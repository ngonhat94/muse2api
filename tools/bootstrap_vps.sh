#!/usr/bin/env bash
# One-time, operator-authorized isolated replacement. No deploy/start/stop/remove.
set -euo pipefail
set +x
umask 077
export ROOT="${ROOT:-/data/home/muse2api-production}"
export IMAGE="${IMAGE:-muse2api:bootstrap}"
command -v python3 >/dev/null || { printf '%s\n' 'ERROR: install Python 3 first.' >&2; exit 1; }
command -v docker >/dev/null || { printf '%s\n' 'ERROR: install Docker and grant this deployment account access.' >&2; exit 1; }
python3 - <<'BOOTSTRAP_HOST_PY'
import os
from pathlib import Path
import re
import stat
import subprocess
import sys

os.umask(0o077)
root = Path(os.environ['ROOT'])
image = os.environ['IMAGE']
names = ('config', 'data', 'profiles', 'incoming')


def fail(message):
    raise ValueError(message)


def private_directory(path):
    info = path.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != 0o700:
        fail('Expected deployment-account-owned directory mode 700: ' + str(path))


def empty_state():
    for parent in (root, *root.parents):
        if parent.is_symlink():
            fail('Symlink path rejected: ' + str(parent))
    if root.exists():
        private_directory(root)
        if set(p.name for p in root.iterdir()) - set(names):
            fail('Existing/partial state in ROOT; no overwrite. Inspect privately; use a different isolated root or reconcile offline.')
        for name in names:
            item = root/name
            if item.exists() or item.is_symlink():
                private_directory(item)
                if any(item.iterdir()):
                    fail('Nonempty/partial state: ' + str(item) + '; no overwrite, reconcile offline.')


def docker(*args, source=None):
    result = subprocess.run(['docker', *args], input=source, text=True,
                            capture_output=True, timeout=120, check=False)
    if result.returncode:
        fail('Docker step failed (' + ' '.join(args[:2]) + '). Check Docker access, image/custom modules and isolated state privately; no approvals were issued. Never retry over partial state.')
    return result.stdout.strip()


# Compile custom modules without importing config/server/engine or running browsers.
probe = '''from pathlib import Path
from cryptography.fernet import Fernet
for name in ('config', 'authority', 'tenant', 'idempotency', 'protection', 'engine', 'app', 'operations'):
    path = Path('/app') / (name + '.py')
    compile(path.read_bytes(), str(path), 'exec')
from authority import AdminAuthority
from idempotency import GenerationLedger
assert callable(AdminAuthority) and callable(GenerationLedger)
Fernet(Fernet.generate_key())
'''
bootstrap = '''import os, secrets
from pathlib import Path
from cryptography.fernet import Fernet
from authority import AdminAuthority
from idempotency import GenerationLedger
os.umask(0o077)
base = Path('/bootstrap')
if any(base.joinpath('data').iterdir()) or base.joinpath('.env').exists():
    raise ValueError('State no longer empty; refuse initialization')
values = dict(MUSE2API_KEY=secrets.token_urlsafe(48),
              MUSE2API_COOKIE_KEY=Fernet.generate_key().decode('ascii'),
              MUSE2API_PUBLIC_BASE='https://muse.dntrip.xyz')
# Explicit mapping and chr(61): no interpolation/redaction-sensitive shell syntax.
with base.joinpath('.env').open('x', encoding='utf-8') as output:
    for key, value in values.items():
        output.write(key + chr(61) + value + '\\n')
    output.flush()
    os.fsync(output.fileno())
os.environ.pop('MUSE2API_COOKIE_KEY_FILE', None)
os.environ.update(values)
AdminAuthority(str(base/'data/admin-authority.json'), values['MUSE2API_KEY'])
GenerationLedger(str(base/'data/generation-ledger.json'), initialize=True)
'''

