#!/usr/bin/env python3
"""Fail-closed deployment on the VPS. Never bootstrap, migrate or restore data."""
import fcntl
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import time

CONTAINER = 'muse2api-production'
CONTRACT = 'muse2api-storage-v1'


class DeploymentError(RuntimeError):
    """Only fixed, non-sensitive stage diagnostics may cross the CI boundary."""


def run(*args, stage='docker-query', env=None):
    try:
        return subprocess.run(args, check=True, text=True, stdout=subprocess.PIPE,
                              stderr=subprocess.PIPE, timeout=180, env=env).stdout.strip()
    except (subprocess.SubprocessError, OSError) as error:
        reason = ('timed out after 180s' if isinstance(error, subprocess.TimeoutExpired)
                  else 'command failed' if isinstance(error, subprocess.CalledProcessError)
                  else 'command unavailable')
        hint = ('check Docker daemon, disk space and uploaded archive privately; runtime not replaced'
                if stage == 'image-load' else 'inspect Docker and deployment state privately')
        raise DeploymentError(stage + ': ' + reason + '; ' + hint) from None


def private(path, directory=False, runtime_data=False):
    info = path.lstat()
    owners = {os.getuid(), 0} if runtime_data else {os.getuid()}
    if (stat.S_ISLNK(info.st_mode) or info.st_uid not in owners or info.st_mode & 0o077
            or not (stat.S_ISDIR(info.st_mode) if directory else stat.S_ISREG(info.st_mode))):
        raise ValueError('target requires owner-only regular files/directories')


def prepare(root):
    if not root.is_absolute() or '..' in root.parts or not re.fullmatch(r'/[A-Za-z0-9_/-]+', str(root)) or str(root) == '/':
        raise ValueError('unsafe deploy path')
    for parent in (root, *root.parents):
        if parent.is_symlink():
            raise ValueError('symlink deploy path')
    for name in ('', 'data', 'profiles', 'incoming', 'config'):
        private(root / name, directory=True)
    for name in ('config/.env', 'DEPLOY_READY', 'data/generation-ledger.json',
                 'data/generation-ledger.json.initialized', 'data/admin-authority.json',
                 'data/admin-authority.json.initialized'):
        private(root / name, runtime_data=name.startswith('data/'))
    if (root / 'DEPLOY_READY').read_text().strip() != CONTRACT:
        raise ValueError('operator approval missing')
    settings = {}
    for line in (root / 'config/.env').read_text().splitlines():
        if line and not line.startswith('#'):
            key, value = line.split('=', 1)
            if key not in {'MUSE2API_KEY', 'MUSE2API_COOKIE_KEY', 'MUSE2API_PUBLIC_BASE'} or not value.strip():
                raise ValueError('config/.env contains unsupported or empty settings')
            if key in settings:
                raise ValueError('duplicate setting')
            settings[key] = value
    if set(settings) != {'MUSE2API_KEY', 'MUSE2API_COOKIE_KEY', 'MUSE2API_PUBLIC_BASE'}:
        raise ValueError('explicit runtime credentials required')


def legacy_guard(root):
    legacy = run('docker', 'ps', '-aq', '--no-trunc', '--filter', 'name=^/muse2api$')
    if legacy:
        marker = root / 'LEGACY_CUTOVER_APPROVED'
        if not marker.exists():
            raise ValueError('legacy install requires explicit cutover approval')
        private(marker)
        if not re.fullmatch('[0-9a-f]{64}', legacy) or marker.read_text().strip() != legacy:
            raise ValueError('legacy container approval does not match')
    return legacy


