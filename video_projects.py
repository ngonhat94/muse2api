"""Durable owner-bound editorial state. Never persists credentials or signed URLs."""
import copy
import json
import os
import threading
import time
import uuid
import shutil
import subprocess
import tempfile
import math
from pathlib import Path
from fastapi import HTTPException
from pydantic import BaseModel, ConfigDict, Field
from typing import Literal


class SceneEdit(BaseModel):
    model_config = ConfigDict(extra='forbid', strict=True)
    id: str | None = None
    order: int = Field(ge=0, le=11)
    narration: str = Field(max_length=4000)
    prompt: str = Field(min_length=1, max_length=8000)
    duration: int = Field(ge=1, le=15)
    approved: bool = False
    selected_attempt_id: str | None = None


class ProjectCreate(BaseModel):
    model_config = ConfigDict(extra='forbid', strict=True)
    title: str = Field(min_length=1, max_length=200)
    idea: str = Field(min_length=1, max_length=12000)
    aspect_ratio: Literal['16:9', '9:16'] = '16:9'


class ProjectPatch(BaseModel):
    model_config = ConfigDict(extra='forbid', strict=True)
    revision: int = Field(ge=1)
    title: str | None = Field(default=None, min_length=1, max_length=200)
    idea: str | None = Field(default=None, min_length=1, max_length=12000)
    aspect_ratio: Literal['16:9', '9:16'] | None = None
    script: str | None = Field(default=None, max_length=24000)
    script_approved: bool | None = None
    scenes: list[SceneEdit] | None = Field(default=None, max_length=12)


class Revision(BaseModel):
    model_config = ConfigDict(extra='forbid', strict=True)
    revision: int = Field(ge=1)


class Submission(Revision):
    request_id: str


def validated(model, data):
    try:
        return model.model_validate(data).model_dump(exclude_none=True)
    except ValueError:
        raise HTTPException(422, 'Invalid video project payload') from None


def render_capability():
    if not shutil.which('ffmpeg') or not shutil.which('ffprobe'):
        raise HTTPException(503, 'Rendering unavailable: ffmpeg and ffprobe are required on server PATH')


def render_mp4(store, owner, clips, aspect, scratch):
    """Only owner-opened regular media; isolated local copies; no remote protocols."""
    render_capability()
    if aspect not in ('16:9', '9:16') or not 1 <= len(clips) <= 12:
        raise ValueError('Invalid render bounds')
    if any(type(c['duration']) is not int or not 1 <= c['duration'] <= 15 for c in clips) or sum(c['duration'] for c in clips) > 120:
        raise ValueError('Invalid render duration')
    usage = store.storage_usage(owner)
    from protection import StorageQuotaExceeded
    if usage['bytes'] >= usage['limits']['bytes'] or usage['files'] >= usage['limits']['files']:
        raise StorageQuotaExceeded('Storage quota exceeded')
    Path(scratch).mkdir(parents=True, exist_ok=True)
    width, height = (1280, 720) if aspect == '16:9' else (720, 1280)
    deadline = time.monotonic() + 300
    def run(args, probe=False):
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise ValueError('Render time limit exceeded')
        result = subprocess.run(args, stdout=subprocess.PIPE if probe else subprocess.DEVNULL,
                                stderr=subprocess.DEVNULL, timeout=min(remaining, 30 if probe else 90), check=True)
        return result.stdout
    with tempfile.TemporaryDirectory(prefix='project-render-', dir=scratch) as folder:
        root = Path(folder)
        total_bytes = 0
        for i, clip in enumerate(clips):
            mid = clip['media_id']
            if store.media_owner(mid) != owner:
                raise ValueError('Media is not owned by this tenant')
            source = root / f'input{i}.mp4'
            with store.open_media(mid) as src, source.open('xb') as dst:
                size = os.fstat(src.fileno()).st_size
                total_bytes += size
                if size > 256 * 1024**2 or total_bytes > 512 * 1024**2:
                    raise ValueError('Render input size limit exceeded')
                shutil.copyfileobj(src, dst, 1024 * 1024)
            info = json.loads(run(['ffprobe', '-v', 'error', '-protocol_whitelist', 'file', '-show_streams', '-show_format', '-of', 'json', str(source)], True))
            streams = info.get('streams', [])
            video = next((s for s in streams if s.get('codec_type') == 'video'), None)
            duration = float(info.get('format', {}).get('duration', 0))
            if not video or not math.isfinite(duration) or not 0 < duration <= 300 or not 0 < video.get('width', 0) <= 4096 or not 0 < video.get('height', 0) <= 4096:
                raise ValueError('Unsupported video dimensions or duration')
            # Probe source frame rate explicitly, then normalize all inputs to 24fps.
            num, den = video.get('avg_frame_rate', '0/1').split('/')
            if not 0 < float(num) / float(den) <= 240:
                raise ValueError('Unsupported source frame rate')
            audio = any(s.get('codec_type') == 'audio' for s in streams)
            cmd = ['ffmpeg', '-hide_banner', '-loglevel', 'error', '-nostdin', '-threads', '1', '-filter_threads', '1', '-protocol_whitelist', 'file', '-i', str(source)]
            if not audio:
                cmd += ['-f', 'lavfi', '-i', 'anullsrc=r=48000:cl=stereo']
            cmd += ['-map', '0:v:0', '-map', '0:a:0' if audio else '1:a:0',
                    '-vf', f'scale={width}:{height}:force_original_aspect_ratio=decrease,pad={width}:{height}:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=24,tpad=stop_mode=clone:stop_duration=15',
                    '-af', 'aresample=48000,apad', '-t', str(clip['duration']), '-c:v', 'libx264', '-threads', '1', '-preset', 'veryfast', '-crf', '23', '-pix_fmt', 'yuv420p',
                    '-c:a', 'aac', '-ac', '2', '-ar', '48000', '-b:a', '128k', '-map_metadata', '-1', '-fs', str(64*1024**2), str(root/f'part{i}.mp4')]
            run(cmd)
        listing = root / 'cuts.txt'
        listing.write_text(''.join(f"file 'part{i}.mp4'\n" for i in range(len(clips))))
        output = root / 'final.mp4'
        run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-nostdin', '-protocol_whitelist', 'file', '-f', 'concat', '-safe', '1', '-i', str(listing), '-c', 'copy', '-movflags', '+faststart', '-fs', str(256*1024**2), str(output)])
        final = json.loads(run(['ffprobe', '-v', 'error', '-show_format', '-of', 'json', str(output)], True))
        if abs(float(final['format']['duration']) - sum(c['duration'] for c in clips)) > 0.3:
            raise ValueError('Rendered duration failed validation')
        name = 'project_' + uuid.uuid4().hex + '.mp4'
        store.write_media(name, output.read_bytes(), owner)
        return name


