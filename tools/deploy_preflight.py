"""Read-only VPS preflight streamed through SSH before any release upload."""
import os
from pathlib import Path
import stat
import subprocess
import sys

root = Path(sys.argv[1])
try:
    legacy = subprocess.run(['docker', 'ps', '-aq', '--no-trunc', '--filter', 'name=^/muse2api$'],
                            check=True, capture_output=True, text=True, timeout=15)
    if legacy.stdout.strip():
        approval = root / 'LEGACY_CUTOVER_APPROVED'
        info = approval.lstat()
        if (not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077
                or approval.read_text().strip() != legacy.stdout.strip()):
            raise ValueError('legacy install requires explicit matching approval')
    if (root / '.git').exists() or (root / 'docker-compose.yml').exists():
        raise ValueError('legacy repository cannot be used as deploy root')
    if any(p.is_symlink() for p in (root, *root.parents)):
        raise ValueError()
    for name in ('', 'incoming', 'data', 'profiles', 'config', 'config/.env', 'DEPLOY_READY',
                 'data/generation-ledger.json', 'data/generation-ledger.json.initialized',
                 'data/admin-authority.json', 'data/admin-authority.json.initialized'):
        item = root / name
        info = item.lstat()
        directory = name in ('', 'incoming', 'data', 'profiles', 'config')
        owners = {os.getuid(), 0} if name.startswith('data/') else {os.getuid()}
        if (info.st_uid not in owners or info.st_mode & 0o077 or
                not (stat.S_ISDIR(info.st_mode) if directory else stat.S_ISREG(info.st_mode))):
            raise ValueError()
    if (root / 'DEPLOY_READY').read_text().strip() != 'muse2api-storage-v1':
        raise ValueError()
except Exception:
    print('VPS not prepared; follow docs/DEPLOYMENT.md. No deployment started.', file=sys.stderr)
    sys.exit(1)
