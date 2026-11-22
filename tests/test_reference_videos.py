import json
import subprocess
import tempfile
import threading
import unittest
from pathlib import Path
from uuid import uuid4

from fastapi import HTTPException
from video_projects import ProjectService


class ReferenceVideosTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(dir=Path(__file__).parent)
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)

    def test_import_transaction_replay_restart_and_validation(self):
        from reference_videos import ReferenceService
        projects = ProjectService(self.root/'projects.json')
        service = ReferenceService(projects, None, self.root/'scratch')
        job = service.admit('alice')
        with self.assertRaises(HTTPException) as pending:
            service.import_shots('alice', job['id'], {'request_id': str(uuid4()), 'shot_ids': ['a']})
        self.assertEqual(pending.exception.status_code, 409)
        service.update('alice', job['id'], status='completed', stage='completed', shots=[
            dict(id='a', order=0, start=0, end=2.3, duration=2.3, thumbnail_path='not-a-path'),
            dict(id='b', order=1, start=2.3, end=18.3, duration=16, thumbnail_path='not-a-path')])
        request = dict(request_id=str(uuid4()), shot_ids=['a'])
        project = service.import_shots('alice', job['id'], request)
        self.assertFalse(project['script_approved'])
        self.assertFalse(project['scenes'][0]['approved'])
        self.assertEqual(project['scenes'][0]['attempts'], [])
        self.assertIn('placeholder', project['scenes'][0]['prompt'])
        self.assertEqual(project['scenes'][0]['duration'], 2)
        restarted_projects = ProjectService(projects.path)
        restarted = ReferenceService(restarted_projects, None, self.root/'scratch')
        self.assertEqual(restarted.import_shots('alice', job['id'], request), project)
        self.assertEqual(len(restarted_projects.list('alice')['projects']), 1)
        for shots, code in [(['b'], 422), (['a','a'],422), ([],422), (['missing'],422)]:
            with self.assertRaises(HTTPException) as error:
                restarted.import_shots('alice', job['id'], dict(request_id=str(uuid4()), shot_ids=shots))
            self.assertEqual(error.exception.status_code, code)
        with self.assertRaises(HTTPException) as conflict:
            restarted.import_shots('alice', job['id'], dict(request, title='different'))
        self.assertEqual(conflict.exception.status_code, 409)
        with self.assertRaises(HTTPException) as foreign:
            restarted.get('bob', job['id'])
        self.assertEqual(foreign.exception.status_code, 404)
        active = restarted.admit('alice')
        again = ReferenceService(ProjectService(projects.path), None, self.root/'scratch')
        self.assertEqual(again.get('alice', active['id'])['status'], 'unknown')

    def test_http_upload_job_thumbnail_import_and_isolation(self):
        import app
        from fastapi.testclient import TestClient
        from reference_videos import ReferenceService
        from store import Store
        from config import Config
        from unittest.mock import patch
        source = self.root/'http.mp4'
        subprocess.run(['ffmpeg', '-v', 'error', '-f', 'lavfi', '-i',
                        'color=green:s=160x90:r=10:d=2', '-threads', '1', str(source)], check=True)
        projects = ProjectService(self.root/'http-projects.json')
        service = ReferenceService(projects, app.store, self.root/'scratch')
        identity = {'id': 'alice', 'key_version': 1}
        for route in app.app.routes:
            if getattr(route, 'path', '').startswith(('/v1/reference-videos', '/v1/video-projects')):
                for dep in route.dependant.dependencies:
                    app.app.dependency_overrides[dep.call] = lambda: identity
        self.addCleanup(app.app.dependency_overrides.clear)
        with patch.object(app, 'REFERENCES', service), patch.object(app, 'VIDEO_PROJECTS', projects), \
             patch.object(app, 'auth', side_effect=lambda *_: identity), \
             patch.object(app, '_project_preflight'), patch.object(app, 'OutstandingJob') as authority:
            client = TestClient(app.app)
            response = client.post('/v1/reference-videos', files={'file': ('../../unsafe.mp4', source.read_bytes(), 'video/mp4')})
            self.assertEqual(response.status_code, 202, response.text)
            job = response.json()
            self.assertIn(job['status'], ('queued', 'processing'))
            for thread in service.threads:
                thread.join(10)
            job = client.get('/v1/reference-videos/'+job['id']).json()
            self.assertEqual(job['status'], 'completed', job)
            self.assertEqual(len(job['shots']), 1)
            self.assertNotIn('owner_id', job)
            thumb = client.get(job['shots'][0]['thumbnail_path'])
            self.assertEqual(thumb.status_code, 200)
            self.assertTrue(thumb.content.startswith(b'\xff\xd8'))
            request = dict(request_id=str(uuid4()), shot_ids=[job['shots'][0]['id']])
            imported = client.post('/v1/reference-videos/'+job['id']+'/import', json=request)
            self.assertEqual(imported.status_code, 200, imported.text)
            p = imported.json()
            self.assertEqual(p['first_frame_mode'], 'review')
            scene = p['scenes'][0]
            self.assertFalse(scene['first_frame']['approved'])
            image = client.get(f"/v1/video-projects/{p['id']}/scenes/{scene['id']}/first-frame/{scene['first_frame']['id']}")
            self.assertEqual(image.content, thumb.content)
            self.assertEqual(client.get('/v1/video-projects/'+p['id']).json()['scenes'], p['scenes'])
            self.assertEqual(client.post('/v1/reference-videos/'+job['id']+'/import', json=request).json()['id'], p['id'])
            identity = {'id': 'bob', 'key_version': 1}
            self.assertEqual(client.get('/v1/reference-videos/'+job['id']).status_code, 404)
            self.assertEqual(client.get(job['shots'][0]['thumbnail_path']).status_code, 404)
            self.assertEqual(client.post('/v1/reference-videos/'+job['id']+'/import', json=request).status_code, 404)
            self.assertEqual(client.post('/v1/reference-videos', files={'file': ('x', b'not video', 'text/plain')}).status_code, 415)
            self.assertEqual(client.post('/v1/reference-videos', json={'url': 'http://localhost/private'}).status_code, 415)
            bad = client.post('/v1/reference-videos', files={'file': ('x', b'not video', 'video/mp4')})
            self.assertEqual(bad.status_code, 202)
            for thread in service.threads:
                thread.join(10)
            self.assertEqual(client.get('/v1/reference-videos/'+bad.json()['id']).json()['status'], 'failed')
            self.assertEqual(client.post('/v1/reference-videos', files=[('file', ('a', b'a', 'video/mp4')), ('file', ('b', b'b', 'video/mp4'))]).status_code, 422)
            with patch.object(app, 'MAX_BODY', 10):
                self.assertEqual(client.post('/v1/reference-videos', files={'file': ('x', b'x'*20, 'video/mp4')}).status_code, 413)
            with patch.object(app, 'auth', side_effect=HTTPException(401, 'Invalid')):
                self.assertEqual(client.get('/v1/reference-videos/'+job['id']).status_code, 401)
                self.assertEqual(client.post('/v1/reference-videos', files={'file': ('x', b'x', 'video/mp4')}).status_code, 401)
            authority.assert_called()

    def test_selection_limits_receipt_after_edits_and_capacity(self):
        from reference_videos import ReferenceService
        p = ProjectService(self.root/'limits.json')
        s = ReferenceService(p, None, self.root/'scratch')
        job = s.admit('alice')
        with self.assertRaises(HTTPException) as full:
            s.admit('alice')
        self.assertEqual(full.exception.status_code, 429)
        for status in ('queued', 'processing', 'unknown', 'failed'):
            s.update('alice', job['id'], status=status)
            with self.assertRaises(HTTPException) as not_ready:
                s.import_shots('alice', job['id'], dict(request_id=str(uuid4()), shot_ids=['a']))
            self.assertEqual(not_ready.exception.status_code, 409)
        shots = [dict(id=str(i), order=i, start=i*15, end=(i+1)*15, duration=15) for i in range(13)]
        shots += [dict(id='short', order=13, start=0, end=.5, duration=.5)]
        s.update('alice', job['id'], status='completed', shots=shots)
        for ids in ([str(i) for i in range(9)], [str(i) for i in range(13)], ['short']):
            with self.assertRaises(HTTPException) as invalid:
                s.import_shots('alice', job['id'], dict(request_id=str(uuid4()), shot_ids=ids))
            self.assertEqual(invalid.exception.status_code, 422)
        req = dict(request_id=str(uuid4()), shot_ids=['1', '0'])
        project = s.import_shots('alice', job['id'], req)
        self.assertIn('shot 1 ', project['scenes'][0]['prompt'])
        p.patch('alice', project['id'], dict(revision=1, title='Edited'))
        self.assertEqual(s.import_shots('alice', job['id'], dict(req, shot_ids=['0','1']))['title'], 'Edited')
        self.assertEqual(len(p.data['projects']), 1)

    def test_worker_async_authority_quota_cleanup_and_restart(self):
        from reference_videos import ReferenceService
        from unittest.mock import patch, Mock
        from protection import StorageQuotaExceeded
        import io
        p = ProjectService(self.root/'worker.json')
        media = {'source.mp4': b'synthetic-local-input'}
        storage = Mock()
        storage.media_owner.side_effect = lambda name: 'alice' if name in media else None
        def open_local(name):
            path = self.root/'mock-source'
            path.write_bytes(media[name])
            return path.open('rb')
        storage.open_media.side_effect = open_local
        storage.delete_media.side_effect = lambda name, owner_id: media.pop(name, None)
        def write(name, data, owner):
            media[name] = data
        storage.write_media.side_effect = write
        s = ReferenceService(p, storage, self.root/'scratch')
        job = s.admit('alice')
        gate, entered = threading.Event(), threading.Event()
        check, release = Mock(), Mock()
        def delayed(source, folder, stage):
            stage('cuts')
            entered.set()
            gate.wait(5)
            out = Path(folder)/'0.jpg'
            out.write_bytes(b'jpeg')
            return [dict(order=0, start=0, end=2, duration=2, file=str(out))]
        with patch('reference_videos.extract_video', side_effect=delayed):
            s.start('alice', job['id'], 'source.mp4', check, release)
            self.assertTrue(entered.wait(2))
            self.assertEqual(s.get('alice', job['id'])['status'], 'processing')
            gate.set()
            for t in s.threads:
                t.join(5)
        self.assertEqual(s.get('alice', job['id'])['status'], 'completed')
        release.assert_called_once()
        self.assertNotIn('source.mp4', media)
        self.assertEqual(list((self.root/'scratch').iterdir()), [])
        # A quota failure cannot leave published partial thumbnails or a source.
        media['source.mp4'] = b'input'
        job2 = s.admit('alice')
        storage.write_media.side_effect = StorageQuotaExceeded('sensitive details')
        with patch('reference_videos.extract_video', side_effect=delayed):
            s.start('alice', job2['id'], 'source.mp4')
            for t in s.threads:
                t.join(5)
        failed = s.get('alice', job2['id'])
        self.assertEqual(failed['status'], 'failed')
        self.assertEqual(failed['shots'], [])
        self.assertNotIn('sensitive', p.path.read_text())
        self.assertNotIn('source.mp4', media)
        # A revocation check fails before decoding and releases admission.
        media['source.mp4'] = b'input'
        job3 = s.admit('alice')
        revoked = Mock(side_effect=HTTPException(401, 'secret'))
        released = Mock()
        s.start('alice', job3['id'], 'source.mp4', revoked, released)
        for t in s.threads:
            t.join(5)
        self.assertEqual(s.get('alice', job3['id'])['status'], 'failed')
        released.assert_called_once()
        self.assertNotIn('secret', p.path.read_text())

    def test_packaging_and_missing_capability(self):
        import app
        for role in ('user', 'admin'):
            self.assertTrue(app.current_principal({'id': 'fixture', 'role': role})['capabilities']['video_projects'])
        from tools.build_desktop import ENGINE_SOURCES
        from reference_videos import extraction_capability
        from unittest.mock import patch
        self.assertIn('first_frames.py', ENGINE_SOURCES)
        self.assertIn('reference_videos.py', ENGINE_SOURCES)
        self.assertIn('video_projects.py', ENGINE_SOURCES)
        with patch('reference_videos.shutil.which', return_value=None):
            with self.assertRaises(HTTPException) as error:
                extraction_capability()
        self.assertEqual(error.exception.status_code, 503)

    def test_import_atomic_failure_concurrency_and_global_uuid_binding(self):
        from reference_videos import ReferenceService
        from unittest.mock import patch
        p = ProjectService(self.root/'atomic.json')
        service = ReferenceService(p, None, self.root/'scratch')
        job = service.admit('alice')
        service.update('alice', job['id'], status='completed', shots=[
            dict(id='a', order=0, start=0, end=2, duration=2)])
        request = dict(request_id=str(uuid4()), shot_ids=['a'])
        with patch.object(p, 'save', side_effect=OSError('synthetic')):
            with self.assertRaises(OSError):
                service.import_shots('alice', job['id'], request)
        self.assertEqual(len(p.data['projects']), 0)
        self.assertEqual(p.data['reference_imports'], {})
        results = []
        workers = [threading.Thread(target=lambda: results.append(service.import_shots('alice', job['id'], request)['id'])) for _ in range(4)]
        for t in workers:
            t.start()
        for t in workers:
            t.join()
        self.assertEqual(len(results), 4)
        self.assertEqual(len(set(results)), 1)
        with self.assertRaises(HTTPException) as conflict:
            p.receipt('alice', results[0], 'render', dict(revision=1, request_id=request['request_id']))
        self.assertEqual(conflict.exception.status_code, 409)

    def test_real_ffmpeg_cut_and_midpoint_keyframes(self):
        from reference_videos import extract_video
        source = self.root/'source.mp4'
        subprocess.run(['ffmpeg', '-v', 'error', '-f', 'lavfi', '-i',
                        'color=red:s=160x90:r=10:d=2', '-f', 'lavfi', '-i',
                        'color=blue:s=160x90:r=10:d=2', '-filter_complex',
                        '[0:v][1:v]concat=n=2:v=1:a=0', '-threads', '1', str(source)],
                       check=True, timeout=30)
        stages = []
        shots = extract_video(source, self.root, stages.append)
        self.assertEqual(stages, ['probe', 'cuts', 'thumbnails'])
        self.assertEqual(len(shots), 2)
        self.assertAlmostEqual(shots[0]['end'], 2, places=1)
        self.assertAlmostEqual(shots[1]['duration'], 2, places=1)
        for shot in shots:
            self.assertTrue(Path(shot['file']).read_bytes().startswith(b'\xff\xd8'))


if __name__ == '__main__':
    unittest.main()
