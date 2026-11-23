"""Local-only, bounded visual extraction. No semantic/model/provider integration."""
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import time

from fastapi import HTTPException

MAX_FILE = 64 * 1024**2
MAX_BODY = 65 * 1024**2
MIMES = {'video/mp4', 'video/webm', 'video/quicktime'}


def extraction_capability():
    if not shutil.which('ffmpeg') or not shutil.which('ffprobe'):
        raise HTTPException(503, 'Reference extraction requires ffmpeg and ffprobe on PATH')


def extract_video(source, directory, stage):
    extraction_capability()
    deadline = time.monotonic() + 240

    def run(args, output=False, budget=30):
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise ValueError('Extraction time limit')
        return subprocess.run(args, stdout=subprocess.PIPE if output else subprocess.DEVNULL,
                              stderr=subprocess.DEVNULL, timeout=min(budget, remaining), check=True).stdout

    stage('probe')
    info = json.loads(run(['ffprobe', '-v', 'error', '-protocol_whitelist', 'file',
                          '-format_whitelist', 'mov,matroska,webm', '-show_streams', '-show_format',
                          '-of', 'json', str(source)], True))
    streams = info.get('streams', [])
    video = next((s for s in streams if s.get('codec_type') == 'video'), None)
    duration = float(info.get('format', {}).get('duration', 0))
    if not video or not math.isfinite(duration) or not 0 < duration <= 120 or len(streams) > 16:
        raise ValueError('Unsupported video')
    w, h = video.get('width', 0), video.get('height', 0)
    num, den = video.get('avg_frame_rate', '0/1').split('/')
    if not 0 < w <= 4096 or not 0 < h <= 4096 or w*h > 8847360 or not 0 < float(num)/float(den) <= 120:
        raise ValueError('Unsupported video bounds')
    common = ['ffmpeg', '-hide_banner', '-loglevel', 'error', '-nostdin', '-threads', '4',
              '-filter_threads', '1', '-protocol_whitelist', 'file',
              '-format_whitelist', 'mov,matroska,webm', '-i', str(source), '-map', '0:v:0', '-an', '-sn', '-dn']
    stage('cuts')
    # Metadata is sent to stdout, not a shell or an unbounded log file. Only
    # selected frames produce lines, capped at 121 (overflow fails, never truncates).
    # Full-frame scene detection gets a larger budget than individual seeks.
    raw = run(common + ['-vf', "scale=320:320:force_original_aspect_ratio=decrease,select=gt(scene\\,0.30),metadata=print:file='pipe\\:1'",
                        '-t', '120', '-frames:v', '121', '-f', 'null', '-'], True, budget=120)
    points = [float(v) for v in re.findall(rb'pts_time:([0-9.]+)', raw)]
    boundaries = [0.0] + sorted(set(p for p in points if 0 < p < duration)) + [duration]
    if len(boundaries) - 1 > 120:
        raise ValueError('Too many shots')
    stage('thumbnails')
    shots = []
    for order, (start, end) in enumerate(zip(boundaries, boundaries[1:])):
        path = Path(directory)/f'{order}.jpg'
        # Output dimensions, frames and bytes bounded independently of input.
        run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-nostdin', '-threads', '4',
             '-filter_threads', '1', '-ss', str((start+end)/2), '-protocol_whitelist', 'file',
             '-format_whitelist', 'mov,matroska,webm', '-i', str(source), '-map', '0:v:0',
             '-an', '-sn', '-dn', '-vf', 'scale=480:480:force_original_aspect_ratio=decrease', '-frames:v', '1',
             '-threads', '1', '-q:v', '4', '-fs', str(1024**2), str(path)])
        if not 0 < path.stat().st_size <= 1024**2:
            raise ValueError('Invalid thumbnail size')
        shots.append(dict(order=order, start=start, end=end, duration=end-start, file=str(path)))
    return shots


