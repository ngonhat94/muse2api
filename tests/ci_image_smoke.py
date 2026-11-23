"""Exercise the built image against temporary synthetic state, never production.

Runs rollout/restart/failed-candidate rollback with the actual Docker daemon.
Only this invocation's containers, tags, and temporary directories are removed.
"""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tarfile
import tempfile
import urllib.error
import urllib.request
import uuid

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('release', ROOT / 'deploy/instabox_release.py')
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


def main(image, sha):
    # Purely local EJS fixtures; kernel-enforced no-network/no-write image check.
    subprocess.run(['docker', 'run', '--rm', '--network', 'none', '--read-only',
                    '--tmpfs', '/tmp:rw,noexec,nosuid,nodev,size=268435456',
                    '--cap-drop=ALL', '--security-opt=no-new-privileges',
                    '--memory=1g', '--pids-limit=64',
                    '-e', 'PYTHONDONTWRITEBYTECODE=1', '--entrypoint', 'python',
                    image, 'tools/check_youtube_runtime.py'], check=True, timeout=120)
    name = 'ci-' + uuid.uuid4().hex[:12]
    bad_sha = '0' * 40
    # Tag a service-owned copy so the rollout cannot operate on production names.
    good = f'muse2api-{name}:{sha}'
    bad = f'muse2api-{name}:{bad_sha}'
    with tempfile.TemporaryDirectory(prefix='muse2api-image-') as directory:
        root = Path(directory)
        (root / 'uploads').mkdir()
        with socket.socket() as sock:
            sock.bind(('127.0.0.1', 0))
            port = sock.getsockname()[1]
        def build_tag(tag, revision, command=None):
            lines = [f'FROM {image}', f'LABEL {release.LABEL}={name}',
                     f'LABEL org.opencontainers.image.revision={revision}',
                     f'ENV MUSE2API_BUILD_SHA={revision}']
            if command:
                lines.append('CMD ' + json.dumps(command))
            subprocess.run(['docker', 'build', '-t', tag, '-'], input='\n'.join(lines), text=True, check=True)
        def upload(tag, revision):
            archive = root / 'uploads' / f'{revision}.tar.gz'
            # Docker load accepts an uncompressed tar too.
            release.docker('save', '-o', str(archive), tag)
            return archive
        def request(path, token=None):
            headers = {'Authorization': 'Bearer ' + token} if token else {}
            with urllib.request.urlopen(urllib.request.Request(f'http://127.0.0.1:{port}{path}', headers=headers), timeout=10) as response:
                return json.load(response)
        try:
            build_tag(good, sha)
            archive = upload(good, sha)
            release.release(root, name, sha, archive, port, '')
            assert not archive.exists(), 'successful upload leaked'
            config = (root / 'config/.env').read_bytes()
            key = dict(line.split('=', 1) for line in config.decode().splitlines())['MUSE2API_KEY']
            assert request('/healthz')['status'] == 'ok'
            try:
                request('/v1/me')
                raise AssertionError('unauthenticated API access allowed')
            except urllib.error.HTTPError as error:
                assert error.code == 401
            principal = request('/v1/me', key)
            assert principal['role'] == 'admin'
            assert principal['capabilities']['generation'] is True
            narration = request('/v1/video-projects/narration-capability', key)
            assert narration['available'] is False and narration['timing'] == 'scene'
            # Exercise packaged adapter validation and actual FFmpeg mux without credentials/network.
            packaged_check = '''
import io, math, struct, wave, tempfile, subprocess
from pathlib import Path
from narration import validate_audio
from video_projects import render_mp4
out = io.BytesIO()
with wave.open(out, 'wb') as w:
    w.setparams((1,2,24000,0,'NONE','not compressed'))
    w.writeframes(b''.join(struct.pack('<h',int(8000*math.sin(i*2*math.pi*440/24000))) for i in range(12000)))
data = out.getvalue()
assert validate_audio(data, 1) == .5
with tempfile.TemporaryDirectory(dir='/app/data') as directory:
    root = Path(directory)
    (root/'speech.wav').write_bytes(data)
    subprocess.run(['ffmpeg','-v','error','-f','lavfi','-i','color=red:s=160x90:r=24','-t','1','-c:v','libx264','-threads','1',str(root/'clip.mp4')],check=True)
    class Store:
        def storage_usage(self, owner): return dict(bytes=0,files=0,limits=dict(bytes=100000000,files=100))
        def media_owner(self, mid): return 'fixture'
        def open_media(self, mid): return (root/mid).open('rb')
        def write_media(self, mid, data, owner): (root/mid).write_bytes(data)
    mid = render_mp4(Store(),'fixture',[dict(media_id='clip.mp4',audio_media_id='speech.wav',duration=1)],'16:9',root)
    assert (root/mid).stat().st_size > 1000
    # Packaged libass/fonts and real Vietnamese burn, not filter-list inference.
    from shorts_render import capability, render_short, preview_frame
    cap = capability()
    assert cap['available'] and cap['burn_captions'], cap
    snapshot = dict(start=0., end=1., crop_x=.7, burn_captions=True,
                    source=dict(scenes=[dict(scene_id='s', take_id='t', media_id='clip.mp4', duration=1,
                                           narration='Xin chào Việt Nam', audio=dict(media_id='speech.wav',duration=.5))]))
    assert preview_frame(Store(),'fixture',snapshot,root,0.)[:2] == bytes([255,216])
    short = render_short(Store(),'fixture',snapshot,root)
    assert (root/short).stat().st_size > 1000
'''
            subprocess.run(['docker', 'exec', name, 'python', '-c', packaged_check], check=True)
            assert request('/v1/video-projects', key) == {'projects': []}
            payload = json.dumps({'title': 'Image contract', 'idea': 'Synthetic sky', 'aspect_ratio': '16:9'}).encode()
            create = urllib.request.Request(f'http://127.0.0.1:{port}/v1/video-projects', data=payload,
                                            headers={'Authorization': 'Bearer ' + key, 'Content-Type': 'application/json'})
            with urllib.request.urlopen(create, timeout=10) as response:
                project = json.load(response)
            assert request('/v1/video-projects/' + project['id'], key)['title'] == 'Image contract'
            assert principal['capabilities']['video_projects'] is True
            # Real packaged FFmpeg -> HTTP upload -> durable job -> import.
            video = subprocess.check_output(['docker', 'exec', name, 'ffmpeg', '-v', 'error',
                '-f', 'lavfi', '-i', 'color=red:s=160x90:r=10:d=2', '-threads', '1',
                '-c:v', 'libx264', '-f', 'mp4', '-movflags', 'frag_keyframe+empty_moov', 'pipe:1'])
            boundary = 'synthetic-reference-boundary'
            body = (f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="demo.mp4"\r\n'
                    'Content-Type: video/mp4\r\n\r\n').encode() + video + f'\r\n--{boundary}--\r\n'.encode()
            upload_request = urllib.request.Request(f'http://127.0.0.1:{port}/v1/reference-videos', data=body,
                headers={'Authorization': 'Bearer '+key, 'Content-Type': 'multipart/form-data; boundary='+boundary})
            with urllib.request.urlopen(upload_request, timeout=10) as response:
                assert response.status == 202
                reference = json.load(response)
            import time
            for _ in range(100):
                reference = request('/v1/reference-videos/'+reference['id'], key)
                if reference['status'] not in ('queued', 'processing'):
                    break
                time.sleep(.1)
            assert reference['status'] == 'completed', reference
            assert len(reference['shots']) == 1
            thumbnail_request = urllib.request.Request(f"http://127.0.0.1:{port}"+reference['shots'][0]['thumbnail_path'],
                                                       headers={'Authorization': 'Bearer '+key})
            with urllib.request.urlopen(thumbnail_request, timeout=10) as response:
                assert response.read().startswith(b'\xff\xd8')
            import_payload = json.dumps(dict(request_id=str(uuid.uuid4()), shot_ids=[reference['shots'][0]['id']])).encode()
            def import_reference():
                req = urllib.request.Request(f"http://127.0.0.1:{port}/v1/reference-videos/{reference['id']}/import",
                    data=import_payload, headers={'Authorization': 'Bearer '+key, 'Content-Type': 'application/json'})
                with urllib.request.urlopen(req, timeout=10) as response:
                    return json.load(response)
            imported = import_reference()
            assert not imported['script_approved'] and not imported['scenes'][0]['approved']
            assert not imported['scenes'][0]['attempts']
            assert request('/readyz', key)['status'] == 'no_account'
            # Custom security modules must import from inside the actual image.
            # The serving app has already imported app/project routes above.
            # Do not import app in a second process: its exclusive runtime lock
            # deliberately rejects a second app instance sharing the same data.
            release.docker('exec', name, 'python', '-c', 'import video_projects,tenant,authority,protection,idempotency,operations,client_config')
            (root / 'data/synthetic-sentinel').write_text('persistent')
            archive = upload(good, sha)
            release.release(root, name, sha, archive, port, '')
            assert (root / 'data/synthetic-sentinel').read_text() == 'persistent'
            assert (root / 'config/.env').read_bytes() == config, 'keys changed across rollout'
            assert import_reference()['id'] == imported['id'], 'reference import duplicated after restart'
            assert request('/v1/reference-videos/'+reference['id'], key)['status'] == 'completed'
            build_tag(bad, bad_sha, ['python', '-c', 'raise SystemExit(1)'])
            archive = upload(bad, bad_sha)
            try:
                release.release(root, name, bad_sha, archive, port, '')
                raise AssertionError('broken candidate accepted')
            except RuntimeError as error:
                assert 'previous container restored' in str(error), str(error)
            assert not archive.exists(), 'failed upload leaked'
            assert release.healthy(port, sha, name), 'rollback not healthy at prior revision'
            assert json.loads((root / 'release.json').read_text())['sha'] == sha
            assert (root / 'config/.env').read_bytes() == config
            print('PASS: Docker startup, custom modules, auth, provenance, persistent state/keys, rollback and upload cleanup')
        finally:
            for target in (name, name + '-rollback'):
                release.docker('rm', '-f', target, check=False)
            for tag in (good, bad):
                release.docker('image', 'rm', tag, check=False)
            # Containers write root-owned data on non-root CI runners.
            subprocess.run(['docker', 'run', '--rm', '-v', f'{root}:/cleanup', '--entrypoint', 'sh', image, '-c', 'rm -rf /cleanup/* /cleanup/.[!.]*'], check=True, capture_output=True)


if __name__ == '__main__':
    main(*sys.argv[1:])
