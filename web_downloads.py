"""Durable public-video downloads with owner isolation and explicit UUID replay."""
import copy
import importlib.util
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import threading
import time
from urllib.parse import urlsplit, urlunsplit
import uuid
from pot_broker import enabled as pot_enabled, JobBroker, serve_job

from fastapi import HTTPException
from pydantic import BaseModel, ConfigDict
from typing import Literal

from web_download_worker import MAX_BYTES, youtube_support, safe_diagnostic
from protection import StorageQuotaExceeded

SITES = {
    'youtube.com': 'YouTube', 'youtu.be': 'YouTube',
    'tiktok.com': 'TikTok', 'facebook.com': 'Facebook', 'fb.watch': 'Facebook',
    'instagram.com': 'Instagram', 'x.com': 'X', 'twitter.com': 'X', 'vimeo.com': 'Vimeo',
}
TERMINAL = {'completed', 'failed', 'cancelled', 'unknown'}


class DownloadCreate(BaseModel):
    model_config = ConfigDict(extra='forbid', strict=True)
    request_id: str
    url: str
    quality: Literal[480, 720, 1080] = 720


def normalize_url(value):
    if not isinstance(value, str) or len(value) > 2048 or any(c.isspace() for c in value):
        raise HTTPException(422, 'Invalid public video URL')
    try:
        parsed = urlsplit(value)
        host = (parsed.hostname or '').lower().rstrip('.')
        if parsed.scheme not in ('http', 'https') or parsed.username or parsed.password or parsed.port not in (None, 80, 443):
            raise ValueError()
        site = next((label for domain, label in SITES.items()
                     if host == domain or host.endswith('.'+domain)), None)
        if not site:
            raise ValueError()
    except ValueError:
        raise HTTPException(422, 'Use a supported public video URL without credentials') from None
    return urlunsplit(('https', host, parsed.path or '/', parsed.query, '')), site


def capability():
    ready = bool(not getattr(sys, 'frozen', False) and importlib.util.find_spec('yt_dlp') and shutil.which('ffmpeg') and shutil.which('ffprobe'))
    youtube = youtube_support()
    youtube['available'] = ready and youtube['available']
    youtube['anonymous_po_token'] = dict(configured=pot_enabled(), live_verified=False)
    return dict(available=ready, sites=list(dict.fromkeys(SITES.values())),
                qualities=[480, 720, 1080], max_bytes=MAX_BYTES, max_seconds=600,
                youtube=youtube)


def run_download(url, quality, root, observe, check, cancelled):
    request = root/'request.json'
    request.write_text(json.dumps(dict(url=url, quality=quality)))
    os.chmod(request, 0o600)
    env = {'PATH': os.environ.get('PATH', os.defpath), 'LANG': 'C.UTF-8', 'PYTHONUNBUFFERED': '1', 'PYTHONNOUSERSITE': '1'}
    ipc_parent = ipc_child = broker = broker_thread = None
    broker_stopped = threading.Event()
    def broker_check():
        check()
        if broker_stopped.is_set(): raise InterruptedError()
    if pot_enabled() and normalize_url(url)[1] == 'YouTube':
        import socket
        from yt_dlp.extractor.youtube import YoutubeIE
        video_id = YoutubeIE.extract_id(url)  # URL parsing only; no network.
        ipc_parent, ipc_child = socket.socketpair()
        env['MUSE_POT_FD'] = str(ipc_child.fileno())
        env['MUSE_POT_VIDEO_ID'] = video_id
        broker = JobBroker(video_id, broker_check, cancelled)
    try:
        process = subprocess.Popen(
            [sys.executable, str(Path(__file__).with_name('web_download_worker.py')), str(root)],
            env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            **({'pass_fds': (ipc_child.fileno(),)} if ipc_child else {}),
            start_new_session=os.name == 'posix')
    except BaseException:
        if ipc_parent: ipc_parent.close()
        if ipc_child: ipc_child.close()
        raise
    if ipc_child:
        ipc_child.close()
        broker_thread = threading.Thread(target=serve_job, args=(ipc_parent, broker), daemon=True)
        broker_thread.start()
    deadline = time.monotonic() + 480
    previous = None
    try:
        while True:
            check()
            if cancelled.is_set():
                raise InterruptedError()
            if time.monotonic() > deadline:
                raise TimeoutError()
            total = sum(p.stat().st_size for p in root.iterdir() if p.is_file())
            if total > 3 * MAX_BYTES:
                raise ValueError('Scratch size limit')
            progress = root/'progress.json'
            if progress.exists():
                data = progress.read_bytes()
                if len(data) > 4096:
                    raise ValueError('Invalid progress')
                if data != previous:
                    observe(json.loads(data))
                    previous = data
            if process.poll() is not None:
                break
            cancelled.wait(.4)
        progress = json.loads((root/'progress.json').read_text())
        if process.returncode or progress['stage'] != 'completed':
            return None, progress
        return root/'video.mp4', progress
    finally:
        broker_stopped.set()
        def stop(force=False):
            try:
                if os.name == 'posix' and process.pid > 1:
                    os.killpg(process.pid, signal.SIGKILL if force else signal.SIGTERM)
                elif process.poll() is None:
                    process.kill() if force else process.terminate()
            except ProcessLookupError:
                pass
        # Kill only the session created for this worker, including its solver.
        stop()
        if process.poll() is None:
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                stop(force=True)
                process.wait()
        if ipc_parent:
            try: ipc_parent.shutdown(2)
            except OSError: pass
            ipc_parent.close()
            broker_thread.join(timeout=23)
            broker.close()


