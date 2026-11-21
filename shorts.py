"""Durable local-only excerpts; never imports a generation/provider adapter."""
import copy
import hashlib
import json
import math
import time
import uuid
from fastapi import HTTPException
from pydantic import BaseModel, ConfigDict, Field
from video_projects import validated


class Draft(BaseModel):
    model_config = ConfigDict(extra='forbid', strict=True, allow_inf_nan=False)
    project_revision: int = Field(ge=1)
    title: str = Field(min_length=1, max_length=200)
    scene_ids: list[str] = Field(min_length=1, max_length=12)
    start: float = Field(ge=0)
    end: float = Field(gt=0)
    crop_x: float = Field(ge=0, le=1)
    burn_captions: bool


class DraftUpdate(Draft):
    revision: int = Field(ge=1)


def source_binding(p, ids):
    selected = []
    for sid in ids:
        scene = next((s for s in p['scenes'] if s['id'] == sid), None)
        if scene is None:
            raise HTTPException(422, 'Unknown source scene')
        take = next((a for a in scene['attempts'] if a['id'] == scene.get('selected_attempt_id')), None)
        if not scene['approved'] or not take or take['status'] != 'completed' or not take.get('media_id'):
            raise HTTPException(409, 'Approve an existing completed selected take')
        entry = dict(scene_id=sid, take_id=take['id'], media_id=take['media_id'], duration=scene['duration'],
                     narration=scene['narration'], prompt=scene['prompt'], order=scene['order'])
        if p.get('audio_mode') == 'spoken':
            from narration import current_audio
            entry['audio'] = copy.deepcopy(current_audio(scene))
        selected.append(entry)
    value: dict = dict(aspect_ratio=p['aspect_ratio'], audio_mode=p.get('audio_mode', 'legacy'), scenes=selected)
    value['binding'] = hashlib.sha256(json.dumps(value, sort_keys=True, ensure_ascii=False).encode()).hexdigest()
    return value


