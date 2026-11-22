import io
import math
import struct
import tempfile
import unittest
import wave
from pathlib import Path
from unittest.mock import patch


def audio_fixture(seconds=0.5):
    out = io.BytesIO()
    with wave.open(out, 'wb') as w:
        w.setparams((1, 2, 24000, 0, 'NONE', 'not compressed'))
        w.writeframes(b''.join(struct.pack('<h', int(8000 * math.sin(i * 2 * math.pi * 440 / 24000))) for i in range(int(seconds * 24000))))
    return out.getvalue()


class NarrationTest(unittest.TestCase):
    def test_durable_narration_replay_stale_and_restart(self):
        from video_projects import ProjectService
        from fastapi import HTTPException
        from uuid import uuid4
        with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as folder:
            service = ProjectService(Path(folder) / 'p.json')
            p = service.create('a', {'title': 'Demo', 'idea': 'Hi'})
            p = service.patch('a', p['id'], {'revision': p['revision'], 'script': 'Hi', 'scenes': [
                {'order': 0, 'narration': 'Hi', 'prompt': 'Sky', 'duration': 1}]})
            sid = p['scenes'][0]['id']
            request = {'revision': p['revision'], 'request_id': str(uuid4()), 'confirm_cost': True}
            calls = []
            def synth(scene):
                calls.append(scene['narration'])
                return {'media_id': 'audio.wav', 'duration': .5, 'provider': 'openai', 'model': 'fixture', 'voice': 'fixture'}
            accepted = service.narrate('a', p['id'], sid, request, synth)
            self.assertEqual(accepted['scenes'][0]['narration_audio']['status'], 'queued')
            for t in service.threads:
                t.join(5)
            service.narrate('a', p['id'], sid, request, synth)
            self.assertEqual(calls, ['Hi'])
            self.assertEqual(service.request_status('a', p['id'], request['request_id'])['status'], 'completed')
            with self.assertRaises(HTTPException) as exc:
                service.narrate('b', p['id'], sid, request, synth)
            self.assertEqual(exc.exception.status_code, 404)
            p = service.get('a', p['id'])
            scene = {k: v for k, v in p['scenes'][0].items() if k not in ('attempts', 'narration_audio')}
            scene['narration'] = 'Changed'
            p = service.patch('a', p['id'], {'revision': p['revision'], 'scenes': [scene]})
            self.assertEqual(p['scenes'][0]['narration_audio']['status'], 'stale')
            state = service.data['projects'][p['id']]['scenes'][0]['narration_audio']
            state['status'] = 'processing'
            service.save()
            restarted = ProjectService(service.path)
            self.assertEqual(restarted.get('a', p['id'])['scenes'][0]['narration_audio']['status'], 'unknown')
            self.assertEqual(restarted.request_status('a', p['id'], request['request_id'])['status'], 'unknown')

    def test_captions_actual_duration_and_stale_rejected(self):
        from narration import captions, binding
        from fastapi import HTTPException
        scene = {'order': 0, 'narration': 'Hello', 'duration': 2}
        scene['narration_audio'] = dict(status='completed', source_revision=binding(scene), media_id='x', duration=.5)
        self.assertIn('00:00:00,000 --> 00:00:00,500', captions([scene], 'srt'))
        self.assertTrue(captions([scene], 'vtt').startswith('WEBVTT'))
        scene['narration'] = 'Changed'
        with self.assertRaises(HTTPException):
            captions([scene], 'srt')

    def test_real_adapter_binary_request_without_credentials_or_network(self):
        from narration import OpenAISpeech
        import os
        class Response:
            status_code = 200
            headers = {'Content-Type': 'application/octet-stream'}
            def __enter__(self): return self
            def __exit__(self, *args): pass
            def iter_content(self, size): yield audio_fixture()[44:]
        with patch.dict(os.environ, {'MUSE_TTS_PROVIDER': 'openai', 'MUSE_TTS_API_KEY': 'synthetic-key'}, clear=False), patch('narration.requests.Session') as session:
            transport = session.return_value.__enter__.return_value
            transport.post.return_value = Response()
            data, duration = OpenAISpeech().generate('Hi', 1)
            self.assertEqual(data, audio_fixture())
            self.assertEqual(duration, .5)
            args, kwargs = transport.post.call_args
            self.assertEqual(args[0], 'https://api.openai.com/v1/audio/speech')
            self.assertEqual(kwargs['json']['response_format'], 'pcm')
            self.assertFalse(kwargs['allow_redirects'])
            self.assertFalse(transport.trust_env)
            Response.status_code = 302
            with self.assertRaises(ValueError):
                OpenAISpeech().generate('Hi', 1)
            self.assertEqual(transport.post.call_count, 2)
            Response.status_code = 200
            Response.iter_content = lambda self, size: iter([b'x' * (8*1024**2 + 1)])
            with self.assertRaises(ValueError):
                OpenAISpeech().generate('Hi', 1)

    def test_vieneu_gradio_single_submission_and_private_download(self):
        import json
        import os
        from unittest.mock import MagicMock
        from narration import speech_adapter, capability
        origin = 'https://tts.example.test'
        event = 'e' * 32
        path = '/data/tmp/gradio/' + 'a' * 64 + '/audio.wav'

        def response(data):
            obj = MagicMock()
            obj.__enter__.return_value = obj
            obj.status_code = 200
            obj.iter_content.return_value = [data]
            return obj

        with patch.dict(os.environ, {'MUSE_TTS_PROVIDER': 'vieneu-gradio', 'MUSE_TTS_GRADIO_URL': origin,
                                     'MUSE_TTS_VOICE': 'Thiện Minh'}, clear=False), patch('narration.requests.Session') as factory:
            adapter = speech_adapter()
            self.assertEqual(capability()['provider'], 'vieneu-gradio')
            transport = factory.return_value.__enter__.return_value
            transport.post.return_value = response(json.dumps({'event_id': event}).encode())
            file = {'path': path, 'url': 'https://untrusted.example/audio.wav'}
            sse = 'event: generating\ndata: [null]\n\nevent: complete\ndata: ' + json.dumps([file]) + '\n\n'
            transport.get.side_effect = [response(sse.encode()), response(audio_fixture())]
            self.assertEqual(adapter.generate('Xin chào', 1), (audio_fixture(), .5))
            args, kwargs = transport.post.call_args
            self.assertEqual(args, (origin + '/gradio_api/call/wrapper',))
            self.assertEqual(kwargs['json']['data'], ['Xin chào', 'Thiện Minh', None, None, None,
                             'Standard (Một lần)', False, 1, .8, 256, True, None])
            self.assertEqual([c.args[0] for c in transport.get.call_args_list],
                             [args[0] + '/' + event, origin + '/gradio_api/file=' + path])
            self.assertFalse(transport.trust_env)
            for call in [transport.post.call_args, *transport.get.call_args_list]:
                self.assertFalse(call.kwargs['allow_redirects'])
                self.assertNotIn('headers', call.kwargs)
            self.assertEqual(transport.post.call_count, 1)

    def test_vieneu_rejects_bad_origin_events_and_file_paths(self):
        import os
        import json
        from fastapi import HTTPException
        from narration import VieNeuSpeech
        for origin in ('http://tts.test', 'https://user@tts.test', 'https://tts.test/proxy', ''):
            with self.subTest(origin=origin), patch.dict(os.environ, {'MUSE_TTS_GRADIO_URL': origin}):
                with self.assertRaises(HTTPException):
                    VieNeuSpeech().preflight()
        for file in (None, {'url': 'https://tts.test/a.wav'}, {'path': '/etc/passwd'},
                     {'path': '/tmp/gradio/' + 'a' * 64 + '/../x.wav'}):
            with self.subTest(file=file), self.assertRaises(ValueError):
                VieNeuSpeech._audio_path('event: complete\ndata: ' + json.dumps([file]))
        with self.assertRaises(ValueError):
            VieNeuSpeech._audio_path('event: error\ndata: null')

    def test_concurrent_edit_capacity_uuid_conflict_and_no_secret_persistence(self):
        import threading
        from video_projects import ProjectService
        from fastapi import HTTPException
        from uuid import uuid4
        with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as folder:
            service = ProjectService(Path(folder) / 'p.json')
            p = service.create('a', {'title': 'Demo', 'idea': 'Hi'})
            p = service.patch('a', p['id'], {'revision': p['revision'], 'script': 'Hi', 'scenes': [
                {'order': 0, 'narration': 'Hi', 'prompt': 'Sky', 'duration': 1}]})
            sid = p['scenes'][0]['id']
            request = dict(revision=p['revision'], request_id=str(uuid4()), confirm_cost=True)
            entered, release = threading.Event(), threading.Event()
            def synth(scene):
                entered.set()
                release.wait(5)
                return dict(media_id='fixture', duration=.5)
            try:
                service.narrate('a', p['id'], sid, request, synth)
                self.assertTrue(entered.wait(1))
                p = service.get('a', p['id'])
                with self.assertRaises(HTTPException) as exc:
                    service.narrate('a', p['id'], sid, dict(request, request_id=str(uuid4()), revision=p['revision']), synth)
                self.assertEqual(exc.exception.status_code, 429)
                scene = {k:v for k,v in p['scenes'][0].items() if k not in ('attempts', 'narration_audio')}
                scene['narration'] = 'Edited'
                service.patch('a', p['id'], dict(revision=p['revision'], scenes=[scene]))
            finally:
                release.set()
                for t in service.threads: t.join(5)
            self.assertEqual(service.get('a', p['id'])['scenes'][0]['narration_audio']['status'], 'stale')
            self.assertIsNone(service.get('a', p['id'])['scenes'][0]['narration_audio']['media_id'])
            self.assertEqual(service.request_status('a', p['id'], request['request_id'])['status'], 'stale')
            with self.assertRaises(HTTPException) as exc:
                service.receipt('a', p['id'], 'render', {k:request[k] for k in ('revision', 'request_id')})
            self.assertEqual(exc.exception.status_code, 409)

    def test_revoked_job_does_not_persist_audio(self):
        import app
        import threading
        from fastapi.testclient import TestClient
        from narration import OpenAISpeech
        from uuid import uuid4
        client = TestClient(app.app)
        admin = {'Authorization': 'Bearer ' + app.CFG.api_key}
        user = client.post('/admin/users', headers=admin, json={'label': 'Narration revoke'}).json()
        headers = {'Authorization': 'Bearer ' + user['api_key']}
        p = client.post('/v1/video-projects', headers=headers, json={'title': 'Speech', 'idea': 'Sky'}).json()
        path = '/v1/video-projects/' + p['id']
        p = client.patch(path, headers=headers, json={'revision': p['revision'], 'script': 'Hi', 'scenes': [
            {'order': 0, 'narration': 'Hi', 'prompt': 'Sky', 'duration': 1}]}).json()
        sid = p['scenes'][0]['id']
        entered, release = threading.Event(), threading.Event()
        def generate(*args):
            entered.set()
            release.wait(5)
            return audio_fixture(), .5
        with patch.object(OpenAISpeech, 'preflight'), patch.object(OpenAISpeech, 'generate', side_effect=generate):
            try:
                response = client.post(path+'/scenes/'+sid+'/narration', headers=headers,
                    json=dict(revision=p['revision'], request_id=str(uuid4()), confirm_cost=True))
                self.assertEqual(response.status_code, 200)
                self.assertTrue(entered.wait(1))
                client.patch('/admin/users/'+user['user']['id'], headers=admin, json={'enabled': False})
                self.assertEqual(client.get(path, headers=headers).status_code, 401)
            finally:
                release.set()
                for t in app.VIDEO_PROJECTS.threads: t.join(5)
        state = app.VIDEO_PROJECTS.get(user['user']['id'], p['id'])['scenes'][0]['narration_audio']
        self.assertEqual(state['status'], 'failed')
        self.assertIsNone(state['media_id'])

    def test_spoken_export_requires_current_audio_and_outdated_download_hidden(self):
        from video_projects import ProjectService
        from narration import binding
        from fastapi import HTTPException
        from uuid import uuid4
        with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as folder:
            service = ProjectService(Path(folder) / 'p.json')
            p = service.create('a', {'title': 'Demo', 'idea': 'Hi'})
            p = service.patch('a', p['id'], {'revision': p['revision'], 'script': 'Hi', 'scenes': [
                {'order': 0, 'narration': 'Hi', 'prompt': 'Sky', 'duration': 1}]})
            raw = service.data['projects'][p['id']]
            raw['script_approved'] = True
            scene = raw['scenes'][0]
            scene.update(approved=True, selected_attempt_id='take', attempts=[dict(id='take', status='completed', media_id='video')])
            raw['audio_mode'] = 'spoken'
            request = dict(revision=raw['revision'], request_id=str(uuid4()))
            for state in (None, dict(status='failed'), dict(status='stale')):
                scene['narration_audio'] = state
                with self.assertRaises(HTTPException):
                    service.render('a', p['id'], request, lambda *args: 'output', lambda _: True)
            scene['narration_audio'] = dict(id='n', status='completed', source_revision=binding(scene), media_id='audio', duration=.5)
            captured = []
            def renderer(clips, aspect):
                captured.extend(clips)
                return 'output'
            service.render('a', p['id'], request, renderer, lambda _: True)
            for t in service.threads: t.join(5)
            self.assertEqual(captured[0]['audio_media_id'], 'audio')
            self.assertEqual(service.render_media('a', p['id']), 'output')
            raw['render']['outdated'] = True
            self.assertIsNone(service.render_media('a', p['id']))

    def test_authenticated_capability_route_registered_before_project_id(self):
        import app
        paths = [r.path for r in app.app.routes]
        self.assertIn('/v1/video-projects/narration-capability', paths)
        self.assertLess(paths.index('/v1/video-projects/narration-capability'), paths.index('/v1/video-projects/{pid}'))

    def test_http_narration_authenticated_reload_captions_and_safe_failures(self):
        import app
        from narration import OpenAISpeech
        from fastapi.testclient import TestClient
        from uuid import uuid4
        client = TestClient(app.app)
        admin = {'Authorization': 'Bearer ' + app.CFG.api_key}
        user = client.post('/admin/users', headers=admin, json={'label': 'Narration fixture'}).json()
        headers = {'Authorization': 'Bearer ' + user['api_key']}
        owner = user['user']['id']
        p = client.post('/v1/video-projects', headers=headers, json={'title': 'Speech', 'idea': 'Sky'}).json()
        path = '/v1/video-projects/' + p['id']
        p = client.patch(path, headers=headers, json={'revision': p['revision'], 'script': 'Hi', 'scenes': [
            {'order': 0, 'narration': 'Hi', 'prompt': 'Sky', 'duration': 1}]}).json()
        sid = p['scenes'][0]['id']
        action = path + '/scenes/' + sid + '/narration'
        request = dict(revision=p['revision'], request_id=str(uuid4()), confirm_cost=True)
        self.assertEqual(client.get('/v1/video-projects/narration-capability').status_code, 401)
        self.assertEqual(client.post(action, json=request).status_code, 401)
        self.assertEqual(client.post(action, headers=headers, json={**request, 'confirm_cost': False}).status_code, 422)
        self.assertEqual(client.post(action, headers=admin, json=request).status_code, 404)
        with patch.object(OpenAISpeech, 'preflight'), patch.object(OpenAISpeech, 'generate', return_value=(audio_fixture(), .5)) as generate:
            response = client.post(action, headers=headers, json=request)
            self.assertEqual(response.status_code, 200, response.text)
            for t in app.VIDEO_PROJECTS.threads: t.join(5)
            self.assertEqual(client.post(action, headers=headers, json=request).status_code, 200)
            self.assertEqual(generate.call_count, 1)
        p = client.get(path, headers=headers).json()
        state = p['scenes'][0]['narration_audio']
        self.assertEqual(state['status'], 'completed', state)
        self.assertEqual(p['audio_mode'], 'spoken')
        self.assertEqual(client.get(action+'/audio', headers=headers).content, audio_fixture())
        self.assertEqual(client.get(action+'/audio', headers=admin).status_code, 404)
        self.assertEqual(client.get(path+'/captions?format=vtt', headers=headers).status_code, 200)
        self.assertIn('00:00:00.500', client.get(path+'/captions?format=vtt', headers=headers).text)
        self.assertEqual(client.get(path+'/requests/'+request['request_id'], headers=headers).json()['action'], 'narration')
        app.store.delete_media(state['media_id'], owner_id=owner)
        self.assertEqual(client.get(action+'/audio', headers=headers).status_code, 409)
        self.assertEqual(client.get(path+'/captions', headers=headers).status_code, 409)
        request.update(revision=p['revision'], request_id=str(uuid4()))
        with patch.object(OpenAISpeech, 'preflight'), patch.object(OpenAISpeech, 'generate', side_effect=ValueError('Bearer secret-in-provider-error')):
            self.assertEqual(client.post(action, headers=headers, json=request).status_code, 200)
            for t in app.VIDEO_PROJECTS.threads: t.join(5)
        result = client.get(path, headers=headers)
        self.assertNotIn('secret-in-provider-error', result.text)
        self.assertEqual(result.json()['scenes'][0]['narration_audio']['status'], 'failed')

    def test_real_mux_uses_narration_and_rejects_missing_corrupt_audio(self):
        import subprocess
        import json
        from video_projects import render_mp4
        with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as folder:
            root = Path(folder)
            subprocess.run(['ffmpeg', '-v', 'error', '-f', 'lavfi', '-i', 'color=c=red:s=160x90:r=24', '-t', '1', '-c:v', 'libx264', '-threads', '1', str(root/'source.mp4')], check=True)
            (root/'speech.wav').write_bytes(audio_fixture())
            class Store:
                def storage_usage(self, owner): return {'bytes': 0, 'files': 0, 'limits': {'bytes': 100000000, 'files': 100}}
                def media_owner(self, mid): return 'a' if (root/mid).exists() else None
                def open_media(self, mid): return (root/mid).open('rb')
                def write_media(self, mid, data, owner): (root/mid).write_bytes(data)
            clips = [{'media_id': 'source.mp4', 'duration': 1, 'audio_media_id': 'speech.wav'}]
            mid = render_mp4(Store(), 'a', clips, '16:9', root)
            info = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-show_streams', '-of', 'json', str(root/mid)]))
            self.assertIn('aac', [s['codec_name'] for s in info['streams']])
            decoded = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(root/mid), '-map', '0:a:0', '-f', 's16le', '-ac', '1', '-ar', '24000', '-'])
            self.assertGreater(max(abs(x[0]) for x in struct.iter_unpack('<h', decoded)), 1000)
            (root/'speech.wav').write_bytes(b'corrupt')
            with self.assertRaises(ValueError):
                render_mp4(Store(), 'a', clips, '16:9', root)
            (root/'speech.wav').unlink()
            with self.assertRaises(ValueError):
                render_mp4(Store(), 'a', clips, '16:9', root)

    def test_pcm_validation_rejects_corrupt_silent_and_overlong(self):
        from narration import validate_audio
        self.assertAlmostEqual(validate_audio(audio_fixture(), 1), 0.5)
        for data in (b'bad', audio_fixture(1.5), audio_fixture()[:-40]):
            with self.assertRaises(ValueError):
                validate_audio(data, 1)
        out = io.BytesIO()
        with wave.open(out, 'wb') as w:
            w.setparams((1, 2, 24000, 0, 'NONE', 'not compressed'))
            w.writeframes(b'\0' * 24000)
        with self.assertRaises(ValueError):
            validate_audio(out.getvalue(), 1)


if __name__ == '__main__':
    unittest.main()
