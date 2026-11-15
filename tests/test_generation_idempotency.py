"""Synthetic durable admission contract; run through run_backend_offline.py."""
import os
import tempfile
import unittest
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor

class LedgerTests(unittest.TestCase):
    def test_authenticated_but_invalid_ledger_refuses_startup(self):
        import idempotency
        from protection import AccountCipher
        import json
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'ledger'
            path.write_text(json.dumps(AccountCipher().encode([{'scope': 'invalid'}])))
            with self.assertRaises(ValueError):
                idempotency.GenerationLedger(path)

    def test_owner_operation_authority_are_isolated(self):
        import idempotency
        with tempfile.TemporaryDirectory() as directory:
            ledger = idempotency.GenerationLedger(Path(directory) / 'ledger', initialize=True)
            a = ledger.admit('a', 'image', 'same', {})[0]['id']
            b = ledger.admit('b', 'image', 'same', {})[0]['id']
            v = ledger.admit('a', 'video', 'same', {})[0]['id']
            self.assertEqual(len({a, b, v}), 3)
            with self.assertRaises(idempotency.Conflict):
                ledger.admit('a', 'image', 'same', {}, authority=2)

    def test_single_send_never_falls_back_after_uncertain_click(self):
        import engine
        from types import SimpleNamespace
        from unittest.mock import patch, MagicMock
        instance = object.__new__(engine.MuseEngine)
        page = MagicMock()
        page.js.return_value = '{"x": 1, "y": 1}'
        instance._ensure_local = lambda: SimpleNamespace(no_resubmit=True)
        instance._ensure_local().page = page
        # page is a property backed by thread local storage.
        local = SimpleNamespace(no_resubmit=True, page=page)
        instance._ensure_local = lambda: local
        with patch.object(instance, '_click_send', return_value='error') as click, patch.object(engine.time, 'sleep'):
            with self.assertRaises(engine.MuseGenerationError):
                instance._send('synthetic')
            self.assertEqual(click.call_count, 1)
            sends = [c for c in page.send.call_args_list if c.args[0] == 'Input.dispatchKeyEvent']
            self.assertFalse(sends, 'uncertain click must never fall back to Enter')

    def test_concurrent_restart_conflict_and_private_binding(self):
        import importlib.util
        self.assertIsNotNone(importlib.util.find_spec('idempotency'), 'durable ledger missing')
        import idempotency
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'ledger.json'
            ledger = idempotency.GenerationLedger(path, capacity=2, ttl=60, initialize=True)
            def admit(_):
                return ledger.admit('owner', 'image', 'private-key', {'prompt': 'secret prompt', 'ref': 'secret-url'})
            with ThreadPoolExecutor(max_workers=8) as pool:
                results = list(pool.map(admit, range(20)))
            self.assertEqual(sum(first for _, first in results), 1)
            self.assertEqual(len({entry['id'] for entry, _ in results}), 1)
            restarted = idempotency.GenerationLedger(path, capacity=2, ttl=60, initialize=True)
            self.assertEqual(restarted.admit('owner', 'image', 'private-key', {'ref': 'secret-url', 'prompt': 'secret prompt'})[0]['id'], results[0][0]['id'])
            with self.assertRaises(idempotency.Conflict):
                restarted.admit('owner', 'image', 'private-key', {'prompt': 'other'})
            text = path.read_text()
            for secret in ('private-key', 'secret prompt', 'secret-url', 'owner'):
                self.assertNotIn(secret, text)

    def test_capacity_ttl_unknown_and_write_failure_fail_closed(self):
        import idempotency
        from unittest.mock import patch
        with tempfile.TemporaryDirectory() as directory:
            ledger = idempotency.GenerationLedger(Path(directory) / 'ledger', capacity=1, ttl=10, initialize=True)
            entry, first = ledger.admit('a', 'image', 'k', {}, now=100)
            self.assertTrue(first)
            with self.assertRaises(idempotency.Conflict):
                ledger.admit('a', 'image', 'k', {}, now=111)
            with self.assertRaises(idempotency.Capacity):
                ledger.admit('a', 'image', 'new', {}, now=111)
            restarted = idempotency.GenerationLedger(ledger.path, capacity=1, ttl=10)
            self.assertEqual(restarted.admit('a', 'image', 'k', {}, now=101)[0]['id'], entry['id'])
        with tempfile.TemporaryDirectory() as directory:
            ledger = idempotency.GenerationLedger(Path(directory) / 'ledger', initialize=True)
            with patch.object(idempotency.os, 'replace', side_effect=OSError('synthetic')):
                with self.assertRaises(OSError):
                    ledger.admit('a', 'image', 'k', {})
            with self.assertRaises(idempotency.Capacity):
                ledger.admit('a', 'image', 'k', {})

