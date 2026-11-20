"""Offline-only acceptance fixes; synthetic stores and ASGI, no startup."""
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch


class AdminEpochTests(unittest.IsolatedAsyncioTestCase):
    async def test_actual_rotation_invalidates_captured_job_and_restart(self):
        import app
        from test_async_images import Client
        old = app.CFG.api_key
        principal = app.auth('Bearer ' + old)
        job = app.OutstandingJob(app.ADMIN_OWNER, principal['key_version'])
        try:
            client = Client(app.app, {'Authorization': 'Bearer ' + old})
            payload = app.ImageRequest(prompt='epoch').model_dump(by_alias=True)
            payload.pop('async', None)
            app.GENERATION_LEDGER.admit(app.ADMIN_OWNER, 'image', 'epoch-key', payload, principal['key_version'])
            rotated = await client.post('/admin/apikey/rotate', json={})
            self.assertEqual(rotated.status_code, 200)
            new = rotated.json()['api_key']
            with self.assertRaises(app.MuseAuthError):
                job.check()
            with self.assertRaises(app.MuseAuthError):
                app.OutstandingJob(app.ADMIN_OWNER, principal['key_version'])
            denied = await client.post('/v1/images/tasks', json={'prompt': 'epoch'}, headers={'Idempotency-Key': 'epoch-key'})
            self.assertEqual(denied.status_code, 401)
            replay = await client.post('/v1/images/tasks', json={'prompt': 'epoch'}, headers={'Authorization': 'Bearer ' + new, 'Idempotency-Key': 'epoch-key'})
            self.assertEqual(replay.status_code, 409)
            with self.assertRaises(app.HTTPException) as stale:
                app.rotate_apikey(principal)
            self.assertEqual(stale.exception.status_code, 401)
            from authority import AdminAuthority
            restarted = AdminAuthority(app.ADMIN_AUTHORITY.path, new)
            self.assertEqual(restarted.version(new), app.auth('Bearer ' + new)['key_version'])
            with self.assertRaises(ValueError):
                AdminAuthority(app.ADMIN_AUTHORITY.path, old)
        finally:
            job.release()


class AuthorityPersistenceTests(unittest.TestCase):
    def test_removed_epoch_and_failed_rotation_fail_closed(self):
        from authority import AdminAuthority
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'authority'
            authority = AdminAuthority(path, 'old')
            def fail(_):
                raise OSError('synthetic env failure')
            with self.assertRaises(OSError):
                authority.rotate('old', 'new', fail)
            self.assertIsNone(authority.version('old'))
            self.assertEqual(AdminAuthority(path, 'new').version('new'), 2)
            path.unlink()
            with self.assertRaises(ValueError):
                AdminAuthority(path, 'old')


class LedgerInitializationTests(unittest.TestCase):
    def test_missing_initialized_ledger_fails_closed_before_task(self):
        from idempotency import GenerationLedger, Capacity
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'ledger'
            ledger = GenerationLedger(path, initialize=True)
            ledger.admit('a', 'image', 'used', {})
            path.unlink()
            with self.assertRaises(ValueError):
                GenerationLedger(path)
            with self.assertRaises(Capacity):
                ledger.admit('a', 'image', 'new', {})


class AdmissionFailureTests(unittest.IsolatedAsyncioTestCase):
    async def test_ledger_capacity_and_write_failure_precede_reference_or_task(self):
        import app
        from idempotency import Capacity
        from test_async_images import Client
        client = Client(app.app, {'Authorization': 'Bearer ' + app.CFG.api_key, 'Idempotency-Key': 'no-task'})
        for error in (Capacity('full'), OSError('synthetic write failure')):
            with patch.object(app.GENERATION_LEDGER, 'admit', side_effect=error), patch.object(app, '_prepare_reference_images') as refs, patch.object(app.store, 'create_task') as task:
                result = await client.post('/v1/images/tasks', json={'prompt': 'fixture'})
                self.assertEqual(result.status_code, 503)
                refs.assert_not_called()
                task.assert_not_called()


class UncertaintyTests(unittest.TestCase):
    def test_orphaned_queued_receipt_is_unknown_not_running(self):
        import app
        task = app.store.create_task('image', 'synthetic orphan')
        receipt = app._idempotent_receipt(task, 'image', app.ADMIN_OWNER)
        self.assertEqual(receipt['status'], 'unknown')
        self.assertTrue(receipt['uncertain'])
        self.assertEqual(receipt['id'], task['id'])
        self.assertEqual(app.get_image_task(task['id'], {'id': app.ADMIN_OWNER})['status'], 'unknown')


class FairCapacityTests(unittest.TestCase):
    def test_owner_saturation_keeps_other_owner_capacity_and_used_keys(self):
        from idempotency import GenerationLedger, Capacity
        with tempfile.TemporaryDirectory() as directory, patch.dict(os.environ, {'MUSE2API_LEDGER_PER_OWNER': '2'}):
            path = Path(directory) / 'ledger'
            ledger = GenerationLedger(path, capacity=4, initialize=True)
            first = ledger.admit('a', 'image', 'one', {})[0]
            ledger.admit('a', 'video', 'two', {})
            with self.assertRaises(Capacity):
                ledger.admit('a', 'image', 'three', {})
            restarted = GenerationLedger(path, capacity=4)
            self.assertEqual(restarted.admit('a', 'image', 'one', {})[0]['id'], first['id'])
            restarted.admit('b', 'image', 'one', {})
            restarted.admit('b', 'video', 'two', {})
            with self.assertRaises(Capacity):
                restarted.admit('c', 'image', 'one', {})


if __name__ == '__main__':
    unittest.main()
