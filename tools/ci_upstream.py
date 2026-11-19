#!/usr/bin/env python3
"""Run upstream integrations with ephemeral secrets and no outbound sockets.

These fixtures need real engine parsing, local Git or FFmpeg, so they cannot use
run_backend_offline's deny-all subprocess/engine guard. Never starts the server.
"""
import os
from pathlib import Path
import runpy
import socket
import subprocess
import sys
import tempfile
from unittest.mock import patch
from cryptography.fernet import Fernet

ROOT = Path(__file__).resolve().parents[1]
CASES = ('test_session_cookie_rotation.py', 'test_version_reporting.py',
         'test_release_integration.py', 'test_media_thumbnails.py')


def main():
    if len(sys.argv) == 1:
        for name in CASES:
            subprocess.run([sys.executable, __file__, name], cwd=ROOT, check=True)
        return
    name = sys.argv[1]
    if name not in CASES:
        raise ValueError('Unclassified integration test')
    with tempfile.TemporaryDirectory(prefix='upstream-integration-') as home:
        os.environ.update(MUSE2API_HOME=home, MUSE2API_PROFILE_ROOT=home+'/profile',
                          MUSE2API_COOKIE_KEY=Fernet.generate_key().decode(),
                          MUSE2API_LEDGER_INITIALIZE='1', MUSE2API_KEY='synthetic-admin',
                          MUSE2API_AUTO_UPDATE='0')
        os.environ.pop('MUSE2API_COOKIE_KEY_FILE', None)
        def deny(*args, **kwargs):
            raise AssertionError('Outbound network forbidden in upstream integration')
        sys.path.insert(0, str(ROOT))
        sys.path.insert(0, str(ROOT/'tests'))
        sys.argv = [str(ROOT/'tests'/name)]
        with patch.object(socket.socket, 'connect', deny), patch.object(socket.socket, 'connect_ex', deny), patch.object(socket, 'getaddrinfo', deny):
            runpy.run_path(str(ROOT/'tests'/name), run_name='__main__')


if __name__ == '__main__':
    main()