class RouteTests(unittest.IsolatedAsyncioTestCase):
    async def test_image_crash_gap_restart_and_revocation(self):
        import app
        import idempotency
        from test_async_images import Client
        from unittest.mock import patch
        client = Client(app.app, {'Authorization': 'Bearer synthetic-admin', 'Idempotency-Key': 'crash-key'})
        with patch.object(app, '_prepare_reference_images', side_effect=RuntimeError('synthetic gap')) as refs:
            with self.assertRaises(RuntimeError):
                await client.post('/v1/images/tasks', json={'prompt': 'crash'})
            ledger = idempotency.GenerationLedger(app.GENERATION_LEDGER.path)
            with patch.object(app, 'GENERATION_LEDGER', ledger):
                replay = await client.post('/v1/images/generations', json={'prompt': 'crash', 'async': True})
                self.assertEqual(replay.status_code, 202)
                self.assertEqual(replay.json()['status'], 'unknown')
                self.assertEqual(refs.call_count, 1)
                denied = await client.post('/v1/images/tasks', json={'prompt': 'crash'}, headers={'Authorization': 'Bearer revoked'})
                self.assertEqual(denied.status_code, 401)

    async def test_idempotent_engine_disables_ambiguous_resend(self):
        import app
        from unittest.mock import patch
        from types import SimpleNamespace
        account = {'id': 'synthetic', 'cookies': {}}
        job = SimpleNamespace(check=lambda: None, idempotent=True)
        with patch.object(app.ACCOUNT_POOL, 'acquire', return_value=account), patch.object(app.ACCOUNT_POOL, 'release'), patch.object(app, '_bind_account_proxy'), patch.object(app, '_clear_account_proxy'), patch.object(app, '_renew_and_persist'), patch.object(app.engine, 'start'), patch.object(app.engine, 'close_current_page'), patch.object(app.engine, 'reset_thread'), patch.object(app.store, 'mark'), patch.object(app.engine, 'generate', side_effect=app.MuseGenerationError('uncertain')) as generate:
            with self.assertRaises(app.MuseGenerationError):
                app._run_generation_locked('secret', 'image', 1, job=job)
            self.assertEqual(generate.call_count, 1)
            self.assertTrue(generate.call_args.kwargs.get('no_resubmit'), 'engine wait loop must not click send again')

    async def test_concurrent_images_bind_before_reference_and_charge_once(self):
        import app
        import asyncio
        from test_async_images import Client
        from unittest.mock import patch
        await asyncio.to_thread(lambda: None)
        client = Client(app.app, {'Authorization': 'Bearer synthetic-admin', 'Idempotency-Key': 'concurrent-image'})
        original = app.threading.Thread.start
        def start(thread):
            if getattr(thread._target, '__name__', '') != 'worker':
                return original(thread)
        try:
            with patch.object(app.threading.Thread, 'start', start), patch.object(app, '_prepare_reference_images', return_value=[]) as refs, patch.object(app.HEAVY_LIMITER, 'admit', return_value=0) as rate:
                responses = await asyncio.gather(*[client.post('/v1/images/tasks', json={'prompt': 'same', 'images': ['https://example.com/private-reference']}) for _ in range(8)])
                self.assertTrue(all(r.status_code == 202 for r in responses))
                self.assertEqual(len({r.json()['id'] for r in responses}), 1)
                self.assertEqual(refs.call_count, 1)
                self.assertEqual(rate.call_count, 1)
                conflict = await client.post('/v1/images/tasks', json={'prompt': 'same', 'images': ['https://example.com/other-reference']})
                self.assertEqual(conflict.status_code, 409)
                self.assertEqual(refs.call_count, 1)
        finally:
            for job in list(app.OutstandingJob._jobs):
                job.release()

    async def test_completed_image_replay_preserves_poll_result(self):
        import app
        from test_async_images import Client
        from unittest.mock import patch
        client = Client(app.app, {'Authorization': 'Bearer synthetic-admin', 'Idempotency-Key': 'complete-image'})
        entry, _ = app.GENERATION_LEDGER.admit(app.ADMIN_OWNER, 'image', 'complete-image', {k: v for k, v in app.ImageRequest(prompt='done').model_dump(by_alias=True).items() if k != 'async'})
        app.store.create_task('image', 'done', task_id=entry['id'])
        app.store.update_task(entry['id'], status='completed')
        expected = {'id': entry['id'], 'status': 'completed', 'data': [{'url': 'synthetic-capability'}]}
        with patch.object(app, 'get_image_task', return_value=expected):
            actual = app._idempotent_receipt(entry, 'image', app.ADMIN_OWNER)
            self.assertEqual(actual.get('data'), expected['data'])

    async def test_unsupported_headers_fail_before_generation(self):
        import app
        from test_async_images import Client
        client = Client(app.app, {'Authorization': 'Bearer synthetic-admin', 'Idempotency-Key': 'unsupported'})
        for path in ('/v1/images/generations', '/v1/images/edits', '/v1/chat/completions', '/v1/responses'):
            result = await client.post(path, json={'prompt': 'fixture'})
            self.assertEqual(result.status_code, 400, path)

    async def test_thread_start_failure_remains_reserved(self):
        import app
        import asyncio
        from test_async_images import Client
        from unittest.mock import patch
        await asyncio.to_thread(lambda: None)
        client = Client(app.app, {'Authorization': 'Bearer synthetic-admin', 'Idempotency-Key': 'thread-gap'})
        original = app.threading.Thread.start
        def start(thread):
            if getattr(thread._target, '__name__', '') == 'worker':
                raise RuntimeError('synthetic start failure')
            return original(thread)
        with patch.object(app.threading.Thread, 'start', start), patch.object(app, '_prepare_reference_images', return_value=[]) as refs:
            with self.assertRaises(RuntimeError):
                await client.post('/v1/videos', json={'prompt': 'start-fail'})
            result = await client.post('/v1/videos', json={'prompt': 'start-fail'})
            self.assertEqual(result.status_code, 200)
            self.assertEqual(refs.call_count, 1)

    async def test_video_alias_replay_deletion_conflict_and_rate_once(self):
        import app
        from test_async_images import Client
        from unittest.mock import patch
        import asyncio
        await asyncio.to_thread(lambda: None)  # initialize executor before Thread fake
        client = Client(app.app, {'Authorization': 'Bearer synthetic-admin', 'Idempotency-Key': 'route-secret'})
        original_start = app.threading.Thread.start
        def start(thread):
            if getattr(thread._target, '__name__', '') == 'worker':
                return None
            return original_start(thread)
        with patch.object(app.threading.Thread, 'start', start), patch.object(app, '_prepare_reference_images', return_value=[]) as refs, patch.object(app.HEAVY_LIMITER, 'admit', return_value=0) as rate:
            first = await client.post('/v1/videos', json={'prompt': 'private prompt'})
            self.assertEqual(first.status_code, 200)
            again = await client.post('/v1/videos/generations', json={'prompt': 'private prompt'})
            self.assertEqual(again.json()['id'], first.json()['id'], 'video aliases must share durable admission')
            app.store.delete_task(first.json()['id'])
            deleted = await client.post('/v1/videos', json={'prompt': 'private prompt'})
            self.assertEqual(deleted.json()['id'], first.json()['id'])
            conflict = await client.post('/v1/videos', json={'prompt': 'changed'})
            self.assertEqual(conflict.status_code, 409)
            self.assertEqual(refs.call_count, 1)
            self.assertEqual(rate.call_count, 1)

if __name__ == '__main__':
    unittest.main()
