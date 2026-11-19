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


UPLOAD_FILES = {'.retention-owner', '.lease', 'image.tar', 'compose.yml', 'deploy_remote.py'}
STALE_SECONDS = 24 * 60 * 60


def cleanup_upload(root, attempt, stale=False):
    """Only our marked, private flat upload directories; never recurse/follow links."""
    if not re.fullmatch('[a-f0-9]{40}-[a-f0-9]{32}', attempt):
        return False
    release = root / 'incoming' / attempt
    try:
        if any(p.is_symlink() for p in (root, *root.parents)):
            return False
        private(root / 'incoming', directory=True)
        private(release, directory=True)
        entries = list(release.iterdir())
        if {p.name for p in entries} - UPLOAD_FILES:
            return False
        for path in entries:
            private(path)
            if path.stat().st_nlink != 1:
                return False
        marker = release / '.retention-owner'
        if marker.read_text() != CONTRACT:
            return False
        with (release / '.lease').open('r+') as lease:
            try:
                fcntl.flock(lease, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                return False
            if stale and time.time() - os.fstat(lease.fileno()).st_mtime < STALE_SECONDS:
                return False
            for path in entries:
                path.unlink()
            release.rmdir()
        return True
    except (OSError, ValueError):
        return False


def prune_images(protected):
    """Explicit non-forced removal; preserve images referenced by ANY container."""
    candidates = run('docker', 'image', 'ls', '--all', '--quiet', '--no-trunc',
                     '--filter', 'label=org.muse2api.storage-contract=' + CONTRACT).splitlines()
    for image_id in sorted(set(candidates)):
        if image_id in protected or not re.fullmatch('sha256:[a-f0-9]{64}', image_id):
            continue
        image = json.loads(run('docker', 'image', 'inspect', image_id))[0]
        labels = image['Config'].get('Labels') or {}
        tags = image.get('RepoTags') or []
        if (labels.get('org.muse2api.storage-contract') != CONTRACT
                or not re.fullmatch('[a-f0-9]{40}', labels.get('org.opencontainers.image.revision', ''))
                or any(not tag.startswith('muse2api-ci:') for tag in tags)
                or image['Id'] != image_id):
            continue
        containers = run('docker', 'ps', '--all', '--quiet', '--no-trunc').splitlines()
        used = {json.loads(run('docker', 'inspect', container))[0]['Image'] for container in containers}
        if image_id not in used:
            try:
                # No --force: Docker is the final race guard for new containers.
                run('docker', 'image', 'rm', image_id, stage='image-retention')
            except DeploymentError:
                print('Image retention deferred; image may now be in use. Inspect privately.', flush=True)


def disk_preflight(root, archive_bytes):
    """Conservative tar + load headroom; containerd may live outside DockerRootDir."""
    docker_root = Path(run('docker', 'info', '--format', '{{.DockerRootDir}}'))
    targets = [root, docker_root, Path('/var/lib/containerd')]
    required = {}
    paths = {}
    margin = 512 * 1024 * 1024
    for path, amount in zip(targets, [archive_bytes + margin, 3 * archive_bytes + margin,
                                       3 * archive_bytes + margin]):
        if not path.exists():
            continue
        device = path.stat().st_dev
        required[device] = required.get(device, 0) + amount
        paths[device] = path
    for device, amount in required.items():
        free = os.statvfs(paths[device])
        available = free.f_bavail * free.f_frsize
        if available < amount:
            raise DeploymentError('disk-preflight: required ' + str(amount) + ' bytes; available '
                                  + str(available) + ' bytes; approved scoped initial cleanup required; no upload started')


def receive(root, revision, image_id, version, sizes, attempt):
    """One SSH session owns the upload lease from allocation through final cleanup."""
    if (not re.fullmatch('[a-f0-9]{40}', revision)
            or not re.fullmatch(revision + '-[a-f0-9]{32}', attempt)
            or len(sizes) != 3 or any(n < 0 for n in sizes)):
        raise ValueError('invalid upload session')
    prepare(root)
    fd = os.open(root / '.upload.lock', os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'r+') as lock:
        info = os.fstat(lock.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077 or info.st_nlink != 1:
            raise ValueError('unsafe upload lock')
        fcntl.flock(lock, fcntl.LOCK_EX)
        prepare(root)
        legacy_guard(root)
        for entry in (root / 'incoming').iterdir():
            cleanup_upload(root, entry.name, stale=True)
        disk_preflight(root, sizes[0])
        release = root / 'incoming' / attempt
        release.mkdir(mode=0o700)  # No reuse or clobber, even on retry.
        try:
            for name, content in (('.retention-owner', CONTRACT), ('.lease', '')):
                fd = os.open(release / name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
                with os.fdopen(fd, 'w') as stream:
                    stream.write(content)
            with (release / '.lease').open('r+') as lease:
                fcntl.flock(lease, fcntl.LOCK_EX)
                for name, size in zip(('image.tar', 'compose.yml', 'deploy_remote.py'), sizes):
                    fd = os.open(release / name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
                    with os.fdopen(fd, 'wb') as stream:
                        remaining = size
                        while remaining:
                            block = sys.stdin.buffer.read(min(1024 * 1024, remaining))
                            if not block:
                                raise ValueError('incomplete upload')
                            stream.write(block)
                            remaining -= len(block)
                deploy(root, revision, image_id, version, attempt)
        finally:
            if not cleanup_upload(root, attempt):
                print('Upload retention deferred; inspect owned upload privately.', flush=True)


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
        prune_images({image_id})
        print('Verified running image ' + image_id + ' revision ' + revision, flush=True)


if __name__ == '__main__':
    try:
        if len(sys.argv) == 8 and sys.argv[1] == '--receive':
            receive(Path(sys.argv[2]), sys.argv[3], sys.argv[4], sys.argv[5],
                    [int(n) for n in sys.argv[6].split(',')], sys.argv[7])
        elif len(sys.argv) in (5, 6):
            deploy(Path(sys.argv[1]), *sys.argv[2:])
        else:
            raise ValueError('invalid deployment arguments')
    except Exception as error:
        # Subprocess stderr may contain configuration; never print it to CI.
        message = str(error) if isinstance(error, DeploymentError) else type(error).__name__ + '; inspect VPS privately'
        print('Deployment failed: ' + message, file=sys.stderr)
        sys.exit(1)
