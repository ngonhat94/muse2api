#!/usr/bin/env python3
"""Prepare the bundled engine before starting Flutter on the host desktop.

Run from any directory: python3 tools/run_desktop.py
Uses an isolated build virtualenv, never changes saved server credentials.
"""
from __future__ import annotations
import argparse
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from build_desktop import engine_bundle_ready


def run(args, **kwargs):
    subprocess.run([str(a) for a in args], check=True, cwd=ROOT, **kwargs)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--flutter', default=shutil.which('flutter') or 'flutter')
    parser.add_argument('--rebuild-engine', action='store_true')
    parser.add_argument('--prepare-only', action='store_true')
    args = parser.parse_args(argv)
    target = {'Darwin': 'macos', 'Windows': 'windows', 'Linux': 'linux'}.get(platform.system())
    if target is None:
        parser.error('Desktop is supported on macOS, Windows and Linux only.')
    engine = ROOT / 'dist/desktop/muse_engine'
    executable = engine / ('muse_engine.exe' if os.name == 'nt' else 'muse_engine')
    try:
        if args.rebuild_engine or not engine_bundle_ready(engine):
            print('Preparing desktop engine and bundled Chromium...', flush=True)
            venv = ROOT / 'build/desktop/venv'
            python = venv / ('Scripts/python.exe' if os.name == 'nt' else 'bin/python')
            if not python.is_file():
                run([sys.executable, '-m', 'venv', venv])
            run([python, '-m', 'pip', 'install', '-r', ROOT / 'desktop/requirements-build.txt'])
            run([python, ROOT / 'tools/build_desktop.py', '--engine-only'])
        if not engine_bundle_ready(engine):
            raise RuntimeError('Desktop bundle is incomplete; no Flutter process was started.')
        if args.prepare_only:
            print(f'Engine ready: {executable}')
            return 0
        print('Engine ready. Starting Muse Studio...', flush=True)
        subprocess.run([args.flutter, 'run', '-d', target,
                        f'--dart-define=MUSE_ENGINE_PATH={executable}',
                        f'--dart-define=MUSE_SOURCE_ROOT={ROOT}'],
                       cwd=ROOT / 'muse_app', check=True)
        return 0
    except (subprocess.CalledProcessError, OSError, RuntimeError):
        print('Desktop preparation/start failed. Review the failed step above. '
              'Preparing the engine requires access to Python packages and the Chromium download; '
              'Flutter was not started with a missing engine.', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
