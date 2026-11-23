import copy
import json
import os
from pathlib import Path
import socket
import signal
import subprocess
import tempfile
import threading
import unittest
from unittest.mock import patch
from uuid import uuid4

from fastapi import HTTPException
from fastapi.testclient import TestClient
import app
from video_projects import ProjectService
from web_downloads import DownloadService, normalize_url, run_download
from web_download_worker import (
    public_address, install_guards, select_formats, classify_error, safe_diagnostic,
    DiagnosticLogger, youtube_support, DENO_VERSION, EJS_VERSION, DENO_SAFE_OPTIONS,
)


class DownloadTest(unittest.TestCase):
    @unittest.skipUnless(os.name == 'posix', 'POSIX process-group cleanup')
    def test_cancel_terminates_only_the_owned_worker_process_group(self):
        class Process:
            pid = 43210
            waits = 0
            def poll(self): return None
            def wait(self, timeout=None):
                self.waits += 1
                if self.waits == 1:
                    raise subprocess.TimeoutExpired('synthetic-worker', 5)
                return -9
        cancelled = threading.Event()
        cancelled.set()
        with tempfile.TemporaryDirectory() as folder, \
             patch('web_downloads.subprocess.Popen', return_value=Process()) as spawn, \
             patch('web_downloads.os.killpg') as kill:
            with self.assertRaises(InterruptedError):
                run_download('https://youtube.com/watch?v=fixture',480,Path(folder),lambda _:None,lambda:None,cancelled)
            self.assertTrue(spawn.call_args.kwargs['start_new_session'])
            self.assertEqual(kill.call_args_list, [
                unittest.mock.call(43210, signal.SIGTERM), unittest.mock.call(43210, signal.SIGKILL),
            ])

    def test_safe_youtube_diagnostics_and_readiness(self):
        examples = [
            ('Sign in to confirm you are not a bot', 'unavailable', 'youtube_bot_check'),
            ('Private video. Please sign in', 'authentication_required', 'youtube_login_required'),
            ('No supported JavaScript runtime could be found', 'unavailable', 'youtube_js_runtime_missing'),
            ('EJS scripts are not installed', 'unavailable', 'youtube_ejs_missing'),
            ('n challenge solving failed', 'unavailable', 'youtube_js_challenge_failed'),
            ('Missing a required PO Token', 'unavailable', 'youtube_po_token_required'),
            ('HTTP Error 429: Too Many Requests', 'unavailable', 'upstream_rate_limited'),
            ('HTTP Error 403: Forbidden', 'unavailable', 'upstream_forbidden'),
            ('Extract failed. See https://fixture.invalid/login?cookies=synthetic', 'unavailable', 'upstream_failure'),
            ('Player extraction failed; see FAQ for cookies instructions', 'unavailable', 'upstream_failure'),
        ]
        for message, error, reason in examples:
            with self.subTest(reason=reason):
                self.assertEqual(classify_error(message, True), (error, reason))
        logger = DiagnosticLogger(True)
        for message, _, _ in examples:
            logger.warning(message + ' SECRET_SYNTHETIC_MARKER')
        for key in ('warning', 'error', 'debug'):
            getattr(logger, key)('https://fixture.invalid/?key=SECRET_SYNTHETIC_MARKER')
        diagnostic = safe_diagnostic('youtube_bot_check', logger.flags)
        self.assertNotIn('SECRET_SYNTHETIC_MARKER', json.dumps(diagnostic))
        self.assertLessEqual(len(diagnostic['flags']), 8)
        self.assertEqual(safe_diagnostic('SECRET_SYNTHETIC_MARKER', ['SECRET_SYNTHETIC_MARKER'])['reason'], 'upstream_failure')
        with patch('web_download_worker.importlib.metadata.version', return_value=EJS_VERSION), \
             patch('web_download_worker.shutil.which', return_value='/synthetic/deno'), \
             patch('web_download_worker._deno_version', return_value=DENO_VERSION):
            self.assertTrue(youtube_support()['available'])
            self.assertFalse(youtube_support()['live_verified'])
        with patch('web_download_worker.importlib.metadata.version', return_value=EJS_VERSION), \
             patch('web_download_worker.shutil.which', return_value=None):
            self.assertEqual(youtube_support()['diagnostic']['reason'], 'youtube_js_runtime_missing')
        with patch('web_download_worker.importlib.metadata.version', return_value='0.0.0'), \
             patch('web_download_worker.shutil.which', return_value=None):
            self.assertEqual(youtube_support()['diagnostic']['reason'], 'youtube_ejs_missing')
        with patch('web_download_worker.importlib.metadata.version', return_value=EJS_VERSION), \
             patch('web_download_worker.shutil.which', return_value='/synthetic/deno'), \
             patch('web_download_worker._deno_version', return_value='0.0.0'):
            self.assertEqual(youtube_support()['diagnostic']['reason'], 'youtube_js_runtime_unsupported')

    def test_deno_guard_allows_only_version_or_restricted_stdin(self):
        calls = []
        class Capture:
            def __init__(self, args, *extra, **kwargs):
                calls.append((args, kwargs))
        def which(name):
            return '/synthetic/' + Path(name).name
        with patch('subprocess.Popen', Capture), patch('shutil.which', side_effect=which), \
             patch.object(socket.socket, 'connect'), patch.object(socket.socket, 'connect_ex'):
            install_guards()
            subprocess.Popen(['deno', '--version'])
            subprocess.Popen(['deno', 'run', '--no-config', '--cached-only', '-'], env={'SECRET': 'synthetic'})
            command, options = calls[-1]
            self.assertEqual(command, ['/synthetic/deno', 'run', *DENO_SAFE_OPTIONS, '-'])
            self.assertNotIn('SECRET', options['env'])
            for args in (
                ['deno', 'eval', '1+1'], ['deno', 'run', '/etc/passwd'],
                ['deno', 'run', '--allow-all', '-'], ['deno', 'run', '--allow-net', '-'],
                ['deno', 'run', '--v8-flags=--expose-gc', '-'], ['node', '-e', '1+1'],
            ):
                with self.assertRaises(PermissionError): subprocess.Popen(args)
            with self.assertRaises(PermissionError):
                subprocess.Popen(['deno', '--version'], executable='/bin/sh')

    def test_url_and_connection_guards(self):
        for url in ('http://127.0.0.1/video', 'https://youtube.com.evil.test/x',
                    'file:///etc/passwd', 'https://user:pass@youtube.com/a',
                    'https://youtube.com:8080/a'):
            with self.assertRaises(HTTPException):
                normalize_url(url)
        self.assertEqual(normalize_url('https://www.youtube.com/watch?v=fixture#t=1')[1], 'YouTube')
        for host in ('127.0.0.1', '10.1.2.3', '169.254.169.254', '::1', '::ffff:127.0.0.1'):
            with patch('socket.getaddrinfo', return_value=[
                (socket.AF_INET, socket.SOCK_STREAM, 6, '', (host, 443))]):
                with self.assertRaises(PermissionError):
                    public_address('cdn.example', 443, socket.AF_INET)
        with self.assertRaises(PermissionError):
            public_address('cdn.example', 22, socket.AF_INET)
        with patch('socket.getaddrinfo', return_value=[
            (socket.AF_INET, socket.SOCK_STREAM, 6, '', ('8.8.8.8', 443)),
            (socket.AF_INET, socket.SOCK_STREAM, 6, '', ('10.0.0.1', 443))]):
            with self.assertRaises(PermissionError):
                public_address('mixed.example', 443, socket.AF_INET)
        # Guards must apply at connect time, including a DNS answer changing to private.
        original_popen = subprocess.Popen
        class NoProcess:
            def __init__(self, *args, **kwargs):
                raise AssertionError('Process execution forbidden in guard test')
        try:
            with (
                patch.object(socket.socket, 'connect', return_value=None) as connect,
                patch.object(socket.socket, 'connect_ex', return_value=0),
                patch('socket.getaddrinfo', return_value=[
                    (socket.AF_INET, socket.SOCK_STREAM, 6, '', ('8.8.8.8', 443))]),
            ):
                subprocess.Popen = NoProcess
                install_guards()
                with socket.socket() as sock:
                    sock.connect(('public.example', 443))
                connect.assert_called_once()
                with self.assertRaises(PermissionError):
                    subprocess.Popen(['curl', 'https://example.com'])
        finally:
            subprocess.Popen = original_popen

    def test_portrait_quality_and_merge_selection(self):
        audio = dict(format_id='audio',ext='m4a',vcodec='none',acodec='aac',protocol='https')
        portrait = dict(format_id='portrait',ext='mp4',vcodec='h264',acodec='none',
                        width=720,height=1280,protocol='https')
        oversized = dict(portrait,format_id='large',width=1080,height=1920)
        result = list(select_formats({'formats':[audio,portrait,oversized]},720))
        self.assertEqual(result[0]['requested_formats'],[portrait,audio])
        self.assertEqual(result[0]['protocol'],'https+https')
        self.assertEqual(list(select_formats({'formats':[oversized]},480)),[])

    def test_http_replay_owned_media_and_restart(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            def runner(url, quality, scratch, observe, check, cancelled):
                check()
                observe(dict(stage='downloading', downloaded=1, total=2, title='Video tổng hợp'))
                output = scratch/'video.mp4'
                subprocess.run(['ffmpeg','-v','error','-f','lavfi','-i','color=red:s=160x90:r=10',
                                '-t','1','-c:v','libx264','-threads','1',str(output)],check=True,timeout=20)
                return output, dict(stage='completed',title='Video tổng hợp',duration=1,height=90)
            projects = ProjectService(root/'projects.json')
            service = DownloadService(projects, app.store, root/'scratch', runner)
            client = TestClient(app.app)
            _, key = app.users.create('Download fixture')
            _, foreign = app.users.create('Other download fixture')
            auth = {'Authorization':'Bearer '+key}
            other = {'Authorization':'Bearer '+foreign}
            payload = dict(request_id=str(uuid4()), url='https://www.youtube.com/watch?v=fixture', quality=720)
            with patch.object(app,'WEB_DOWNLOADS',service):
                self.assertEqual(client.post('/v1/video-downloads',json=payload).status_code,401)
                self.assertEqual(client.post('/v1/video-downloads',headers=auth,
                    content=b'x'*(32*1024+1)).status_code,413)
                response = client.post('/v1/video-downloads',headers=auth,json=payload)
                self.assertEqual(response.status_code,202,response.text)
                jid = response.json()['id']
                for thread in service.threads:
                    thread.join(15)
                job = client.get('/v1/video-downloads/'+jid,headers=auth).json()
                self.assertEqual(job['status'],'completed',job)
                self.assertTrue(job['media_id'].endswith('.mp4'))
                self.assertNotIn('owner_id',job)
                self.assertEqual(client.get('/v1/video-downloads/'+jid,headers=other).status_code,404)
                receipt = '/v1/video-downloads/requests/'+payload['request_id']
                self.assertEqual(client.get(receipt,headers=auth).json()['id'],jid)
                self.assertEqual(client.get(receipt,headers=other).status_code,404)
                self.assertEqual(client.post('/v1/video-downloads',headers=auth,json=payload).json()['id'],jid)
                self.assertEqual(client.post('/v1/video-downloads',headers=auth,
                    json=dict(payload,quality=480)).status_code,409)
                self.assertEqual(len(service.threads),1)
                restarted = DownloadService(ProjectService(projects.path),app.store,root/'scratch',runner)
                with patch.object(app,'WEB_DOWNLOADS',restarted):
                    self.assertEqual(client.get(receipt,headers=auth).json()['status'],'completed')
                    self.assertEqual(client.get('/v1/video-downloads',headers=auth).json()['downloads'][0]['id'],jid)

    def test_quota_failure_and_global_uuid_are_preserved(self):
        from protection import StorageQuotaExceeded
        class Authority:
            worker_owned = False
            def __init__(self): self.releases = 0
            def check(self): pass
            def release(self): self.releases += 1
        def runner(url, quality, root, observe, check, cancelled):
            output = root/'video.mp4'
            output.write_bytes(b'synthetic')
            return output, dict(title='Fixture',duration=1,height=90)
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            projects = ProjectService(root/'projects.json')
            service = DownloadService(projects, app.store, root/'scratch', runner)
            fields = dict(request_id=str(uuid4()),url='https://vimeo.com/123',quality=720)
            authority = Authority()
            with (
                patch('web_downloads.capability',return_value={'available':True}),
                patch.object(app.store,'write_media',side_effect=StorageQuotaExceeded('Synthetic quota')),
            ):
                job,_ = service.create('fixture',fields,authority,lambda:None)
                for thread in service.threads: thread.join(5)
            saved = service.get('fixture',job['id'])
            self.assertEqual(saved['status'],'failed')
            self.assertEqual(saved['error_code'],'quota')
            self.assertIsNone(saved['media_id'])
            self.assertEqual(authority.releases,1)
            self.assertFalse(list((root/'scratch').iterdir()))
            used = str(uuid4())
            projects.data['image_imports']={'fixture:'+used:dict(project='synthetic')}
            with self.assertRaises(HTTPException) as conflict:
                service.create('fixture',dict(fields,request_id=used),Authority(),lambda:None)
            self.assertEqual(conflict.exception.status_code,409)

    def test_failed_job_persists_only_safe_diagnostics_and_replays(self):
        class Authority:
            worker_owned = False
            def check(self): pass
            def release(self): pass
        def runner(*args):
            return None, dict(error_code='SECRET_SYNTHETIC_MARKER', diagnostic=dict(
                reason='youtube_bot_check', message='SECRET_SYNTHETIC_MARKER',
                flags=['youtube_js_challenge_failed', 'https://fixture.invalid/SECRET_SYNTHETIC_MARKER']))
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            projects = ProjectService(root/'projects.json')
            service = DownloadService(projects, app.store, root/'scratch', runner)
            payload = dict(request_id=str(uuid4()),url='https://youtube.com/watch?v=fixture',quality=480)
            with patch('web_downloads.capability',return_value={'available':True}):
                job,_ = service.create('fixture',payload,Authority(),lambda:None)
            for thread in service.threads: thread.join(5)
            result = service.get('fixture',job['id'])
            self.assertEqual(result['status'],'failed')
            self.assertEqual(result['error_code'],'unavailable')
            self.assertEqual(result['diagnostic']['reason'],'youtube_bot_check')
            self.assertEqual(result['diagnostic']['flags'],['youtube_js_challenge_failed'])
            self.assertNotIn('SECRET_SYNTHETIC_MARKER',projects.path.read_text())
            restarted = DownloadService(ProjectService(projects.path),app.store,root/'scratch',runner)
            self.assertEqual(restarted.receipt('fixture',payload['request_id'])['diagnostic'],result['diagnostic'])
            replay,created = restarted.create('fixture',payload,Authority(),lambda:None)
            self.assertFalse(created)
            self.assertEqual(replay['id'],result['id'])
            self.assertFalse(restarted.threads)

    def test_cancellation_and_interrupted_restart(self):
        class Authority:
            worker_owned = False
            def __init__(self): self.releases = 0
            def check(self): pass
            def release(self): self.releases += 1
        def runner(url, quality, root, observe, check, cancelled):
            cancelled.wait(3)
            raise InterruptedError()
        with tempfile.TemporaryDirectory() as folder:
            projects = ProjectService(Path(folder)/'projects.json')
            service = DownloadService(projects,app.store,Path(folder)/'scratch',runner)
            authority = Authority()
            fields = dict(request_id=str(uuid4()),url='https://vimeo.com/123456',quality=480)
            with patch('web_downloads.capability',return_value={'available':True}):
                job,_ = service.create('fixture',fields,authority,lambda:None)
            with self.assertRaises(HTTPException):
                service.cancel('other',job['id'])
            with projects.lock:
                projects.data = copy.deepcopy(projects.data)
            service.cancel('fixture',job['id'])
            for thread in service.threads: thread.join(5)
            self.assertEqual(service.get('fixture',job['id'])['status'],'cancelled')
            self.assertEqual(authority.releases,1)
            projects.data['web_downloads'][job['id']]['status']='processing'
            projects.save()
            restarted=DownloadService(ProjectService(projects.path),app.store,Path(folder)/'scratch',runner)
            self.assertEqual(restarted.get('fixture',job['id'])['status'],'unknown')


if __name__ == '__main__':
    unittest.main()