def deploy(root, revision, image_id, version, attempt=None):
    if not re.fullmatch('[0-9a-f]{40}', revision) or not re.fullmatch('sha256:[0-9a-f]{64}', image_id):
        raise ValueError('invalid immutable release identifier')
    if not re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', version):
        raise ValueError('invalid version')
    if attempt is not None and not re.fullmatch(revision + '-[a-f0-9]{32}', attempt):
        raise ValueError('invalid upload attempt for revision')
    prepare(root)
    # O_NOFOLLOW prevents an existing lock symlink from redirecting writes.
    fd = os.open(root / '.deploy.lock', os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'r+') as lock:
        info = os.fstat(lock.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077 or info.st_nlink != 1:
            raise ValueError('unsafe deployment lock')
        fcntl.flock(lock, fcntl.LOCK_EX)
        prepare(root)
        legacy = legacy_guard(root)
        if (root / '.git').exists() or (root / 'docker-compose.yml').exists():
            raise ValueError('legacy repository cannot be used as deploy root')
        release = root / 'incoming' / (attempt or revision)
        private(release, directory=True)
        compose = release / 'compose.yml'
        private(compose)
        private(release / 'image.tar')
        # Loading does not start an application. Verify exact content identity.
        run('docker', 'load', '--input', str(release / 'image.tar'), stage='image-load')
        new = json.loads(run('docker', 'image', 'inspect', image_id, stage='image-inspect'))[0]
        labels = new['Config'].get('Labels') or {}
        if new['Id'] != image_id or labels.get('org.opencontainers.image.revision') != revision or labels.get('org.muse2api.storage-contract') != CONTRACT:
            raise ValueError('image identity/contract mismatch')
        previous = None
        ids = run('docker', 'ps', '-aq', '--filter', 'name=^/' + CONTAINER + '$')
        if ids:
            old = json.loads(run('docker', 'inspect', CONTAINER))[0]
            if (old['Config'].get('Labels') or {}).get('com.docker.compose.project') != 'muse2api-production':
                raise ValueError('existing container is not managed by this deployment')
            previous = old['Image']
        env = dict(os.environ, MUSE2API_DEPLOY_IMAGE=image_id, MUSE2API_DEPLOY_ROOT=str(root),
                   MUSE2API_DEPLOY_UID=str(os.getuid()), MUSE2API_DEPLOY_GID=str(os.getgid()))
        command = ['docker', 'compose', '--project-name', 'muse2api-production', '--project-directory', str(root), '-f', str(compose)]

        def compose_run(*args):
            # Keep subprocess execution here for the synthetic compose boundary.
            try:
                subprocess.run(command + list(args), env=env, check=True, stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE, timeout=180)
            except (subprocess.SubprocessError, OSError) as error:
                reason = 'timed out after 180s' if isinstance(error, subprocess.TimeoutExpired) else 'command failed'
                raise DeploymentError('compose-' + args[0] + ': ' + reason + '; inspect runtime privately') from None

        def healthy(expected_id, expected_version=None):
            probe = ('import json,urllib.request; '
                     'assert json.load(urllib.request.urlopen("http://127.0.0.1:18610/healthz",timeout=3))["status"]=="ok"; '
                     + ('assert json.load(open("/app/version.json"))["version"]==' + repr(expected_version) if expected_version else ''))
            for _ in range(30):
                try:
                    state = json.loads(run('docker', 'inspect', CONTAINER))[0]
                    if state['Image'] == expected_id and state['State']['Running']:
                        run('docker', 'exec', CONTAINER, 'python', '-c', probe)
                        return True
                except (subprocess.SubprocessError, DeploymentError, ValueError, KeyError):
                    pass
                time.sleep(2)
            return False

        # Stop before recreate: no two workers may access the ledger/profiles.
        if legacy:
            # Preserve the legacy container and mounts, but prevent reboot from
            # starting a competing worker. Legacy rollback remains manual.
            run('docker', 'update', '--restart=no', legacy, stage='legacy-restart-policy')
            run('docker', 'stop', '--time', '60', legacy, stage='legacy-stop')
            legacy_state = json.loads(run('docker', 'inspect', legacy))[0]
            if legacy_state['State']['Running']:
                raise RuntimeError('legacy runtime still running')
        compose_run('stop', '--timeout', '60', 'muse2api')
        if ids:
            stopped = json.loads(run('docker', 'inspect', CONTAINER))[0]
            if stopped['State']['Running']:
                raise RuntimeError('managed runtime still running')
        try:
            compose_run('up', '--detach', '--no-build', '--pull', 'never', '--scale', 'muse2api=1', 'muse2api')
            if not healthy(image_id, version):
                raise RuntimeError('new image health/version verification failed')
        except Exception as failure:
            # Never restore a ledger snapshot: that could duplicate upstream work.
            compose_run('stop', '--timeout', '60', 'muse2api')
            policy = root / 'ROLLBACK_COMPATIBLE'
            compatible = False
            if previous and policy.exists():
                private(policy)
                old_labels = json.loads(run('docker', 'image', 'inspect', previous))[0]['Config'].get('Labels') or {}
                compatible = policy.read_text().strip() == CONTRACT and old_labels.get('org.muse2api.storage-contract') == CONTRACT
            if compatible:
                env['MUSE2API_DEPLOY_IMAGE'] = previous
                compose_run('up', '--detach', '--no-build', '--pull', 'never', '--scale', 'muse2api=1', 'muse2api')
                if not healthy(previous):
                    compose_run('stop', '--timeout', '60', 'muse2api')
                    raise RuntimeError('rollback unhealthy; operator recovery required') from None
                print('Previous image recovered; release FAILED. Data was not rolled back.', flush=True)
            detail = str(failure) if isinstance(failure, DeploymentError) else 'health/version verification failed'
            raise DeploymentError(detail + '; release FAILED; no data restored') from None
        print('Verified running image ' + image_id + ' revision ' + revision, flush=True)


if __name__ == '__main__':
    try:
        if len(sys.argv) not in (5, 6):
            raise ValueError('expected path, revision, image ID, version, optional attempt')
        deploy(Path(sys.argv[1]), *sys.argv[2:])
    except Exception as error:
        # Subprocess stderr may contain configuration; never print it to CI.
        message = str(error) if isinstance(error, DeploymentError) else type(error).__name__ + '; inspect VPS privately'
        print('Deployment failed: ' + message, file=sys.stderr)
        sys.exit(1)