class ShortsService:
    def __init__(self, projects):
        self.projects = projects
        self.lock = projects.lock
        self.active = set()
        self.preview_slots = __import__('threading').BoundedSemaphore(2)
        self.threads = []
        with self.lock:
            dirty = False
            for p in projects.data['projects'].values():
                for s in p.get('shorts', {}).values():
                    for job in s['jobs'].values():
                        if job['status'] in ('queued', 'processing'):
                            job.update(status='unknown', error='Render interrupted; inspect receipt before a new explicit request.')
                            dirty = True
            if dirty:
                projects.save()

    def owned(self, owner, pid, sid):
        p = self.projects.owned(owner, pid)
        s = p.get('shorts', {}).get(sid)
        if not s:
            raise HTTPException(404, 'Short not found')
        return p, s

    def public(self, p, s):
        result = copy.deepcopy(s)
        try:
            current = source_binding(p, s['scene_ids']) == s['source']
        except HTTPException:
            current = False
        result['source_current'] = current
        job = s['jobs'].get(s['approved_render_id'])
        result['output_eligible'] = bool(current and job and job['status'] == 'completed' and job['revision'] == s['revision'])
        return result

    def get(self, owner, pid, sid):
        with self.lock:
            return self.public(*self.owned(owner, pid, sid))

    def list(self, owner, pid):
        with self.lock:
            p = self.projects.owned(owner, pid)
            return {'shorts': [self.public(p, s) for s in p.get('shorts', {}).values()]}

    def fields(self, p, body, update=False):
        f = validated(DraftUpdate if update else Draft, body)
        self.projects.revision(p, f['project_revision'])
        if len(set(f['scene_ids'])) != len(f['scene_ids']):
            raise HTTPException(422, 'Duplicate source scenes')
        source = source_binding(p, f['scene_ids'])
        total = sum(s['duration'] for s in source['scenes'])
        if not .25 <= f['end'] - f['start'] <= 60 or f['end'] > total:
            raise HTTPException(422, 'Segment must be within selected timeline and 0.25 to 60 seconds')
        f['source'] = source
        return f

    def create(self, owner, pid, body):
        with self.lock:
            p = self.projects.owned(owner, pid)
            f = self.fields(p, body)
            shorts = p.setdefault('shorts', {})
            if len(shorts) >= 50:
                raise HTTPException(429, 'Short draft limit reached')
            now = int(time.time())
            s = dict(f, id=uuid.uuid4().hex, revision=1, created_at=now, updated_at=now, jobs={}, approved_render_id=None)
            shorts[s['id']] = s
            self.projects.save()
            return self.public(p, s)

    def update(self, owner, pid, sid, body):
        with self.lock:
            p, s = self.owned(owner, pid, sid)
            f = self.fields(p, body, True)
            self.projects.revision(s, f.pop('revision'))
            s.update(f)
            s.update(revision=s['revision'] + 1, updated_at=int(time.time()), approved_render_id=None)
            self.projects.save()
            return self.public(p, s)

    def job(self, owner, pid, sid, rid):
        with self.lock:
            _, s = self.owned(owner, pid, sid)
            job = s['jobs'].get(rid)
            if not job:
                raise HTTPException(404, 'Render receipt not found')
            return copy.deepcopy(job)

    def render(self, owner, pid, sid, body, renderer, preflight):
        from video_projects import Submission
        import threading
        f = validated(Submission, body)
        try:
            rid = str(uuid.UUID(f['request_id']))
            if rid != f['request_id']:
                raise ValueError()
        except (ValueError, AttributeError):
            raise HTTPException(422, 'request_id must be a canonical UUID') from None
        with self.lock:
            p, s = self.owned(owner, pid, sid)
            receipts = self.projects.data.setdefault('short_receipts', {})
            key = owner + ':' + rid
            identity = dict(project=pid, short=sid, revision=f['revision'])
            if key in receipts:
                if receipts[key] != identity:
                    raise HTTPException(409, 'UUID already used with a different render payload')
                return self.job(owner, pid, sid, rid)
            self.projects.revision(s, f['revision'])
            if not self.public(p, s)['source_current']:
                raise HTTPException(409, 'Source changed; explicitly save a fresh draft')
            if len(s['jobs']) >= 50:
                raise HTTPException(429, 'Short render receipt limit reached')
            if len(self.active) >= 2 or any(x[0] == owner for x in self.active):
                raise HTTPException(429, 'Short render capacity reached')
            preflight()
            snapshot = copy.deepcopy({k:v for k,v in s.items() if k not in ('jobs', 'approved_render_id')})
            job = dict(id=rid, request_id=rid, revision=s['revision'], status='queued', snapshot=snapshot,
                       error=None, created_at=int(time.time()), media_id=None)
            s['jobs'][rid] = job
            receipts[key] = identity
            self.active.add((owner, rid))
            self.projects.save()
            accepted = copy.deepcopy(job)
        def worker():
            try:
                with self.lock:
                    job = self.owned(owner, pid, sid)[1]['jobs'][rid]
                    job['status'] = 'processing'
                    self.projects.save()
                mid = renderer(copy.deepcopy(snapshot))
                with self.lock:
                    job = self.owned(owner, pid, sid)[1]['jobs'][rid]
                    job.update(status='completed', media_id=mid)
                    self.projects.save()
            except Exception:
                with self.lock:
                    job = self.owned(owner, pid, sid)[1]['jobs'][rid]
                    job.update(status='failed', error='Local render failed; check source media, storage and rendering capability.')
                    self.projects.save()
            finally:
                with self.lock:
                    self.active.discard((owner, rid))
        try:
            thread = threading.Thread(target=worker, daemon=True)
            self.threads = [t for t in self.threads if t.is_alive()] + [thread]
            thread.start()
        except BaseException:
            with self.lock:
                job.update(status='unknown', error='Render admission interrupted; no automatic retry.')
                self.active.discard((owner, rid))
                self.projects.save()
        return accepted

    def approve(self, owner, pid, sid, rid, revision):
        with self.lock:
            p, s = self.owned(owner, pid, sid)
            self.projects.revision(s, revision)
            job = self.job(owner, pid, sid, rid)
            if job['status'] != 'completed' or job['revision'] != revision or not self.public(p, s)['source_current']:
                raise HTTPException(409, 'Only a current completed render can be approved')
            s['approved_render_id'] = rid
            self.projects.save()
            return self.public(p, s)
