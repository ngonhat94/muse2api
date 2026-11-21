"""Real ASGI HTTP contract; synthetic identities only, no auth overrides."""
import unittest
from fastapi.testclient import TestClient
import app


class ProjectContractTest(unittest.TestCase):
    def test_generation_capability_and_revocation_over_http(self):
        client = TestClient(app.app)
        admin = {'Authorization': 'Bearer ' + app.CFG.api_key}
        response = client.get('/v1/me', headers=admin)
        self.assertEqual(response.status_code, 200)
        self.assertIs(response.json()['capabilities'].get('generation'), True)
        created = client.post('/admin/users', headers=admin, json={'label': 'Synthetic contract tenant'})
        self.assertEqual(created.status_code, 201, created.text)
        user = created.json()
        headers = {'Authorization': 'Bearer ' + user['api_key']}
        me = client.get('/v1/me', headers=headers)
        self.assertEqual(me.status_code, 200)
        self.assertIs(me.json()['capabilities'].get('generation'), True)
        self.assertFalse(me.json()['capabilities']['manage_users'])
        project = {'title': 'Synthetic contract', 'idea': 'A red sky', 'aspect_ratio': '16:9'}
        self.assertEqual(client.post('/v1/video-projects', headers=headers, json=project).status_code, 200)
        uid = user['user']['id']
        self.assertEqual(client.patch('/admin/users/' + uid, headers=admin, json={'enabled': False}).status_code, 200)
        for path in ('/v1/me', '/v1/video-projects'):
            self.assertEqual(client.get(path, headers=headers).status_code, 401)
        self.assertEqual(client.post('/v1/video-projects', headers=headers, json=project).status_code, 401)
        self.assertEqual(client.patch('/admin/users/' + uid, headers=admin, json={'enabled': True}).status_code, 200)
        self.assertEqual(client.get('/v1/me', headers=headers).status_code, 200)
        self.assertEqual(client.delete('/admin/users/' + uid + '/key', headers=admin).status_code, 200)
        for path in ('/v1/me', '/v1/video-projects'):
            self.assertEqual(client.get(path, headers=headers).status_code, 401)
        self.assertEqual(client.post('/v1/video-projects', headers=headers, json=project).status_code, 401)
        self.assertEqual(client.get('/v1/me').status_code, 401)

    def test_planning_revocation_and_receipt_denial(self):
        import json
        import threading
        from unittest.mock import patch
        from uuid import uuid4
        client = TestClient(app.app)
        admin = {'Authorization': 'Bearer ' + app.CFG.api_key}
        user = client.post('/admin/users', headers=admin, json={'label': 'Planning revocation'}).json()
        headers = {'Authorization': 'Bearer ' + user['api_key']}
        p = client.post('/v1/video-projects', headers=headers, json={'title': 'Draft', 'idea': 'Idea'}).json()
        path = '/v1/video-projects/' + p['id']
        rid = str(uuid4())
        entered, release = threading.Event(), threading.Event()
        async def adapter(snapshot, principal):
            self.assertNotIn('api_key', principal)
            entered.set()
            release.wait(5)
            return json.dumps({'script': 'Must not apply', 'scenes': [
                {'order': 0, 'narration': 'Draft', 'prompt': 'Sky', 'duration': 1}]})
        with patch.object(app, '_project_planner', side_effect=adapter), \
             patch.object(app.store, 'pick_account', return_value={'id': 'synthetic-account'}):
            try:
                response = client.post(path + '/plan', headers=headers, json={'revision': 1, 'request_id': rid})
                self.assertEqual(response.status_code, 200, response.text)
                self.assertTrue(entered.wait(1))
                self.assertEqual(client.patch('/admin/users/' + user['user']['id'], headers=admin, json={'enabled': False}).status_code, 200)
                self.assertEqual(client.get(path + '/requests/' + rid, headers=headers).status_code, 401)
                self.assertEqual(client.post(path + '/plan', headers=headers, json={'revision': 1, 'request_id': rid}).status_code, 401)
            finally:
                release.set()
                for thread in app.VIDEO_PROJECTS.threads:
                    thread.join(5)
        persisted = app.VIDEO_PROJECTS.get(user['user']['id'], p['id'])
        self.assertEqual(persisted['planning']['status'], 'failed')
        self.assertEqual(persisted['script'], '')
        self.assertEqual(client.patch('/admin/users/' + user['user']['id'], headers=admin, json={'enabled': True}).status_code, 200)
        self.assertEqual(client.get(path + '/requests/' + rid, headers=headers).json()['status'], 'failed')

    @unittest.skipUnless(__import__('shutil').which('ffmpeg') and __import__('shutil').which('ffprobe'),
                         'Real HTTP render contract requires ffmpeg/ffprobe')
    def test_export_real_http_lifecycle(self):
        import hashlib
        import json
        import os
        import subprocess
        import time
        from pathlib import Path
        from unittest.mock import patch
        from uuid import uuid4

        client = TestClient(app.app)
        admin = {'Authorization': 'Bearer ' + app.CFG.api_key}
        user = client.post('/admin/users', headers=admin, json={'label': 'Synthetic lifecycle tenant'}).json()
        headers = {'Authorization': 'Bearer ' + user['api_key']}
        entries = []

        def request(stage, method, path, body=None):
            response = client.request(method, path, headers=headers, json=body)
            self.assertEqual(response.status_code, 200, response.text)
            value = response.json()
            entries.append({'stage': stage, 'request': {'method': method, 'path': path, 'json': body},
                            'status': response.status_code, 'response': value})
            return value

        request('me', 'GET', '/v1/me')
        p = request('create', 'POST', '/v1/video-projects',
                    {'title': 'Synthetic red sky', 'idea': 'A red sky', 'aspect_ratio': '16:9'})
        path = '/v1/video-projects/' + p['id']
        import threading
        gate = threading.Event()
        entered = threading.Event()
        async def planner(snapshot, principal):
            entered.set()
            gate.wait(5)
            return json.dumps({'script': 'A red sky.', 'scenes': [
                {'order': 0, 'narration': 'A red sky.', 'prompt': 'Red sky', 'duration': 1}]})
        plan_id = str(uuid4())
        with patch.object(app.store, 'pick_account', return_value={'id': 'synthetic-account'}), \
             patch.object(app, '_project_planner', side_effect=planner):
            started = time.monotonic()
            try:
                p = request('plan', 'POST', path + '/plan', {'revision': p['revision'], 'request_id': plan_id})
                self.assertLess(time.monotonic() - started, 1)
                self.assertTrue(entered.wait(1))
                self.assertIn(p['planning']['status'], ('queued', 'processing'))
                receipt = request('plan_receipt', 'GET', path + '/requests/' + plan_id)
                self.assertTrue(receipt['accepted'])
                request('plan_replay', 'POST', path + '/plan', {'revision': 1, 'request_id': plan_id})
            finally:
                gate.set()
                for thread in app.VIDEO_PROJECTS.threads:
                    thread.join(5)
        p = request('plan_completed', 'GET', path)
        self.assertEqual(p['planning']['status'], 'completed', p)
        request('plan_receipt_completed', 'GET', path + '/requests/' + plan_id)
        request('missing_receipt', 'GET', path + '/requests/' + str(uuid4()))
        p = request('manual', 'PATCH', path, {'revision': p['revision'], 'script': 'A red sky.',
                    'scenes': [{'order': 0, 'narration': 'A red sky.', 'prompt': 'Red sky', 'duration': 1}]})
        scene = {k: v for k, v in p['scenes'][0].items() if k != 'attempts'}
        scene['approved'] = True
        p = request('approve', 'PATCH', path, {'revision': p['revision'], 'script_approved': True, 'scenes': [scene]})
        sid = p['scenes'][0]['id']
        source = Path(app.CFG.data_dir) / 'synthetic-source.mp4'
        subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-f', 'lavfi', '-i',
                        'color=c=red:s=320x240:r=24:d=1', '-c:v', 'libx264', '-pix_fmt', 'yuv420p',
                        '-y', str(source)], check=True, timeout=30)
        calls = []

        def adapter(prompt, kind, timeout, **kwargs):
            calls.append(kind)
            self.assertEqual(kind, 'video')
            kwargs['on_acquired']()
            app.store.write_media('synthetic-contract.mp4', source.read_bytes(), kwargs['owner_id'])
            return {'filename': 'synthetic-contract.mp4', 'size': source.stat().st_size, 'kind': 'video'}, 'synthetic-account'

        with patch.object(app.store, 'pick_account', return_value={'id': 'synthetic-account'}), \
             patch.object(app, '_run_generation', side_effect=adapter):
            generate_id = str(uuid4())
            p = request('generate', 'POST', path + '/scenes/' + sid + '/generate',
                        {'revision': p['revision'], 'request_id': generate_id})
            receipt = request('generate_receipt', 'GET', path + '/requests/' + generate_id)
            self.assertTrue(receipt['accepted'])
            self.assertEqual(receipt['task_id'], p['scenes'][0]['attempts'][0]['task_id'])
            self.assertEqual(receipt['action'], 'generate')
            self.assertEqual(receipt['scene_id'], sid)
            for _ in range(300):
                response = client.get(path, headers=headers)
                self.assertEqual(response.status_code, 200, response.text)
                p = response.json()
                if p['scenes'][0]['attempts'][0]['status'] == 'completed':
                    break
                time.sleep(.01)
            self.assertEqual(p['scenes'][0]['attempts'][0]['status'], 'completed', p)
            p = request('completed', 'GET', path)
            attempt = p['scenes'][0]['attempts'][0]
            p = request('select', 'PATCH', path, {'revision': p['revision'], 'scenes': [
                {**{k: v for k, v in p['scenes'][0].items() if k != 'attempts'}, 'selected_attempt_id': attempt['id']} ]})
            self.assertEqual(request('generate_receipt_completed', 'GET', path + '/requests/' + generate_id)['status'], 'completed')
            render_id = str(uuid4())
            p = request('render', 'POST', path + '/render', {'revision': p['revision'], 'request_id': render_id})
            self.assertTrue(request('render_receipt', 'GET', path + '/requests/' + render_id)['accepted'])
            self.assertEqual(client.get(path + '/requests/' + str(uuid4()), headers=headers).json()['status'], 'not_found')
            outsider = client.post('/admin/users', headers=admin, json={'label': 'Outsider'}).json()
            self.assertEqual(client.get(path + '/requests/' + render_id, headers={'Authorization': 'Bearer ' + outsider['api_key']}).status_code, 404)
            for thread in app.VIDEO_PROJECTS.threads:
                thread.join(60)
            p = request('render_completed', 'GET', path)
            self.assertEqual(p['render']['status'], 'completed', p)
        self.assertEqual(calls, ['video'])
        media = []
        for label, url in [('take', p['scenes'][0]['attempts'][0]['url']), ('render', p['render']['url'])]:
            self.assertIsNotNone(url)
            response = client.get(url)
            self.assertEqual(response.status_code, 200, response.text if response.status_code != 200 else '')
            self.assertEqual(response.headers['content-type'], 'video/mp4')
            media.append({'stage': label, 'url': url, 'status': response.status_code,
                          'content_type': response.headers['content-type'], 'bytes': len(response.content),
                          'sha256': hashlib.sha256(response.content).hexdigest()})
        request('reload', 'GET', path)
        request('list', 'GET', '/v1/video-projects')
        fixture = {'provenance': 'Captured from real FastAPI HTTP routes with real auth, existing video worker, injected unpaid generation adapter and real ffmpeg renderer; synthetic isolated identities; URLs expire.',
                   'exchanges': entries, 'media_gets': media}
        output = os.environ.get('MUSE2API_CONTRACT_EXPORT')
        if output:
            Path(output).write_text(json.dumps(fixture, indent=2) + '\n')


if __name__ == '__main__':
    unittest.main()
