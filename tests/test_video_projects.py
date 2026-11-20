import asyncio
import tempfile
import unittest
from pathlib import Path
from uuid import uuid4

from fastapi import HTTPException


class ProjectsTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(dir=Path(__file__).resolve().parents[1] / 'tests')
        self.addCleanup(self.tmp.cleanup)

    def service(self):
        from video_projects import ProjectService
        return ProjectService(Path(self.tmp.name) / 'projects.json')

    def ready(self, service):
        p = service.create('alice', {'title': 'Demo', 'idea': 'An idea', 'aspect_ratio': '16:9'})
        p = service.patch('alice', p['id'], {'revision': p['revision'], 'script': 'Hi', 'scenes': [
            {'order': 0, 'narration': 'Hi', 'prompt': 'Sky', 'duration': 1}]})
        return service.patch('alice', p['id'], {'revision': p['revision'], 'script_approved': True,
            'scenes': [{k: (True if k == 'approved' else v) for k, v in p['scenes'][0].items() if k != 'attempts'}]})

    def test_idempotent_submission_reconciliation_restart_and_selected_take(self):
        s = self.service()
        p = self.ready(s)
        sid = p['scenes'][0]['id']
        calls = []
        async def submit(task_id, scene):
            calls.append(task_id)
        request = {'revision': p['revision'], 'request_id': str(uuid4())}
        p = asyncio.run(s.generate('alice', p['id'], sid, request, submit))
        self.assertEqual(len(calls), 1)
        replay = asyncio.run(s.generate('alice', p['id'], sid, request, submit))
        self.assertEqual(replay, p)
        self.assertEqual(len(calls), 1)
        s.reconcile('alice', p['id'], lambda tid: {'status': 'completed', 'media_id': 'take.mp4'}, lambda mid: mid == 'take.mp4')
        p = s.get('alice', p['id'])
        selected = p['scenes'][0]['selected_attempt_id']
        self.assertIsNotNone(selected)
        p = asyncio.run(s.generate('alice', p['id'], sid, {'revision': p['revision'], 'request_id': str(uuid4())}, submit))
        self.assertEqual(p['scenes'][0]['selected_attempt_id'], selected)
        s = self.service()
        s.reconcile('alice', p['id'], lambda tid: {'status': 'unknown'}, lambda mid: True)
        p = s.get('alice', p['id'])
        self.assertEqual(p['scenes'][0]['attempts'][-1]['status'], 'unknown')
        self.assertEqual(len(calls), 2)
        self.assertEqual(asyncio.run(s.generate('alice', p['id'], sid, request, submit)), p)
        with self.assertRaises(HTTPException) as conflict:
            asyncio.run(s.generate('alice', p['id'], 'other', request, submit))
        self.assertEqual(conflict.exception.status_code, 409)
        self.assertNotIn('url', Path(self.tmp.name, 'projects.json').read_text().replace('"url": null', ''))

    def test_generate_requires_approvals_and_uncertain_adapter_never_retries(self):
        s = self.service()
        p = self.ready(s)
        sid = p['scenes'][0]['id']
        async def uncertain(task_id, scene):
            raise RuntimeError('secret upstream response must not persist')
        req = {'revision': p['revision'], 'request_id': str(uuid4())}
        p = asyncio.run(s.generate('alice', p['id'], sid, req, uncertain))
        self.assertEqual(p['scenes'][0]['attempts'][0]['status'], 'unknown')
        self.assertNotIn('secret', Path(self.tmp.name, 'projects.json').read_text())
        self.assertEqual(asyncio.run(s.generate('alice', p['id'], sid, req, uncertain)), p)
        p = s.patch('alice', p['id'], {'revision': p['revision'], 'script_approved': False})
        with self.assertRaises(HTTPException) as denied:
            asyncio.run(s.generate('alice', p['id'], sid, {'revision': p['revision'], 'request_id': str(uuid4())}, uncertain))
        self.assertEqual(denied.exception.status_code, 409)

    def test_async_render_snapshot_replay_and_restart(self):
        import threading
        s = self.service()
        p = self.ready(s)
        sid = p['scenes'][0]['id']
        async def submit(tid, scene):
            return None
        p = asyncio.run(s.generate('alice', p['id'], sid, {'revision': p['revision'], 'request_id': str(uuid4())}, submit))
        p = s.reconcile('alice', p['id'], lambda tid: {'status': 'completed', 'media_id': 'take.mp4'}, lambda mid: True)
        gate = threading.Event()
        finished = threading.Event()
        calls = []
        def renderer(clips, aspect):
            calls.append(clips)
            gate.wait(5)
            finished.set()
            return 'final.mp4'
        req = {'revision': p['revision'], 'request_id': str(uuid4())}
        p = s.render('alice', p['id'], req, renderer, lambda mid: True)
        self.assertEqual(s.render('alice', p['id'], req, renderer, lambda mid: True)['render']['id'], p['render']['id'])
        p = s.patch('alice', p['id'], {'revision': p['revision'], 'idea': 'Changed'})
        gate.set()
        self.assertTrue(finished.wait(5))
        for thread in s.threads:
            thread.join(5)
        p = s.get('alice', p['id'])
        self.assertEqual(len(calls), 1)
        self.assertEqual(p['render']['status'], 'completed')
        self.assertTrue(p['render']['outdated'])
        self.assertEqual(s.render('alice', p['id'], req, renderer, lambda mid: True), p)
        self.assertNotIn('final.mp4', str(p['render']))
        self.assertEqual(s.render_media('alice', p['id']), 'final.mp4')
        # Simulate an interrupted durable render; a new service has no live workers.
        s.data['projects'][p['id']]['render']['status'] = 'processing'
        s.save()
        restarted = self.service()
        p = restarted.reconcile('alice', p['id'], lambda tid: None, lambda mid: True)
        self.assertEqual(p['render']['status'], 'unknown')
        self.assertEqual(restarted.render('alice', p['id'], req, renderer, lambda mid: True), p)
        self.assertEqual(len(calls), 1)

    def test_plan_schema_and_manual_fallback(self):
        s = self.service()
        p = s.create('alice', {'title': 'X', 'idea': 'Sky', 'aspect_ratio': '16:9'})
        async def invalid(project):
            return '{"script": "bad", "scenes": [{"url": "https://bad"}]}'
        with self.assertRaises(HTTPException) as error:
            asyncio.run(s.plan('alice', p['id'], {'revision': p['revision']}, invalid))
        self.assertEqual(error.exception.status_code, 502)
        self.assertEqual(s.get('alice', p['id']), p)
        async def valid(project):
            return '{"script": "Hi", "scenes": [{"order":0,"narration":"Hi","prompt":"Sky","duration":1}]}'
        p = asyncio.run(s.plan('alice', p['id'], {'revision': p['revision']}, valid))
        self.assertEqual(p['script'], 'Hi')
        self.assertFalse(p['scenes'][0]['approved'])
        self.assertFalse(p['script_approved'])

    def test_routes_use_existing_async_worker_and_refresh_owned_urls(self):
        import os
        from unittest.mock import patch
        from cryptography.fernet import Fernet
        root = Path(self.tmp.name)
        with patch.dict(os.environ, {'MUSE2API_HOME': str(root), 'MUSE2API_PROFILE_ROOT': str(root/'profile'),
            'MUSE2API_COOKIE_KEY': Fernet.generate_key().decode(), 'MUSE2API_COOKIE_KEY_FILE': '',
            'MUSE2API_KEY': 'synthetic', 'MUSE2API_LEDGER_INITIALIZE': '1', 'MUSE2API_AUTO_UPDATE': '0'}):
            import app
        from fastapi.testclient import TestClient
        from video_projects import ProjectService
        service = ProjectService(root/'route-projects.json')
        with patch.object(app, 'VIDEO_PROJECTS', service), patch.object(app, 'auth', return_value={'id':'alice','key_version':1}), \
             patch.object(app, '_project_preflight'), patch.object(app, 'create_video') as create:
            app.app.dependency_overrides[app.auth] = lambda: {'id':'alice','key_version':1}
            self.addCleanup(app.app.dependency_overrides.clear)
            # Existing Depends captured the original auth function before patching.
            for route in app.app.routes:
                if getattr(route, 'path', '').startswith('/v1/video-projects'):
                    for dep in route.dependant.dependencies:
                        app.app.dependency_overrides[dep.call] = lambda: {'id':'alice','key_version':1}
            async def fake(req, _):
                admission = app._IDEMPOTENT_ADMISSION.get()
                self.assertIsNotNone(admission)
                self.assertEqual(req.prompt, 'Sky')
                return {'task_id': admission['id']}
            create.side_effect = fake
            client = TestClient(app.app)
            p = self.ready(service)
            sid = p['scenes'][0]['id']
            req = {'revision':p['revision'], 'request_id':str(uuid4())}
            result = client.post(f"/v1/video-projects/{p['id']}/scenes/{sid}/generate", json=req)
            self.assertEqual(result.status_code, 200, result.text)
            self.assertEqual(create.call_count, 1)
            result = client.post(f"/v1/video-projects/{p['id']}/scenes/{sid}/generate", json=req)
            self.assertEqual(result.status_code, 200)
            self.assertEqual(create.call_count, 1)
            self.assertEqual(client.get('/v1/video-projects').status_code, 200)
            self.assertEqual(client.patch(f"/v1/video-projects/{p['id']}", json={'revision':1,'title':'stale'}).status_code, 409)

    def test_capability_and_quota_gate_before_authorization(self):
        from unittest.mock import patch
        from video_projects import render_capability
        from protection import StorageQuotaExceeded
        with patch('video_projects.shutil.which', return_value=None):
            with self.assertRaises(HTTPException) as error:
                render_capability()
        self.assertEqual(error.exception.status_code, 503)
        s = self.service()
        p = self.ready(s)
        async def submit(tid, scene):
            self.fail('Must not submit when preflight fails')
        def no_quota():
            raise StorageQuotaExceeded('full')
        with self.assertRaises(StorageQuotaExceeded):
            asyncio.run(s.generate('alice', p['id'], p['scenes'][0]['id'],
                {'revision':p['revision'], 'request_id':str(uuid4())}, submit, no_quota))
        self.assertEqual(s.get('alice', p['id']), p)
        self.assertEqual(s.data['requests'], {})

    def test_concurrent_idempotent_generation_and_edit_during_submission(self):
        s = self.service()
        p = self.ready(s)
        sid = p['scenes'][0]['id']
        calls = []
        async def scenario():
            gate = asyncio.Event()
            entered = asyncio.Event()
            async def submit(tid, scene):
                calls.append(tid)
                entered.set()
                await gate.wait()
                raise RuntimeError('ambiguous')
            req = {'revision':p['revision'], 'request_id':str(uuid4())}
            task = asyncio.create_task(s.generate('alice',p['id'],sid,req,submit))
            await entered.wait()
            replay = await s.generate('alice',p['id'],sid,req,submit)
            edited = s.patch('alice',p['id'],{'revision':replay['revision'],'title':'Concurrent edit'})
            gate.set()
            result = await task
            self.assertEqual(result['title'], edited['title'])
            self.assertGreater(result['revision'], edited['revision'])
            self.assertEqual(result['scenes'][0]['attempts'][0]['status'],'unknown')
        asyncio.run(scenario())
        self.assertEqual(len(calls),1)

    def test_existing_video_worker_runs_with_injected_unpaid_adapter(self):
        import os
        import time
        from unittest.mock import patch
        from cryptography.fernet import Fernet
        root = Path(self.tmp.name)
        with patch.dict(os.environ, {'MUSE2API_HOME': str(root), 'MUSE2API_PROFILE_ROOT': str(root/'profile'),
            'MUSE2API_COOKIE_KEY': Fernet.generate_key().decode(), 'MUSE2API_COOKIE_KEY_FILE': '',
            'MUSE2API_KEY':'synthetic', 'MUSE2API_LEDGER_INITIALIZE':'1', 'MUSE2API_AUTO_UPDATE':'0'}):
            import app
        from store import Store
        from types import SimpleNamespace
        with patch.dict(os.environ, {'MUSE2API_COOKIE_KEY':Fernet.generate_key().decode(),'MUSE2API_COOKIE_KEY_FILE':''}):
            store = Store(SimpleNamespace(data_dir=str(root), media_dir=str(root/'media'),
                accounts_file=str(root/'accounts.json'),tasks_file=str(root/'tasks.json'),media_index_file=str(root/'index.json')))
        s = self.service()
        p = self.ready(s)
        class Job:
            worker_owned = False
            task_id = None
            def __init__(self, *args):
                import threading
                self.cancelled = threading.Event()
            def check(self):
                pass
            def release(self):
                pass
        def adapter(prompt, kind, timeout, **kwargs):
            self.assertEqual(kind, 'video')
            kwargs['on_acquired']()
            store.write_media('synthetic.mp4', b'synthetic-owned-test', 'alice')
            return {'filename':'synthetic.mp4','size':20,'kind':'video'}, 'fake-account'
        with patch.object(app, 'VIDEO_PROJECTS', s), patch.object(app, 'store', store), \
             patch.object(app, 'OutstandingJob', Job), patch.object(app, '_run_generation', side_effect=adapter) as upstream, \
             patch.object(app, '_project_preflight'), patch.object(app, '_task_observation', side_effect=lambda t,o:t), \
             patch.object(app, '_capability_state', return_value=(True, 1, 'synthetic-hash')):
            req = app.Submission(revision=p['revision'], request_id=str(uuid4()))
            p = asyncio.run(app.generate_project_scene(p['id'], p['scenes'][0]['id'], req, {'id':'alice'}))
            for _ in range(100):
                p = app._project_view(p['id'], {'id':'alice'})
                if p['scenes'][0]['attempts'][0]['status'] == 'completed':
                    break
                time.sleep(.01)
            attempt = p['scenes'][0]['attempts'][0]
            self.assertEqual(attempt['status'], 'completed', str(store.tasks))
            self.assertEqual(attempt['media_id'], 'synthetic.mp4')
            self.assertIsNotNone(attempt['url'])
            persisted = Path(self.tmp.name, 'projects.json').read_text()
            self.assertNotIn('?cap=', persisted)
            self.assertNotIn('cookies', persisted)
            self.assertEqual(upstream.call_count, 1)

    @unittest.skipUnless(__import__('shutil').which('ffmpeg') and __import__('shutil').which('ffprobe'),
                         'Real rendering requires installed ffmpeg/ffprobe; capability denial is tested separately')
    def test_real_render_normalizes_audio_dimensions_and_owned_quota(self):
        import json
        import subprocess
        from types import SimpleNamespace
        from store import Store
        from video_projects import render_mp4
        root = Path(self.tmp.name)
        media = root / 'media'
        media.mkdir()
        cfg = SimpleNamespace(data_dir=str(root), media_dir=str(media),
            accounts_file=str(root/'accounts.json'), tasks_file=str(root/'tasks.json'), media_index_file=str(root/'media.json'))
        from unittest.mock import patch
        from cryptography.fernet import Fernet
        with patch.dict('os.environ', {'MUSE2API_COOKIE_KEY': Fernet.generate_key().decode(), 'MUSE2API_COOKIE_KEY_FILE': ''}):
            store = Store(cfg)
        clips = []
        for i, size in enumerate(('320x240', '240x320')):
            target = root / f'source{i}.mp4'
            cmd = ['ffmpeg', '-hide_banner', '-loglevel', 'error', '-f', 'lavfi', '-i', f'color=c=red:s={size}:r=15:d=0.5']
            if i:
                cmd += ['-f', 'lavfi', '-i', 'sine=frequency=440:duration=0.5', '-shortest']
            subprocess.run(cmd + ['-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-y', str(target)], check=True, timeout=20)
            name = f'clip{i}.mp4'
            store.write_media(name, target.read_bytes(), 'alice')
            clips.append({'media_id': name, 'duration': 1})
        output = render_mp4(store, 'alice', clips, '16:9', root)
        self.assertEqual(store.media_owner(output), 'alice')
        info = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-show_streams', '-show_format', '-of', 'json', str(media/output)]))
        video = next(s for s in info['streams'] if s['codec_type'] == 'video')
        self.assertEqual((video['width'], video['height'], video['r_frame_rate']), (1280, 720, '24/1'))
        self.assertTrue(any(s['codec_type'] == 'audio' for s in info['streams']))
        self.assertAlmostEqual(float(info['format']['duration']), 2.0, delta=0.15)
        with self.assertRaises(ValueError):
            render_mp4(store, 'bob', clips, '16:9', root)
        store.limit_provider = lambda owner: {'storage_bytes': 1}
        from protection import StorageQuotaExceeded
        with self.assertRaises(StorageQuotaExceeded):
            render_mp4(store, 'alice', clips, '16:9', root)

    def test_owned_durable_revision_and_approval_invalidation(self):
        service = self.service()
        p = service.create('alice', {'title': 'Demo', 'idea': 'An idea', 'aspect_ratio': '16:9'})
        self.assertEqual(service.list('bob'), {'projects': []})
        with self.assertRaises(HTTPException) as denied:
            service.get('bob', p['id'])
        self.assertEqual(denied.exception.status_code, 404)
        p = service.patch('alice', p['id'], {'revision': p['revision'], 'script': 'Hello', 'scenes': [
            {'order': 0, 'narration': 'Hello', 'prompt': 'Sky', 'duration': 1, 'approved': True}]})
        self.assertFalse(p['script_approved'])
        self.assertFalse(p['scenes'][0]['approved'])
        with self.assertRaises(HTTPException) as stale:
            service.patch('alice', p['id'], {'revision': 1, 'title': 'stale'})
        self.assertEqual(stale.exception.status_code, 409)
        with self.assertRaises(HTTPException):
            service.patch('alice', p['id'], {'revision':p['revision'], 'scenes':[{'id':'foreign', 'order':0,'prompt':'bad','narration':'','duration':1}]})
        with self.assertRaises(HTTPException):
            service.patch('alice', p['id'], {'revision':p['revision'], 'scenes':[{'order':0,'prompt':'bad','narration':'','duration':1,'attempts':[]}]})
        with self.assertRaises(HTTPException):
            service.render('alice', p['id'], {'revision':p['revision'],'request_id':str(uuid4())}, lambda c,a:'bad', lambda m:False)
        p = service.patch('alice', p['id'], {'revision': p['revision'], 'script_approved': True,
            'scenes': [{**{k: v for k, v in p['scenes'][0].items() if k not in ('attempts',)}, 'approved': True}]})
        self.assertTrue(p['script_approved'])
        self.assertTrue(p['scenes'][0]['approved'])
        self.assertEqual(self.service().get('alice', p['id']), p)
        p = service.patch('alice', p['id'], {'revision': p['revision'], 'idea': 'Changed', 'script_approved': True})
        self.assertFalse(p['script_approved'])
        self.assertFalse(p['scenes'][0]['approved'])


if __name__ == '__main__':
    unittest.main()
