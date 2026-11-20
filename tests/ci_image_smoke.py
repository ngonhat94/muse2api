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
            assert request('/v1/video-projects', key) == {'projects': []}
            payload = json.dumps({'title': 'Image contract', 'idea': 'Synthetic sky', 'aspect_ratio': '16:9'}).encode()
            create = urllib.request.Request(f'http://127.0.0.1:{port}/v1/video-projects', data=payload,
                                            headers={'Authorization': 'Bearer ' + key, 'Content-Type': 'application/json'})
            with urllib.request.urlopen(create, timeout=10) as response:
                project = json.load(response)
            assert request('/v1/video-projects/' + project['id'], key)['title'] == 'Image contract'
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
