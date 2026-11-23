"""Lease-bound desktop setup helper. stdout is a fixed JSON protocol only.

Builds in a temporary workspace, then atomically publishes a fresh runtime.
Never reads .env, saved accounts, cookies or API keys from the source checkout.
"""
from __future__ import annotations
import argparse
from contextlib import contextmanager
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import threading

ROOT = Path(__file__).resolve().parents[1]
SOURCES = (
    'app.py', 'engine.py', 'store.py', 'config.py', 'cdp.py', 'proxy.py', 'tenant.py', 'protection.py',
    'authority.py', 'idempotency.py', 'operations.py', 'client_config.py',
    'video_projects.py', 'first_frames.py', 'image_projects.py', 'reference_videos.py', 'thumbnails.py', 'generation_timing.py',
    'narration.py', 'shorts.py', 'shorts_render.py',
    'requirements.txt', 'desktop/launcher.py', 'desktop/requirements-build.txt',
    'tools/build_desktop.py',
)
_cancelled = threading.Event()
_child_lock = threading.Lock()
_child = None

class SetupError(Exception):
    def __init__(self, code):
        self.code = code


def protocol(event, **fields):
    print(json.dumps({'event': event, **fields}), flush=True)


def terminate_child(child):
    if child is None or child.poll() is not None:
        return
    try:
        if os.name == 'nt':
            subprocess.run(['taskkill', '/PID', str(child.pid), '/T', '/F'],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
        else:
            os.killpg(child.pid, signal.SIGKILL)
    except (OSError, subprocess.SubprocessError):
        pass


def watch_parent():
    try:
        while sys.stdin.read(1024):
            pass
    finally:
        _cancelled.set()
        with _child_lock:
            terminate_child(_child)


def run_step(command, stage, cwd=None, env=None):
    global _child
    if _cancelled.is_set():
        raise SetupError('cancelled')
    protocol('progress', stage=stage)
    # New process group lets Cancel/parent EOF stop pip/build descendants too.
    options = {'start_new_session': True} if os.name != 'nt' else {'creationflags': subprocess.CREATE_NEW_PROCESS_GROUP}
    with _child_lock:
        if _cancelled.is_set():
            raise SetupError('cancelled')
        _child = subprocess.Popen([str(a) for a in command], cwd=cwd, env=env,
                                  stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                                  stderr=subprocess.DEVNULL, **options)
        child = _child
    try:
        try:
            result = child.wait(timeout=1800)
        except subprocess.TimeoutExpired:
            terminate_child(child)
            raise SetupError('download_failed') from None
        if _cancelled.is_set():
            raise SetupError('cancelled')
        if result:
            raise SetupError('download_failed' if stage in ('dependencies', 'browser') else 'install_failed')
    finally:
        with _child_lock:
            if _child is child:
                _child = None


@contextmanager
def setup_lock(parent):
    with open(parent / 'install.lock', 'a+b') as handle:
        try:
            if os.name == 'nt':
                import msvcrt
                handle.write(b'0'); handle.flush(); handle.seek(0)
                msvcrt.locking(handle.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl
                fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            raise SetupError('install_busy') from None
        yield


def copy_sources(work):
    for name in SOURCES:
        source = ROOT / name
        if not source.is_file():
            raise SetupError('setup_missing')
        destination = work / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)


def publish_runtime(staged, destination):
    """Preserve previous runtime on any failed verification or rename."""
    previous = destination.with_name('previous')
    if previous.exists():
        shutil.rmtree(previous)
    if destination.exists():
        destination.rename(previous)
    try:
        staged.rename(destination)
    except OSError:
        if previous.exists() and not destination.exists():
            previous.rename(destination)
        raise
    if previous.exists():
        shutil.rmtree(previous, ignore_errors=True)


def install(destination):
    if sys.version_info < (3, 11):
        raise SetupError('python_missing')
    destination = destination.resolve()
    destination.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    if os.name != 'nt':
        os.chmod(destination.parent, 0o700)
        os.umask(0o077)
    with setup_lock(destination.parent), tempfile.TemporaryDirectory(prefix='setup-', dir=destination.parent) as temporary:
        work = Path(temporary)
        protocol('progress', stage='preparing')
        copy_sources(work)
        venv = work / 'venv'
        run_step([sys.executable, '-m', 'venv', venv], 'preparing')
        python = venv / ('Scripts/python.exe' if os.name == 'nt' else 'bin/python')
        run_step([python, '-m', 'pip', 'install', '--disable-pip-version-check',
                  '-r', work / 'desktop/requirements-build.txt'], 'dependencies', cwd=work)
        env = dict(os.environ, PLAYWRIGHT_BROWSERS_PATH=str(work / 'build/desktop/browsers'))
        run_step([python, '-m', 'playwright', 'install', 'chromium', '--no-shell'], 'browser', cwd=work, env=env)
        # Builder reuses the browser just downloaded in its private build cache.
        run_step([python, work / 'tools/build_desktop.py', '--engine-only'], 'packaging', cwd=work)
        staged = work / 'dist/desktop/muse_engine'
        run_step([python, '-c',
                  "import sys;sys.path.insert(0,'tools');from build_desktop import engine_bundle_ready;sys.exit(0 if engine_bundle_ready('dist/desktop/muse_engine') else 1)"],
                 'verifying', cwd=work)
        if _cancelled.is_set():
            raise SetupError('cancelled')
        publish_runtime(staged, destination)
        protocol('complete')


def main(argv=None):
    parser = argparse.ArgumentParser()
    parser.add_argument('--destination', required=True, type=Path)
    args = parser.parse_args(argv)
    if not args.destination.is_absolute():
        protocol('error', code='storage_denied'); return 1
    threading.Thread(target=watch_parent, daemon=True).start()
    try:
        install(args.destination)
        return 0
    except SetupError as error:
        protocol('error', code=error.code)
    except PermissionError:
        protocol('error', code='storage_denied')
    except Exception:
        protocol('error', code='install_failed')
    return 1

if __name__ == '__main__':
    raise SystemExit(main())
