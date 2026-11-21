"""Local-only Shorts tracer bullets. Generated assets never leave isolated tenant storage."""
import tempfile
import unittest
from pathlib import Path
from fastapi import HTTPException
from video_projects import ProjectService


class ShortsTest(unittest.TestCase):
    def fixture(self, folder):
        from shorts import ShortsService
        p = ProjectService(Path(folder) / 'projects.json')
        project = p.create('a', dict(title='Demo', idea='Reuse'))
        project = p.patch('a', project['id'], dict(revision=1, scenes=[dict(order=0, narration='Xin chào Việt Nam', prompt='Colors', duration=3)]))
        raw = p.owned('a', project['id'])
        raw['script_approved'] = True
        raw['scenes'][0].update(approved=True, selected_attempt_id='take', attempts=[dict(id='take', status='completed', media_id='clip.mp4')])
        p.save()
        return p, ShortsService(p), project['id'], raw['scenes'][0]['id']

    def payload(self, p, pid, sid):
        return dict(project_revision=p.get('a', pid)['revision'], title='Short', scene_ids=[sid], start=.5, end=2.5, crop_x=1.0, burn_captions=False)

    def test_durable_draft_revision_source_and_isolation(self):
        with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as folder:
            p, shorts, pid, sid = self.fixture(folder)
            body = self.payload(p, pid, sid)
            s = shorts.create('a', pid, body)
            self.assertEqual(s['revision'], 1)
            self.assertTrue(s['source_current'])
            self.assertEqual(s['source']['scenes'][0]['take_id'], 'take')
            from shorts import ShortsService
            restarted = ShortsService(ProjectService(p.path))
            self.assertEqual(restarted.get('a', pid, s['id'])['source'], s['source'])
            with self.assertRaises(HTTPException) as e:
                shorts.get('b', pid, s['id'])
            self.assertEqual(e.exception.status_code, 404)
            shorts.update('a', pid, s['id'], dict(body, revision=1, crop_x=0.0))
            with self.assertRaises(HTTPException) as e:
                shorts.update('a', pid, s['id'], dict(body, revision=1))
            self.assertEqual(e.exception.status_code, 409)
            p.owned('a', pid)['aspect_ratio'] = '9:16'
            self.assertFalse(shorts.get('a', pid, s['id'])['source_current'])

    def test_uuid_snapshot_replay_approval_restart(self):
        import threading
        from uuid import uuid4
        from shorts import ShortsService
        with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as folder:
            p, shorts, pid, sid = self.fixture(folder)
            body = self.payload(p, pid, sid)
            s = shorts.create('a', pid, body)
            rid = str(uuid4())
            request = dict(revision=1, request_id=rid)
            entered, release = threading.Event(), threading.Event()
            calls = []
            def render(snapshot):
                calls.append(snapshot)
                entered.set()
                release.wait(3)
                return 'out.mp4'
            try:
                job = shorts.render('a', pid, s['id'], request, render, lambda: None)
                self.assertEqual(job['id'], rid)
                self.assertTrue(entered.wait(1))
                replay = shorts.render('a', pid, s['id'], request, render, lambda: self.fail('replay preflight'))
                self.assertEqual(replay['id'], rid)
                restarted = ShortsService(ProjectService(p.path))
                self.assertEqual(restarted.job('a', pid, s['id'], rid)['status'], 'unknown')
                shorts.update('a', pid, s['id'], dict(body, revision=1, crop_x=0.0))
                p.patch('a', pid, dict(revision=p.get('a',pid)['revision'],title='Concurrent project edit'))
            finally:
                release.set()
                for t in shorts.threads: t.join(5)
            self.assertEqual(len(calls), 1)
            self.assertEqual(calls[0]['crop_x'], 1.)
            # Project edits replace the project dict; worker must update durable current job.
            self.assertEqual(__import__('json').loads(p.path.read_text())['projects'][pid]['shorts'][s['id']]['jobs'][rid]['status'],'completed')
            self.assertEqual(shorts.job('a', pid, s['id'], rid)['status'], 'completed')
            with self.assertRaises(HTTPException) as e:
                shorts.approve('a', pid, s['id'], rid, 2)
            self.assertEqual(e.exception.status_code, 409)
            with self.assertRaises(HTTPException):
                shorts.render('a', pid, s['id'], dict(request, revision=2), render, lambda: None)
            with self.assertRaises(HTTPException):
                shorts.job('b', pid, s['id'], rid)

    def test_strict_bounds(self):
        with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as folder:
            p, shorts, pid, sid = self.fixture(folder)
            body = self.payload(p, pid, sid)
            for change in (dict(crop_x=-.1), dict(crop_x=float('nan')), dict(end=4.), dict(start=2.5), dict(scene_ids=[sid,sid]), dict(scene_ids=['foreign']), dict(url='https://example.com')):
                with self.subTest(change=change), self.assertRaises(HTTPException) as e:
                    shorts.create('a', pid, dict(body, **change))
                self.assertEqual(e.exception.status_code, 422)

    def test_geometry_caption_clipping_and_source_invalidation(self):
        from shorts_render import geometry, caption_text
        from narration import binding
        self.assertTrue(geometry(640,360,0.).startswith('crop=202:360:0:0'))
        self.assertTrue(geometry(640,360,1.).startswith('crop=202:360:438:0'))
        self.assertTrue(geometry(180,640,.5).startswith('crop=180:320:0:160'))
        with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as folder:
            p, shorts, pid, sid=self.fixture(folder)
            raw=p.owned('a',pid); scene=raw['scenes'][0]
            raw['audio_mode']='spoken'
            scene['narration_audio']=dict(id='audio',status='completed',source_revision=binding(scene),media_id='speech.wav',duration=1.)
            s=shorts.create('a',pid,self.payload(p,pid,sid))
            self.assertIn('00:00:00,000 --> 00:00:00,500',caption_text(s))
            for field,value in [('narration','Changed'),('selected_attempt_id','other'),('duration',2),('prompt','Changed')]:
                old=scene[field]; scene[field]=value
                self.assertFalse(shorts.get('a',pid,s['id'])['source_current'])
                scene[field]=old
            scene['narration_audio']['id']='another'
            self.assertFalse(shorts.get('a',pid,s['id'])['source_current'])

    def test_capacity_cross_short_uuid_and_failure_redaction(self):
        import threading
        from uuid import uuid4
        with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as folder:
            p,shorts,pid,sid=self.fixture(folder)
            body=self.payload(p,pid,sid)
            s=shorts.create('a',pid,body); other=shorts.create('a',pid,body)
            entered,release=threading.Event(),threading.Event()
            def renderer(snapshot):
                entered.set(); release.wait(3)
                raise ValueError('SECRET /internal/path')
            rid=str(uuid4())
            try:
                shorts.render('a',pid,s['id'],dict(revision=1,request_id=rid),renderer,lambda:None)
                self.assertTrue(entered.wait(1))
                with self.assertRaises(HTTPException) as e:
                    shorts.render('a',pid,other['id'],dict(revision=1,request_id=rid),renderer,lambda:None)
                self.assertEqual(e.exception.status_code,409)
                with self.assertRaises(HTTPException) as e:
                    shorts.render('a',pid,other['id'],dict(revision=1,request_id=str(uuid4())),renderer,lambda:None)
                self.assertEqual(e.exception.status_code,429)
            finally:
                release.set()
                for t in shorts.threads:t.join(5)
            job=shorts.job('a',pid,s['id'],rid)
            self.assertEqual(job['status'],'failed')
            self.assertNotIn('SECRET',str(job))

    def test_real_render_crop_segment_audio_captions_and_frame(self):
        import subprocess
        import json
        import io
        from shorts_render import render_short, preview_frame, caption_text, capability
        with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as folder:
            root = Path(folder)
            # Nonuniform spatial and temporal source: red left / blue right, then green.
            subprocess.run(['ffmpeg','-v','error','-f','lavfi','-i',
                'color=red:s=640x360:r=24:d=3,drawbox=x=320:y=0:w=320:h=360:color=blue:t=fill,drawbox=x=0:y=0:w=640:h=360:color=green:t=fill:enable=gte(t\\,1.5)',
                '-f','lavfi','-i','sine=frequency=440:duration=3','-c:v','libx264','-threads','1','-c:a','aac','-shortest',str(root/'clip.mp4')], check=True)
            class Store:
                def media_owner(self, mid): return 'a'
                def open_media(self, mid): return (root/mid).open('rb')
                def write_media(self, mid, data, owner): (root/mid).write_bytes(data)
                def storage_usage(self, owner): return dict(bytes=0,files=1,limits=dict(bytes=10**9,files=100))
            p, shorts, pid, sid = self.fixture(folder)
            s = shorts.create('a', pid, self.payload(p,pid,sid))
            self.assertTrue(capability()['available'])
            self.assertIn('Việt Nam',caption_text(s,'vtt'))
            self.assertIn('00:00:00,000 --> 00:00:02,000',caption_text(s,'srt'))
            frame = preview_frame(Store(),'a',s,root,0.)
            self.assertEqual(frame[:2],b'\xff\xd8')
            mid = render_short(Store(),'a',s,root)
            info=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(root/mid)]))
            video=next(x for x in info['streams'] if x['codec_type']=='video')
            self.assertEqual((video['width'],video['height']),(720,1280))
            self.assertAlmostEqual(float(info['format']['duration']),2.,delta=.15)
            subprocess.run(['ffmpeg','-v','error','-xerror','-i',str(root/mid),'-f','null','-'],check=True)
            def pixel(at):
                return subprocess.check_output(['ffmpeg','-v','error','-ss',str(at),'-i',str(root/mid),'-frames:v','1','-vf','scale=1:1','-f','rawvideo','-pix_fmt','rgb24','-'])
            blue=pixel(.1); green=pixel(1.5)
            self.assertGreater(blue[2],blue[0]+100)
            self.assertGreater(green[1],green[2]+50)
            # Reuse actual fixture narration, unrelated to configured provider credentials.
            from tests.test_narration import audio_fixture
            (root/'speech.wav').write_bytes(audio_fixture(1.))
            spoken=__import__('copy').deepcopy(s)
            spoken['source']['scenes'][0]['audio']=dict(media_id='speech.wav',duration=1.)
            self.assertIn('00:00:00,000 --> 00:00:00,500',caption_text(spoken))
            speech_mid=render_short(Store(),'a',spoken,root)
            import struct
            pcm=subprocess.check_output(['ffmpeg','-v','error','-i',str(root/speech_mid),'-map','0:a:0','-ac','1','-ar','8000','-f','s16le','-'])
            samples=[v[0] for v in struct.iter_unpack('<h',pcm)]
            self.assertGreater(max(abs(x) for x in samples[:2000]),1000)
            self.assertLess(max(abs(x) for x in samples[8000:]),64)
            # Intentional silent legacy remains silence; no invented voice.
            subprocess.run(['ffmpeg','-v','error','-i',str(root/'clip.mp4'),'-an','-c:v','copy',str(root/'silent.mp4')],check=True)
            silent=__import__('copy').deepcopy(s)
            silent['source']['scenes'][0]['media_id']='silent.mp4'
            silent_mid=render_short(Store(),'a',silent,root)
            pcm=subprocess.check_output(['ffmpeg','-v','error','-i',str(root/silent_mid),'-map','0:a:0','-ac','1','-ar','8000','-f','s16le','-'])
            self.assertEqual(max(abs(v[0]) for v in struct.iter_unpack('<h',pcm)),0)
            if capability()['burn_captions']:
                burned=render_short(Store(),'a',dict(s,burn_captions=True),root)
                self.assertTrue((root/burned).stat().st_size>1000)

    def test_http_contract_auth_stale_receipt_and_no_provider(self):
        import app
        from fastapi.testclient import TestClient
        from uuid import uuid4
        from unittest.mock import patch
        client=TestClient(app.app)
        admin={'Authorization':'Bearer '+app.CFG.api_key}
        user=client.post('/admin/users',headers=admin,json={'label':'Short fixture'}).json()
        headers={'Authorization':'Bearer '+user['api_key']}
        owner=user['user']['id']
        p=client.post('/v1/video-projects',headers=headers,json=dict(title='Reuse',idea='Existing')).json()
        pid=p['id']; base=f'/v1/video-projects/{pid}/shorts'
        self.assertEqual(client.get(base+'/capability').status_code,401)
        self.assertEqual(client.get(base+'/capability',headers=headers).status_code,200)
        p=app.VIDEO_PROJECTS.patch(owner,pid,dict(revision=1,scenes=[dict(order=0,narration='Việt Nam',prompt='Colors',duration=3)]))
        raw=app.VIDEO_PROJECTS.owned(owner,pid)
        import subprocess
        with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as folder:
            source=Path(folder)/'source.mp4'
            subprocess.run(['ffmpeg','-v','error','-f','lavfi','-i','testsrc2=s=640x360:r=24:d=3','-f','lavfi','-i','sine=frequency=440:duration=3','-c:v','libx264','-threads','1','-c:a','aac','-shortest',str(source)],check=True)
            app.store.write_media('short_fixture.mp4',source.read_bytes(),owner)
        raw['scenes'][0].update(approved=True,selected_attempt_id='take',attempts=[dict(id='take',status='completed',media_id='short_fixture.mp4')])
        body=dict(project_revision=p['revision'],title='Short',scene_ids=[raw['scenes'][0]['id']],start=.5,end=2.5,crop_x=.5,burn_captions=False)
        with patch.object(app,'create_video',side_effect=AssertionError('provider called')), patch.object(app,'chat_completions',side_effect=AssertionError('provider called')):
            response=client.post(base,headers=headers,json=body)
            self.assertEqual(response.status_code,201,response.text)
            s=response.json(); path=base+'/'+s['id']
            self.assertEqual(client.get(path,headers=admin).status_code,404)
            self.assertEqual(client.get(path).status_code,401)
            self.assertEqual(client.get(path,headers=headers).json()['revision'],1)
            self.assertEqual(len(client.get(base,headers=headers).json()['shorts']),1)
            self.assertEqual(client.patch(path,headers=headers,json=dict(body,revision=9)).status_code,409)
            rid=str(uuid4())
            self.assertEqual(client.get(path+'/renders/'+rid,headers=headers).status_code,404)
            frame=client.get(path+'/frame?revision=1&at=0',headers=headers)
            self.assertEqual(frame.status_code,200,frame.text[:100] if frame.status_code!=200 else '')
            self.assertEqual(frame.content[:2],bytes([255,216]))
            self.assertEqual(client.get(path+'/frame?revision=9',headers=headers).status_code,409)
            self.assertEqual(client.get(path+'/frame?revision=1',headers=admin).status_code,404)
            response=client.post(path+'/renders',headers=headers,json=dict(revision=1,request_id=rid))
            self.assertEqual(response.status_code,202,response.text)
            for t in app.SHORTS.threads: t.join(30)
            completed=client.get(path+'/renders/'+rid,headers=headers).json()
            self.assertEqual(completed['status'],'completed',completed)
            self.assertEqual(client.post(path+'/renders',headers=headers,json=dict(revision=1,request_id=rid)).status_code,202)
            video=client.get(path+'/renders/'+rid+'/video',headers=headers)
            self.assertEqual(video.status_code,200)
            self.assertEqual(video.content[4:8],b'ftyp')
            self.assertEqual(client.get(path+'/renders/'+rid+'/video',headers=admin).status_code,404)
            self.assertEqual(client.get(path+'/renders/'+rid+'/captions',headers=admin).status_code,404)
            self.assertIn('Việt Nam',client.get(path+'/renders/'+rid+'/captions?format=vtt',headers=headers).text)
            self.assertEqual(client.get(path+'/renders/'+rid+'/captions?format=bad',headers=headers).status_code,422)
            self.assertEqual(client.post(path+'/renders/'+rid+'/approve',headers=headers,json={'revision':1}).status_code,200)
            self.assertTrue(client.get(path,headers=headers).json()['output_eligible'])
            changed=client.patch(path,headers=headers,json=dict(body,revision=1,crop_x=0.)).json()
            self.assertFalse(changed['output_eligible'])
            self.assertEqual(client.post(path+'/renders/'+rid+'/approve',headers=headers,json={'revision':2}).status_code,409)
            client.patch('/admin/users/'+owner,headers=admin,json={'enabled':False})
            self.assertEqual(client.get(path,headers=headers).status_code,401)


if __name__ == '__main__':
    unittest.main()
