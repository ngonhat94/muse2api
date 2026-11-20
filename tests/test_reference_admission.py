"""Synthetic reference admission/lifetime regressions; run via offline guard."""
import asyncio
import importlib.util
import sys
import threading
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('reference_app', ROOT/'app.py')
assert spec is not None and spec.loader is not None
m = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = m
spec.loader.exec_module(m)

class ReferenceAdmission(unittest.IsolatedAsyncioTestCase):
    def setUp(self):
        user, key = m.users.create('reference-fixture')
        self.owner = user['id']
        self.principal = m.users.authenticate(key)

    def tearDown(self):
        for job in list(m.OutstandingJob._jobs):
            job.release()

    async def invoke(self, route):
        if route == 'task':
            result = m.create_image_task(m.ImageRequest(prompt='fixture', images=['https://example.test/a']), None, self.principal)
            return await result if hasattr(result, '__await__') else result
        if route == 'video':
            return await m.create_video(m.VideoRequest(prompt='fixture', images=['https://example.test/a']), self.principal)
        if route == 'edit':
            class Request:
                headers = {'content-type':'application/json'}
                async def json(self):
                    return {'prompt':'fixture', 'images':['https://example.test/a']}
            return await m.images_edits(Request(), self.principal)
        return await m.images_generations(m.ImageRequest(prompt='fixture', images=['https://example.test/a'], **{'async':route == 'async'}), self.principal)

    async def test_saturation_precedes_normalization_all_routes(self):
        jobs = [m.OutstandingJob(self.owner) for _ in range(8)]
        for route in ('task', 'sync', 'async', 'edit', 'video'):
            with self.subTest(route=route), patch.object(m, '_prepare_reference_images', side_effect=AssertionError('NORMALIZATION BEFORE ADMISSION')) as normalize:
                with self.assertRaises(m.HTTPException) as caught:
                    await self.invoke(route)
                self.assertEqual(caught.exception.status_code, 429)
                normalize.assert_not_called()

    async def test_dns_wait_revocation_prevents_http_open(self):
        import engine
        calls = []
        def dns(*args, **kwargs):
            m.users.revoke(self.owner)
            return [(2, 1, 6, '', ('8.8.8.8', 443))]
        with patch.object(engine.socket, 'getaddrinfo', dns), patch.object(engine.urllib.request, 'build_opener') as build:
            build.return_value.open.side_effect = lambda *a, **k: calls.append('HTTP') or (_ for _ in ()).throw(ValueError('fixture'))
            try:
                await self.invoke('sync')
            except Exception:
                pass
        self.assertEqual(calls, [])

    async def test_cancelled_normalizer_retains_slot_and_cannot_start_generation(self):
        from email.message import Message
        import engine
        entered, release = threading.Event(), threading.Event()
        headers = Message()
        headers['Content-Type'] = 'image/png'
        class Response:
            def __enter__(self): return self
            def __exit__(self, *args): pass
            def read(self, limit):
                entered.set()
                release.wait(5)
                return b'fixture'
        response = Response()
        response.headers = headers
        try:
            with patch.object(engine, '_open_public_ref_image', return_value=response), patch.object(m, '_run_generation') as generate:
                task = asyncio.create_task(self.invoke('sync'))
                self.assertTrue(await asyncio.to_thread(entered.wait, 3))
                task.cancel()
                with self.assertRaises(asyncio.CancelledError): await task
                self.assertEqual(sum(j.owner_id == self.owner for j in m.OutstandingJob._jobs), 1)
                held = [m.OutstandingJob(self.owner) for _ in range(7)]
                with self.assertRaises(m.HTTPException): m.OutstandingJob(self.owner)
                release.set()
                for _ in range(100):
                    if sum(j.owner_id == self.owner for j in m.OutstandingJob._jobs) == 7: break
                    await asyncio.sleep(.01)
                self.assertEqual(sum(j.owner_id == self.owner for j in m.OutstandingJob._jobs), 7)
                generate.assert_not_called()
        finally:
            release.set()

    async def test_single_slot_transfers_to_live_generation_at_owner_limit(self):
        entered, release = threading.Event(), threading.Event()
        held = [m.OutstandingJob(self.owner) for _ in range(7)]
        def generation(*args, **kwargs):
            entered.set()
            release.wait(5)
            raise m.MuseGenerationError('synthetic stop')
        try:
            with patch.object(m, '_prepare_reference_images', return_value=[]), patch.object(m, '_run_generation', generation):
                task = asyncio.create_task(self.invoke('sync'))
                self.assertTrue(await asyncio.to_thread(entered.wait, 3))
                self.assertEqual(sum(j.owner_id == self.owner for j in m.OutstandingJob._jobs), 8)
                task.cancel()
                with self.assertRaises(asyncio.CancelledError): await task
                self.assertEqual(sum(j.owner_id == self.owner for j in m.OutstandingJob._jobs), 8)
                release.set()
                for _ in range(100):
                    if sum(j.owner_id == self.owner for j in m.OutstandingJob._jobs) == 7: break
                    await asyncio.sleep(.01)
                self.assertEqual(sum(j.owner_id == self.owner for j in m.OutstandingJob._jobs), 7)
        finally:
            release.set()

    async def test_invalidated_reference_does_not_normalize_next_source_all_routes(self):
        import engine
        for route in ('task', 'sync', 'async', 'edit', 'video'):
            for action in ('revoke', 'disable', 'rotate'):
                with self.subTest(route=route, action=action):
                    user, key = m.users.create('invalidation-fixture')
                    self.owner, self.principal = user['id'], m.users.authenticate(key)
                    def normalize(instance, image):
                        if action == 'disable': m.users.patch(self.owner, enabled=False)
                        elif action == 'revoke': m.users.revoke(self.owner)
                        else: m.users.rotate(self.owner)
                        return 'Zml4dHVyZQ==', 'image/png'
                    with patch.object(engine.MuseEngine, '_normalize_image', normalize), patch.object(m, '_run_generation') as generate:
                        with self.assertRaises(m.MuseAuthError): await self.invoke(route)
                        generate.assert_not_called()
                    self.assertFalse(any(j.owner_id == self.owner for j in m.OutstandingJob._jobs))

    async def test_queued_handoff_uses_last_slot_until_worker_exit(self):
        await asyncio.to_thread(lambda: None)  # Start the real executor before faking task workers.
        for route in ('task', 'async', 'video'):
            with self.subTest(route=route):
                held = [m.OutstandingJob(self.owner) for _ in range(7)]
                workers = []
                class Thread:
                    def __init__(self, target, **kwargs): self.target = target
                    def start(self): workers.append(self.target)
                with patch.object(m, '_prepare_reference_images', return_value=[]), patch.object(m.threading, 'Thread', Thread):
                    result = await self.invoke(route)
                if route == 'video': self.assertEqual(result['status'], 'queued')
                else: self.assertEqual(result.status_code, 202)
                self.assertEqual(sum(j.owner_id == self.owner for j in m.OutstandingJob._jobs), 8)
                with patch.object(m, '_run_generation', side_effect=m.MuseAuthError('synthetic stop')):
                    workers[0]()
                self.assertEqual(sum(j.owner_id == self.owner for j in m.OutstandingJob._jobs), 7)
                for job in held: job.release()
                for task in list(m.store.tasks.values()):
                    if task.get('owner_id') == self.owner: m.store.delete_task(task['id'], owner_id=self.owner)

    async def test_stale_principal_and_global_limit_precede_normalization(self):
        m.users.rotate(self.owner)
        with patch.object(m, '_prepare_reference_images') as normalize:
            with self.assertRaises(m.MuseAuthError): await self.invoke('sync')
            normalize.assert_not_called()
        self.principal = {'id': self.owner, 'key_version': m.users.capability_state(self.owner)[1]}
        held = []
        # Eight synthetic users fill the global 64-slot budget.
        for _ in range(8):
            user, key = m.users.create('global-fixture')
            held.extend(m.OutstandingJob(user['id']) for _ in range(8))
        with patch.object(m, '_prepare_reference_images') as normalize:
            with self.assertRaises(m.HTTPException) as caught: await self.invoke('sync')
            self.assertEqual(caught.exception.status_code, 429)
            normalize.assert_not_called()

if __name__ == '__main__':
    unittest.main()