try:
    if not root.is_absolute() or not re.fullmatch(r'/[A-Za-z0-9_./-]+', str(root)) or '..' in root.parts or '.' in root.parts or root == Path('/'):
        fail('ROOT must be an absolute isolated path, without spaces or traversal; default /data/home/muse2api-production.')
    if not image or image.startswith('-') or any(c.isspace() for c in image):
        fail('IMAGE must name a reviewed custom local image, default muse2api:bootstrap.')
    # Recheck actual on-disk state; never trust an earlier paste/check.
    empty_state()
    # A fresh host has no legacy container. Existing installs still require an
    # exact-ID approval so deployment cannot stop an unrelated/replaced runtime.
    legacy = docker('ps', '-aq', '--no-trunc', '--filter', 'name=^/muse2api$')
    if legacy and not re.fullmatch(r'[0-9a-f]{64}', legacy):
        fail('Legacy muse2api lookup returned an invalid container ID; no approvals written.')
    immutable = docker('image', 'inspect', '--format', '{{.Id}}', image)
    if not re.fullmatch(r'sha256:[0-9a-f]{64}', immutable):
        fail('Reviewed image is missing or has an invalid immutable ID; build/load custom muse2api:bootstrap first.')
    docker('run', '--rm', '--network', 'none', '--read-only', '--cap-drop', 'ALL',
           '--security-opt', 'no-new-privileges', '--user', str(os.getuid())+':'+str(os.getgid()),
           '--entrypoint', 'python', immutable, '-c', probe)
    empty_state()
    root.mkdir(mode=0o700, exist_ok=True)
    for name in names:
        (root/name).mkdir(mode=0o700, exist_ok=True)
    empty_state()
    # Exclusive lock retained on failure: no production file cleanup, no unsafe retry.
    with (root/'BOOTSTRAP_IN_PROGRESS').open('x') as lock:
        lock.write('one-time isolated initialization; reconcile offline if interrupted\n')
    docker('run', '--rm', '-i', '--network', 'none', '--cap-drop', 'ALL',
           '--security-opt', 'no-new-privileges', '--user', str(os.getuid())+':'+str(os.getgid()),
           '--mount', 'type=bind,src='+str(root/'config')+',dst=/bootstrap',
           '--mount', 'type=bind,src='+str(root/'data')+',dst=/bootstrap/data',
           '--env', 'MUSE2API_HOME=/bootstrap', '--entrypoint', 'python', immutable, '-', source=bootstrap)
    for name in ('config/.env', 'data/admin-authority.json', 'data/admin-authority.json.initialized',
                 'data/generation-ledger.json', 'data/generation-ledger.json.initialized'):
        info = (root/name).lstat()
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077 or not info.st_size:
            fail('Bootstrap output missing/unsafe: '+name+'; reconcile privately; no approvals issued.')
    current_legacy = docker('ps', '-aq', '--no-trunc', '--filter', 'name=^/muse2api$')
    if current_legacy != legacy:
        fail('Legacy container changed during bootstrap; no approvals issued. Reconcile offline.')
    # Approvals are exclusive, only after all initialization and output checks succeed.
    approvals = [('DEPLOY_READY', 'muse2api-storage-v1')]
    if legacy:
        approvals.insert(0, ('LEGACY_CUTOVER_APPROVED', legacy))
    for name, value in approvals:
        with (root/name).open('x') as output:
            output.write(value+'\n')
            output.flush()
            os.fsync(output.fileno())
    print('BOOTSTRAP COMPLETE: isolated state and deployment approval prepared at '+str(root))
    if legacy:
        print('Old muse2api retained and untouched. No service started. Keep config/.env private; deploy/proxy verification remains separate.')
    else:
        print('Fresh host initialized. No service started. Keep config/.env private; deploy/proxy verification remains separate.')
except Exception as error:
    if isinstance(error, subprocess.TimeoutExpired):
        message = 'Docker timed out; inspect isolated state privately. No completion claimed; do not retry over partial state.'
    else:
        message = str(error)
    print('ERROR: '+message, file=sys.stderr)
    sys.exit(1)
BOOTSTRAP_HOST_PY
