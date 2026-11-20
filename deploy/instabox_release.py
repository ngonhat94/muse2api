"""Transactional single-host Docker rollout. Run on the target via Instabox exec.

Only service-labelled containers/images and this invocation's upload are touched.
Runtime config, encrypted data and browser profiles survive image replacement.
"""
import argparse
import base64
import fcntl
import json
import os
from pathlib import Path
import re
import secrets
import subprocess
import time
import urllib.request

LABEL = 'io.muse2api.service'


def docker(*args, check=True):
    # Never emit inspect output: container environments can contain credentials.
    return subprocess.run(['docker', *args], capture_output=True, text=True, check=check)


def inspect(name):
    result = docker('inspect', name, check=False)
    return json.loads(result.stdout)[0] if result.returncode == 0 else None


def healthy(port, sha, name):
    try:
        with urllib.request.urlopen(f'http://127.0.0.1:{port}/healthz', timeout=3) as response:
            if json.load(response)['status'] != 'ok':
                return False
        info = inspect(name)
        return (bool(info) and info['State']['Running'] and
                f'MUSE2API_BUILD_SHA={sha}' in info['Config']['Env'] and
                info['Config']['Labels']['org.opencontainers.image.revision'] == sha)
    except (OSError, ValueError, KeyError, TypeError):
        return False


def release(root, name, sha, archive, port, public_url):
    if not re.fullmatch(r'[a-z0-9][a-z0-9-]{0,50}', name):
        raise ValueError('invalid service name')
    if not re.fullmatch(r'[0-9a-f]{40}', sha):
        raise ValueError('invalid revision')
    root = Path(root).resolve()
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    archive = Path(archive).resolve()
    # Cleanup must never be able to unlink arbitrary paths supplied by a caller.
    if archive.parent != root / 'uploads' or archive.name != f'{sha}.tar.gz':
        raise ValueError('upload must be scoped to revision in deployment uploads directory')
    with (root / '.deploy.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        try:
            _rollout(root, name, sha, archive, port, public_url)
        finally:
            archive.unlink(missing_ok=True)


def _rollout(root, name, sha, archive, port, public_url):
    image = f'muse2api-{name}:{sha}'
    backup = name + '-rollback'
    for target in (name, backup):
        info = inspect(target)
        if info and info['Config'].get('Labels', {}).get(LABEL) != name:
            raise ValueError('refusing to replace foreign container')
    docker('load', '-i', str(archive))
    image_info = json.loads(docker('image', 'inspect', image).stdout)[0]
    labels = image_info['Config'].get('Labels') or {}
    if labels.get(LABEL) != name or labels.get('org.opencontainers.image.revision') != sha:
        raise ValueError('image ownership/revision mismatch')
    for directory in ('data', 'profiles', 'config'):
        (root / directory).mkdir(mode=0o700, exist_ok=True)
    config = root / 'config' / '.env'
    if not config.exists():
        # Generated on host, no credential is passed as argv or written to logs.
        with config.open('x', opener=lambda p, f: os.open(p, f, 0o600)) as handle:
            handle.write('MUSE2API_KEY=' + secrets.token_urlsafe(48) + '\n')
            handle.write('MUSE2API_COOKIE_KEY=' + base64.urlsafe_b64encode(secrets.token_bytes(32)).decode() + '\n')
    if config.stat().st_mode & 0o077:
        raise ValueError('runtime config must be owner-only')
    # A stale rollback container is safe to remove only after ownership checks above.
    if inspect(backup):
        docker('rm', '-f', backup)
    old = inspect(name)
    old_sha = None
    if old:
        old_sha = old['Config']['Labels'].get('org.opencontainers.image.revision')
        docker('stop', '-t', '30', name)
        docker('rename', name, backup)
    try:
        docker('run', '-d', '--name', name, '--restart', 'unless-stopped',
               '--label', f'{LABEL}={name}', '--shm-size', '2g',
               '--log-opt', 'max-size=10m', '--log-opt', 'max-file=3',
               '-p', f'{port}:18610',
               '-v', f'{root}/data:/runtime/data',
               '-v', f'{root}/config:/runtime',
               '-v', f'{root}/profiles:/root/muse2api-profiles',
               '-e', 'MUSE2API_HOME=/runtime',
               '-e', 'MUSE2API_MANAGED_DEPLOYMENT=1',
               '-e', 'MUSE2API_REPOSITORY=ngonhat94/muse2api',
               '-e', 'MUSE2API_REPO_REF=master',
               '-e', f'MUSE2API_PUBLIC_BASE={public_url}',
               '-e', 'MUSE2API_LEDGER_INITIALIZE=1', image)
        for _ in range(45):
            if healthy(port, sha, name):
                break
            time.sleep(2)
        else:
            raise RuntimeError('candidate health/revision check failed')
    except BaseException:
        if inspect(name):
            docker('rm', '-f', name)
        if old:
            docker('rename', backup, name)
            docker('start', name)
            for _ in range(30):
                if healthy(port, old_sha, name):
                    break
                time.sleep(2)
            else:
                raise RuntimeError('rollback health check failed') from None
        raise RuntimeError('candidate failed; previous container restored' if old else 'candidate failed; no prior release') from None
    state = root / 'release.json'
    temporary = root / '.release.json.new'
    temporary.write_text(json.dumps({'sha': sha, 'image': image, 'previous_sha': old_sha}) + '\n')
    temporary.replace(state)
    # Retain current and rollback images only. Never globally prune Docker.
    retained = {inspect(target)['Image'] for target in (name, backup) if inspect(target)}
    ids = docker('image', 'ls', '--filter', f'label={LABEL}={name}', '-q').stdout.split()
    for image_id in set(ids):
        full_id = json.loads(docker('image', 'inspect', image_id).stdout)[0]['Id']
        if full_id not in retained:
            docker('image', 'rm', image_id, check=False)
    print(json.dumps({'status': 'healthy', 'sha': sha, 'previous_sha': old_sha}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    for option in ('root', 'name', 'sha', 'archive'):
        parser.add_argument('--' + option, required=True)
    parser.add_argument('--port', type=int, default=18610)
    parser.add_argument('--public-url', default='')
    args = parser.parse_args()
    try:
        release(args.root, args.name, args.sha, args.archive, args.port, args.public_url)
    except Exception as error:
        # Docker exceptions contain argv but not captured environment/secret output.
        print(f'release failed: {type(error).__name__}: {error}', file=__import__('sys').stderr)
        raise SystemExit(1)