class DownloadService:
    def __init__(self, projects, store, scratch, runner=run_download):
        self.projects, self.store = projects, store
        self.scratch, self.runner = Path(scratch), runner
        self.active = {}
        self.threads = []
        if self.scratch.exists():
            for folder in self.scratch.glob('web-video-*'):
                if folder.is_dir() and not folder.is_symlink():
                    shutil.rmtree(folder)
        with projects.lock:
            changed = False
            for job in projects.data.get('web_downloads', {}).values():
                if job['status'] not in TERMINAL:
                    job.update(status='unknown', stage='unknown', error_code='interrupted')
                    changed = True
            if changed:
                projects.save()

    def owned(self, owner, jid):
        job = self.projects.data.get('web_downloads', {}).get(jid)
        if not job or job['owner_id'] != owner:
            raise HTTPException(404, 'Download not found')
        return job

    @staticmethod
    def public(job):
        return {k: copy.deepcopy(v) for k, v in job.items() if k != 'owner_id'}

    def get(self, owner, jid):
        with self.projects.lock:
            return self.public(self.owned(owner, jid))

    def list(self, owner):
        with self.projects.lock:
            return {'downloads': [self.public(j) for j in self.projects.data.get('web_downloads', {}).values()
                                  if j['owner_id'] == owner]}

    def create(self, owner, fields, authority, preflight):
        url, site = normalize_url(fields['url'])
        try:
            rid = str(uuid.UUID(fields['request_id']))
        except (ValueError, TypeError, AttributeError):
            raise HTTPException(422, 'request_id must be a UUID') from None
        key = owner + ':' + rid
        payload = dict(url=url, quality=fields['quality'])
        with self.projects.lock:
            previous = self.projects.data.get('web_download_requests', {}).get(key)
            if previous:
                if previous['payload'] != payload:
                    raise HTTPException(409, 'request_id already used with another payload')
                return self.get(owner, previous['job']), False
            if any(key in self.projects.data.get(table, {}) for table in ('requests', 'reference_imports', 'image_imports')):
                raise HTTPException(409, 'request_id already used for another action')
            jobs = self.projects.data.get('web_downloads', {})
            owned = [j for j in jobs.values() if j['owner_id'] == owner]
            if len(self.active) >= 2 or any(j['status'] not in TERMINAL for j in owned):
                raise HTTPException(429, 'Download history or concurrency limit reached')
            if not capability()['available']:
                raise HTTPException(503, 'Video download tools unavailable')
            preflight()
            authority.check()
            now = int(time.time())
            jid = uuid.uuid4().hex
            job = dict(payload, id=jid, owner_id=owner, site=site, request_id=rid,
                       status='queued', stage='queued', error_code=None, title='',
                       downloaded=0, total=None, media_id=None, diagnostic=None,
                       created_at=now, updated_at=now)
            before = copy.deepcopy(self.projects.data)
            try:
                for old in sorted(owned, key=lambda j: j['created_at'])[:max(0, len(owned) - 19)]:
                    del self.projects.data['web_downloads'][old['id']]
                self.projects.data.setdefault('web_downloads', {})[jid] = job
                self.projects.data.setdefault('web_download_requests', {})[key] = dict(payload=payload, job=jid)
                self.projects.save()
            except BaseException:
                self.projects.data = before
                raise
            cancelled = threading.Event()
            self.active[jid] = cancelled
            authority.worker_owned = True

            def update(values):
                allowed = {'stage', 'downloaded', 'total', 'title', 'duration', 'height', 'width', 'size'}
                with self.projects.lock:
                    current = self.owned(owner, jid)
                    if current['status'] in TERMINAL:
                        return
                    current.update({k: v for k, v in values.items() if k in allowed})
                    current.update(status='processing', updated_at=int(time.time()))
                    self.projects.save()

            def worker():
                media = None
                try:
                    self.scratch.mkdir(parents=True, exist_ok=True)
                    with tempfile.TemporaryDirectory(prefix='web-video-', dir=self.scratch) as folder:
                        output, result = self.runner(url, fields['quality'], Path(folder), update, authority.check, cancelled)
                        authority.check()
                        if cancelled.is_set():
                            raise InterruptedError()
                        if output is None:
                            with self.projects.lock:
                                current = self.owned(owner, jid)
                                diagnostic = result.get('diagnostic') or {}
                                diagnostic = diagnostic if isinstance(diagnostic, dict) else {}
                                code = result.get('error_code')
                                code = code if isinstance(code, str) and code in {'bounds', 'protected', 'authentication_required', 'unsupported', 'unavailable'} else 'unavailable'
                                current.update(status='failed', stage='failed', error_code=code,
                                               diagnostic=safe_diagnostic(diagnostic.get('reason'), diagnostic.get('flags')),
                                               updated_at=int(time.time()))
                                self.projects.save()
                            return
                        if not output.is_file() or not 0 < output.stat().st_size <= MAX_BYTES:
                            raise ValueError('Invalid download file')
                        media = 'web_' + uuid.uuid4().hex + '.mp4'
                        self.store.write_media(media, output.read_bytes(), owner)
                        authority.check()
                        with self.projects.lock:
                            if cancelled.is_set():
                                raise InterruptedError()
                            current = self.owned(owner, jid)
                            current.update(status='completed', stage='completed', media_id=media,
                                       downloaded=output.stat().st_size, total=output.stat().st_size,
                                       title=result.get('title', '')[:200], duration=result.get('duration'),
                                       height=result.get('height'), width=result.get('width'), updated_at=int(time.time()))
                            self.projects.save()
                            media = None
                except Exception as exc:
                    if media:
                        self.store.delete_media(media, owner_id=owner)
                    with self.projects.lock:
                        code = ('cancelled' if isinstance(exc, InterruptedError) else
                                'timeout' if isinstance(exc, TimeoutError) else
                                'quota' if isinstance(exc, StorageQuotaExceeded) else 'failed')
                        current = self.owned(owner, jid)
                        current.update(status='cancelled' if code == 'cancelled' else 'failed',
                                       stage='failed', error_code=code, media_id=None, updated_at=int(time.time()))
                        self.projects.save()
                finally:
                    with self.projects.lock:
                        self.active.pop(jid, None)
                    authority.release()

            thread = threading.Thread(target=worker, daemon=True, name='public-video-download')
            self.threads = [t for t in self.threads if t.is_alive()]
            self.threads.append(thread)
            try:
                thread.start()
            except BaseException:
                self.active.pop(jid, None)
                job.update(status='unknown', stage='unknown', error_code='interrupted')
                self.projects.save()
                authority.worker_owned = False
                raise
            return self.public(job), True

    def cancel(self, owner, jid):
        with self.projects.lock:
            job = self.owned(owner, jid)
            if jid in self.active:
                self.active[jid].set()
            return self.public(job)

    def receipt(self, owner, rid):
        try:
            key = owner + ':' + str(uuid.UUID(rid))
        except ValueError:
            raise HTTPException(422, 'Invalid request UUID') from None
        with self.projects.lock:
            receipt = self.projects.data.get('web_download_requests', {}).get(key)
            if not receipt:
                raise HTTPException(404, 'Download receipt not found')
            return self.get(owner, receipt['job'])