class ProjectService:
    def __init__(self, path):
        self.path = Path(path)
        self.lock = threading.RLock()
        self.active = set()
        self.threads = []
        self.data = json.loads(self.path.read_text()) if self.path.exists() else {'projects': {}, 'requests': {}}

    def save(self):
        self.path.parent.mkdir(parents=True, exist_ok=True)
        tmp = self.path.with_suffix('.tmp')
        with open(tmp, 'w') as f:
            os.chmod(tmp, 0o600)
            json.dump(self.data, f, ensure_ascii=False)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, self.path)
        fd = os.open(self.path.parent, os.O_RDONLY)
        try:
            os.fsync(fd)
        finally:
            os.close(fd)

    def owned(self, owner, pid):
        p = self.data['projects'].get(pid)
        if not p or p['owner_id'] != owner:
            raise HTTPException(404, 'Project not found')
        return p

    @staticmethod
    def public(p):
        return copy.deepcopy({k: v for k, v in p.items() if k != 'owner_id'})

    def get(self, owner, pid):
        with self.lock:
            return self.public(self.owned(owner, pid))

    def list(self, owner):
        with self.lock:
            return {'projects': [self.public(p) for p in self.data['projects'].values() if p['owner_id'] == owner]}

    def create(self, owner, data):
        fields = validated(ProjectCreate, data)
        with self.lock:
            if sum(p['owner_id'] == owner for p in self.data['projects'].values()) >= 100:
                raise HTTPException(429, 'Project limit reached')
            now = int(time.time())
            p = dict(fields, id=uuid.uuid4().hex, owner_id=owner, revision=1, script='',
                     script_approved=False, scenes=[], render=None, created_at=now, updated_at=now)
            self.data['projects'][p['id']] = p
            self.save()
            return self.public(p)

    @staticmethod
    def revision(p, revision):
        if p['revision'] != revision:
            raise HTTPException(409, 'Stale project revision; refresh before editing')

    def changed(self, p):
        p['revision'] += 1
        p['updated_at'] = int(time.time())
        self.save()

    def receipt(self, owner, pid, action, request):
        fields = validated(Submission, request)
        try:
            uuid.UUID(fields['request_id'])
        except (ValueError, AttributeError):
            raise HTTPException(422, 'request_id must be a UUID') from None
        key = owner + ':' + str(uuid.UUID(fields['request_id']))
        previous = self.data['requests'].get(key)
        if previous:
            if previous['project'] != pid or previous['action'] != action:
                raise HTTPException(409, 'request_id already used for another action')
            return key, True
        return key, False

    async def generate(self, owner, pid, sid, request, submit, preflight=lambda: None):
        with self.lock:
            p = self.owned(owner, pid)
            key, replay = self.receipt(owner, pid, 'generate:' + sid, request)
            if replay:
                return self.public(p)
            self.revision(p, request['revision'])
            scene = next((s for s in p['scenes'] if s['id'] == sid), None)
            if not scene:
                raise HTTPException(404, 'Scene not found')
            if not p['script'].strip() or not p['script_approved'] or not scene['approved']:
                raise HTTPException(409, 'Approve the script and scene before generating')
            if len(scene['attempts']) >= 50:
                raise HTTPException(429, 'Scene attempt limit reached')
            preflight()
            aid = uuid.uuid4().hex
            attempt = dict(id=aid, task_id=aid, status='queued', media_id=None, url=None, error=None)
            scene['attempts'].append(attempt)
            self.data['requests'][key] = {'project': pid, 'action': 'generate:' + sid, 'id': aid}
            self.changed(p)  # WAL: save authorization before any upstream submission.
            snapshot = dict(copy.deepcopy(scene), aspect_ratio=p['aspect_ratio'])
        try:
            await submit(aid, snapshot)
        except BaseException:
            with self.lock:
                current = self.owned(owner, pid)
                current_scene = next((s for s in current['scenes'] if s['id'] == sid), None)
                current_attempt = next((a for a in current_scene['attempts'] if a['id'] == aid), None) if current_scene else None
                if current_attempt:
                    current_attempt.update(status='unknown', error='Submission outcome uncertain; refresh or explicitly authorize a new request.')
                    self.changed(current)
        return self.get(owner, pid)

    def reconcile(self, owner, pid, observe, owns):
        with self.lock:
            p = self.owned(owner, pid)
            dirty = False
            for scene in p['scenes']:
                for attempt in scene['attempts']:
                    if attempt['status'] not in ('queued', 'processing', 'unknown'):
                        continue
                    state = observe(attempt['task_id']) or {'status': 'unknown'}
                    status = state.get('status', 'unknown')
                    if status not in ('queued', 'processing', 'completed', 'failed', 'unknown'):
                        status = 'unknown'
                    media = state.get('media_id')
                    if status == 'completed' and (not media or not owns(media)):
                        status, media = 'failed', None
                    error = ('Generation failed; inspect account health or authorize a new take.' if status == 'failed' else
                             'Worker outcome unknown; no automatic resubmission.' if status == 'unknown' else None)
                    updates = dict(status=status, media_id=media if status == 'completed' else None, error=error)
                    if any(attempt[k] != v for k, v in updates.items()):
                        attempt.update(updates)
                        dirty = True
                    if status == 'completed' and scene['selected_attempt_id'] is None:
                        scene['selected_attempt_id'] = attempt['id']
                        if p['render']:
                            p['render']['outdated'] = True
                        dirty = True
            r = p['render']
            if r and r['status'] in ('queued', 'processing') and r['id'] not in self.active:
                r.update(status='unknown', error='Render interrupted; explicitly authorize a new render.')
                dirty = True
            if dirty:
                self.changed(p)
            return self.public(p)

    async def plan(self, owner, pid, request, planner):
        fields = validated(Revision, request)
        with self.lock:
            p = self.owned(owner, pid)
            self.revision(p, fields['revision'])
            snapshot = self.public(p)
        try:
            text = await planner(snapshot)
            if not isinstance(text, str) or len(text) > 64000:
                raise ValueError('Invalid planner response')
            draft = json.loads(text)
            if set(draft) != {'script', 'scenes'} or not draft['script'].strip() or not draft['scenes']:
                raise ValueError('Invalid draft')
            fields = validated(ProjectPatch, dict(draft, revision=request['revision']))
            # No upstream may approve, select, or name server-owned scenes.
            for scene in fields['scenes']:
                if scene.get('id') or scene.get('selected_attempt_id') or scene.get('approved'):
                    raise ValueError('Planner must return an unapproved draft')
        except Exception:
            raise HTTPException(502, 'Planning unavailable or invalid draft. Your project is unchanged; edit script and scenes manually.') from None
        return self.patch(owner, pid, fields)

    def render_media(self, owner, pid):
        with self.lock:
            p = self.owned(owner, pid)
            r = p['render']
            return self.data.get('render_media', {}).get(r['id']) if r and r['status'] == 'completed' else None

    def render(self, owner, pid, request, renderer, owns, preflight=lambda: None):
        with self.lock:
            p = self.owned(owner, pid)
            key, replay = self.receipt(owner, pid, 'render', request)
            if replay:
                return self.public(p)
            self.revision(p, request['revision'])
            if not p['script'].strip() or not p['script_approved'] or not p['scenes']:
                raise HTTPException(409, 'Approve script and all selected scenes before rendering')
            clips = []
            for scene in sorted(p['scenes'], key=lambda s: s['order']):
                take = next((a for a in scene['attempts'] if a['id'] == scene['selected_attempt_id']), None)
                if not scene['approved'] or not take or take['status'] != 'completed' or not take['media_id'] or not owns(take['media_id']):
                    raise HTTPException(409, 'Every scene needs an approved completed owned selected take')
                clips.append({'media_id': take['media_id'], 'duration': scene['duration']})
            if len(self.active) >= 2 or any(self.data['projects'][x]['owner_id'] == owner and self.data['projects'][x]['render'] and self.data['projects'][x]['render']['id'] in self.active for x in self.data['projects']):
                raise HTTPException(429, 'Render capacity reached; wait for the active render')
            preflight()
            rid = uuid.uuid4().hex
            p['render'] = dict(id=rid, status='queued', url=None, error=None, outdated=False)
            self.data['requests'][key] = {'project': pid, 'action': 'render', 'id': rid}
            self.active.add(rid)
            self.changed(p)
            aspect = p['aspect_ratio']
        def worker():
            try:
                with self.lock:
                    current = self.owned(owner, pid)
                    current['render']['status'] = 'processing'
                    self.changed(current)
                mid = renderer(clips, aspect)
                if not owns(mid):
                    raise ValueError('Output ownership invalid')
                with self.lock:
                    self.data.setdefault('render_media', {})[rid] = mid
                    current = self.owned(owner, pid)
                    current['render'].update(status='completed', error=None)
                    self.changed(current)
            except Exception:
                with self.lock:
                    current = self.owned(owner, pid)
                    current['render'].update(status='failed', error='Render failed: check owned source media, storage quota and server rendering capability.')
                    self.changed(current)
            finally:
                with self.lock:
                    self.active.discard(rid)
        try:
            thread = threading.Thread(target=worker, daemon=True)
            self.threads = [t for t in self.threads if t.is_alive()]
            self.threads.append(thread)
            thread.start()
        except BaseException:
            with self.lock:
                self.active.discard(rid)
                p['render'].update(status='unknown', error='Render admission interrupted; no automatic resubmission.')
                self.changed(p)
        return self.get(owner, pid)

    def patch(self, owner, pid, data):
        fields = validated(ProjectPatch, data)
        with self.lock:
            original = self.owned(owner, pid)
            self.revision(original, fields.pop('revision'))
            p = copy.deepcopy(original)
            global_change = any(k in fields and fields[k] != p[k] for k in ('idea', 'aspect_ratio', 'script'))
            editorial = global_change
            scene_data = fields.pop('scenes', None)
            p.update(fields)
            if scene_data is not None:
                existing = {s['id']: s for s in original['scenes']}
                scenes = []
                seen = set()
                for s in scene_data:
                    sid = s.get('id')
                    if sid and sid not in existing:
                        raise HTTPException(422, 'Scene does not belong to this project')
                    sid = sid or uuid.uuid4().hex
                    if sid in seen:
                        raise HTTPException(422, 'Duplicate scene')
                    seen.add(sid)
                    old = existing.get(sid)
                    new = dict(s, id=sid, attempts=copy.deepcopy(old['attempts']) if old else [])
                    new.setdefault('selected_attempt_id', None)
                    selected = new.get('selected_attempt_id')
                    if selected and not any(a['id'] == selected and a['status'] == 'completed' for a in new['attempts']):
                        raise HTTPException(422, 'Select a completed take from this scene')
                    content_change = not old or any(new[k] != old[k] for k in ('prompt', 'narration', 'duration'))
                    if content_change or global_change:
                        new['approved'] = False
                    editorial |= content_change or not old or any(new.get(k) != old.get(k) for k in ('order', 'approved', 'selected_attempt_id'))
                    scenes.append(new)
                if len({s['order'] for s in scenes}) != len(scenes) or sum(s['duration'] for s in scenes) > 120:
                    raise HTTPException(422, 'Scene order must be unique; total duration must not exceed 120 seconds')
                editorial |= set(existing) != seen
                p['scenes'] = sorted(scenes, key=lambda s: s['order'])
            if global_change:
                p['script_approved'] = False
                for s in p['scenes']:
                    s['approved'] = False
            editorial |= p['script_approved'] != original['script_approved']
            if editorial and p['render']:
                p['render']['outdated'] = True
            self.data['projects'][pid] = p
            self.changed(p)
            return self.public(p)