class ReferenceService:
    """Shares the incumbent lock and atomic file: job/import/project transactions."""
    def __init__(self, projects, store, scratch):
        self.projects, self.store, self.scratch = projects, store, Path(scratch)
        self.threads = []
        # Runtime is single-process/locked by incumbent startup; remove only
        # our interrupted scratch directories, never follow substituted links.
        if self.scratch.is_symlink():
            raise ValueError('Unsafe reference scratch directory')
        if self.scratch.exists():
            for folder in self.scratch.glob('reference-*'):
                if folder.is_dir() and not folder.is_symlink():
                    shutil.rmtree(folder)
        with projects.lock:
            projects.data.setdefault('reference_jobs', {})
            projects.data.setdefault('reference_imports', {})
            dirty = False
            for job in projects.data['reference_jobs'].values():
                if job['status'] in ('queued', 'processing'):
                    job.update(status='unknown', stage='unknown',
                               error='Extraction interrupted; upload again explicitly.', updated_at=int(time.time()))
                    dirty = True
            if dirty:
                projects.save()

    @property
    def jobs(self):
        return self.projects.data['reference_jobs']

    def owned(self, owner, jid):
        job = self.jobs.get(jid)
        if not job or job['owner_id'] != owner:
            raise HTTPException(404, 'Reference video not found')
        return job

    @staticmethod
    def public(job):
        import copy
        return copy.deepcopy({k: v for k, v in job.items() if k not in ('owner_id', 'source', 'media')})

    def get(self, owner, jid):
        with self.projects.lock:
            return self.public(self.owned(owner, jid))

    def admit(self, owner):
        import uuid
        with self.projects.lock:
            active = [j for j in self.jobs.values() if j['status'] in ('queued', 'processing')]
            if len(active) >= 2 or any(j['owner_id'] == owner for j in active):
                raise HTTPException(429, 'Reference extraction capacity reached')
            if sum(j['owner_id'] == owner for j in self.jobs.values()) >= 20:
                raise HTTPException(429, 'Reference video job limit reached')
            now = int(time.time())
            job = dict(id=uuid.uuid4().hex, owner_id=owner, status='queued', stage='queued',
                       error=None, shots=[], created_at=now, updated_at=now, source=None, media={})
            self.jobs[job['id']] = job
            self.projects.save()
            return self.public(job)

    def update(self, owner, jid, **fields):
        with self.projects.lock:
            job = self.owned(owner, jid)
            job.update(fields, updated_at=int(time.time()))
            self.projects.save()

    def start(self, owner, jid, source, check=lambda: None, release=lambda: None):
        import threading
        self.update(owner, jid, source=source)

        def worker():
            import tempfile
            import uuid
            written = []
            try:
                check()
                self.scratch.mkdir(parents=True, exist_ok=True)
                with tempfile.TemporaryDirectory(prefix='reference-', dir=self.scratch) as folder:
                    local = Path(folder)/'input.video'
                    if self.store.media_owner(source) != owner:
                        raise ValueError('Source ownership')
                    with self.store.open_media(source) as src, local.open('xb') as dst:
                        size = os.fstat(src.fileno()).st_size
                        if not 0 < size <= MAX_FILE:
                            raise ValueError('Source bounds')
                        shutil.copyfileobj(src, dst, 1024*1024)
                    def stage(value):
                        check()
                        self.update(owner, jid, status='processing', stage=value)
                    shots = extract_video(local, folder, stage)
                    media = {}
                    for shot in shots:
                        check()
                        sid = uuid.uuid4().hex
                        name = uuid.uuid4().hex + '.jpg'
                        self.store.write_media(name, Path(shot.pop('file')).read_bytes(), owner)
                        written.append(name)
                        media[sid] = name
                        shot.update(id=sid, thumbnail_path=f'/v1/reference-videos/{jid}/shots/{sid}/thumbnail')
                    check()
                    self.update(owner, jid, status='completed', stage='completed', shots=shots, media=media)
            except Exception:
                for name in written:
                    self.store.delete_media(name, owner_id=owner)
                self.update(owner, jid, status='failed', stage='failed', shots=[], media={},
                            error='Local video extraction failed; check video format, bounds and storage.')
            finally:
                try:
                    self.store.delete_media(source, owner_id=owner)
                    self.update(owner, jid, source=None)
                finally:
                    release()
        thread = threading.Thread(target=worker, daemon=True, name='reference-extraction')
        self.threads.append(thread)
        thread.start()

    def thumbnail(self, owner, jid, sid):
        with self.projects.lock:
            job = self.owned(owner, jid)
            name = job.get('media', {}).get(sid)
            if job['status'] != 'completed' or not name or self.store.media_owner(name) != owner:
                raise HTTPException(404, 'Reference thumbnail not found')
            try:
                with self.store.open_media(name) as handle:
                    return handle.read(1024**2 + 1)
            except (OSError, ValueError):
                raise HTTPException(404, 'Reference thumbnail not found') from None

    def import_shots(self, owner, jid, request):
        import copy
        import uuid
        from video_projects import ProjectCreate, validated
        if not isinstance(request, dict) or set(request) - {'request_id', 'shot_ids', 'title'}:
            raise HTTPException(422, 'Invalid reference import payload')
        try:
            rid = str(uuid.UUID(request['request_id']))
            ids = request['shot_ids']
            if not isinstance(ids, list) or not 1 <= len(ids) <= 12 or any(not isinstance(s, str) for s in ids) or len(set(ids)) != len(ids):
                raise ValueError()
            title = request.get('title', 'Reference storyboard')
            fields = validated(ProjectCreate, dict(title=title, idea='Editable reference storyboard; no semantic analysis performed.'))
        except (KeyError, ValueError, TypeError, AttributeError):
            raise HTTPException(422, 'Invalid reference import payload') from None
        fingerprint = dict(job=jid, shot_ids=sorted(ids), title=title)
        key = owner + ':' + rid
        with self.projects.lock:
            job = self.owned(owner, jid)
            receipts = self.projects.data['reference_imports']
            previous = receipts.get(key)
            if previous:
                if previous['payload'] != fingerprint:
                    raise HTTPException(409, 'request_id already used for another action')
                return self.projects.get(owner, previous['project'])
            if key in self.projects.data['requests'] or key in self.projects.data.get('image_imports', {}) or key in self.projects.data.get('web_download_requests', {}):
                raise HTTPException(409, 'request_id already used for another action')
            if job['status'] != 'completed':
                raise HTTPException(409, 'Reference video is not completed')
            shots = [s for s in job['shots'] if s['id'] in ids]
            durations = [int(math.floor(s['duration'] + 0.5)) for s in shots]
            if len(shots) != len(ids) or any(not 1 <= s['duration'] <= 15 for s in shots) or sum(s['duration'] for s in shots) > 120 or sum(durations) > 120:
                raise HTTPException(422, 'Selected shots require 1-15 seconds each and <=120 seconds total')
            if sum(p['owner_id'] == owner for p in self.projects.data['projects'].values()) >= 100:
                raise HTTPException(429, 'Project limit reached')
            now = int(time.time())
            p = dict(fields, aspect_ratio='16:9', id=uuid.uuid4().hex, owner_id=owner, revision=1,
                     script='Editable placeholder script. Describe the selected shots before approving; no semantic analysis performed.',
                     script_approved=False, scenes=[], render=None, created_at=now, updated_at=now)
            for order, (shot, duration) in enumerate(zip(shots, durations)):
                prompt = (f"Editable placeholder for reference shot {shot['order'] + 1} "
                          f"({shot['start']:.3f}-{shot['end']:.3f} seconds). "
                          'No semantic analysis performed. Describe subject, setting, action and camera before approving.')
                p['scenes'].append(dict(id=uuid.uuid4().hex, order=order, narration='', prompt=prompt,
                                        duration=duration, approved=False, selected_attempt_id=None, attempts=[]))
                media = job.get('media', {}).get(shot['id'])
                if media:
                    p['scenes'][-1]['first_frame'] = {'id': media, 'approved': False}
                    p['first_frame_mode'] = 'review'
            before = copy.deepcopy(self.projects.data)
            try:
                self.projects.data['projects'][p['id']] = p
                receipts[key] = dict(payload=fingerprint, project=p['id'])
                self.projects.save()  # New project and UUID receipt in ONE atomic replace.
            except BaseException:
                self.projects.data = before
                raise
            return self.projects.public(p)
