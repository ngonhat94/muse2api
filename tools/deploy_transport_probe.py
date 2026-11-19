#!/usr/bin/env python3
"""Bounded isolated incoming transport diagnostic; never changes running services."""
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import shlex
import subprocess
import tempfile
import time


def commands(root, attempt):
    if (not re.fullmatch(r'/[a-zA-Z0-9_/-]+', root) or root == '/'
            or '..' in root or '//' in root or root.endswith('/')
            or not re.fullmatch(r'diagnostic-[a-f0-9]{32}', attempt)):
        raise ValueError('Invalid isolated diagnostic target')
    target = root + '/incoming/' + attempt + '/probe.bin'
    reader = ('import pathlib,hashlib,json; p=pathlib.Path(' + repr(target)
              + '); h=hashlib.sha256(); f=p.open("rb"); '
              + '[h.update(b) for b in iter(lambda:f.read(1048576),b"")]; '
              + 'print(json.dumps({"bytes":p.stat().st_size,"sha256":h.hexdigest()}))')
    return ["umask 077; mkdir '" + root + '/incoming/' + attempt + "'",
            "umask 077; set -C; cat > '" + target + "'",
            'python3 -c ' + shlex.quote(reader)]


def main():
    root = os.environ['VPS_DEPLOY_PATH']
    attempt = 'diagnostic-' + secrets.token_hex(16)
    remote = commands(root, attempt)
    # Exactly 1 GiB, near the previously exported image size; no compression.
    size = 1024 * 1024 * 1024
    with tempfile.TemporaryDirectory(dir=os.environ['RUNNER_TEMP']) as temp:
        p = Path(temp)
        (p / 'config').write_text('Host *\n User ' + os.environ['VPS_USER'] + '\n')
        (p / 'config').chmod(0o600)
        (p / 'known').write_text(os.environ['VPS_KNOWN_HOSTS'] + '\n')
        ssh = ['ssh', '-F', str(p / 'config'), '-p', os.environ['VPS_PORT'],
               '-o', 'BatchMode=yes', '-o', 'StrictHostKeyChecking=yes',
               '-o', 'UserKnownHostsFile=' + str(p / 'known'),
               '-o', 'GlobalKnownHostsFile=/dev/null', '-o', 'PubkeyAuthentication=no',
               '-o', 'PasswordAuthentication=no', '-o', 'KbdInteractiveAuthentication=no',
               '-o', 'ConnectTimeout=15', '-o', 'ServerAliveInterval=15',
               '-o', 'ServerAliveCountMax=3', '-o', 'LogLevel=ERROR', os.environ['VPS_HOST']]
        h = hashlib.sha256()
        block = bytes(range(256)) * 4096
        with (p / 'payload').open('wb') as f:
            for _ in range(size // len(block)):
                f.write(block)
                h.update(block)
        expected = {'bytes': size, 'sha256': h.hexdigest()}
        print(json.dumps({'attempt': attempt, 'expected': expected}), flush=True)
        for stage, cmd in zip(['allocate', 'upload', 'verify'], remote):
            started = time.monotonic()
            with (p / 'payload').open('rb') as f:
                r = subprocess.run(ssh + [cmd], stdin=f if stage == 'upload' else subprocess.DEVNULL,
                                   capture_output=True, timeout=600)
            categories = [x for x in ['Permission denied', 'No such file or directory',
                          'No space left on device', 'File too large', 'Illegal option',
                          'cannot overwrite existing file', 'Connection reset', 'Broken pipe']
                          if x in r.stderr.decode(errors='replace')]
            print(json.dumps({'stage': stage, 'exit': r.returncode,
                              'seconds': round(time.monotonic() - started, 2),
                              'stderr_bytes': len(r.stderr), 'categories': categories}), flush=True)
            if r.returncode:
                raise SystemExit(1)
            if stage == 'verify':
                actual = json.loads(r.stdout)
                if actual != expected:
                    raise SystemExit('Transport hash mismatch')
                print('Transport hash and byte count verified', flush=True)


if __name__ == '__main__':
    main()
