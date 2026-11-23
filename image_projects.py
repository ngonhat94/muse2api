"""Atomic, owner-bound image storyboard imports without generation."""
import copy
import hashlib
import json
import time
import uuid

from fastapi import HTTPException

from first_frames import canonical_image
from video_projects import ProjectCreate, validated


def import_images(projects, store, owner, metadata, images, check):
    if set(metadata) != {'request_id', 'title', 'idea', 'aspect_ratio', 'duration'}:
        raise HTTPException(422, 'Invalid image storyboard metadata')
    try:
        rid = str(uuid.UUID(metadata['request_id']))
    except (ValueError, TypeError, AttributeError):
        raise HTTPException(422, 'request_id must be a UUID') from None
    fields = validated(ProjectCreate, {k: metadata[k] for k in ('title', 'idea', 'aspect_ratio')})
    duration = metadata['duration']
    if type(duration) is not int or not 1 <= duration <= 15 or not 3 <= len(images) <= 12 or duration * len(images) > 120:
        raise HTTPException(422, 'Require 3-12 images, 1-15 seconds each, 120 seconds total')
    canonical = []
    for image in images:
        check()
        canonical.append(canonical_image(image))
    digest = hashlib.sha256(json.dumps(dict(fields, duration=duration,
        images=[hashlib.sha256(i).hexdigest() for i in canonical]), sort_keys=True).encode()).hexdigest()
    key = owner + ':' + rid
    with projects.lock:
        check()
        previous = projects.data.get('image_imports', {}).get(key)
        if previous:
            if previous['action'] != 'image-import' or previous.get('digest') != digest:
                raise HTTPException(409, 'request_id already used for another payload')
            return projects.public(projects.owned(owner, previous['project']))
        if key in projects.data['requests'] or key in projects.data.get('reference_imports', {}):
            raise HTTPException(409, 'request_id already used for another action')
        if sum(p['owner_id'] == owner for p in projects.data['projects'].values()) >= 100:
            raise HTTPException(429, 'Project limit reached')
        now = int(time.time())
        project = dict(fields, id=uuid.uuid4().hex, owner_id=owner, revision=1,
            script=fields['idea'], script_approved=False, scenes=[], render=None,
            first_frame_mode='review', source_mode='images', created_at=now, updated_at=now)
        written = []
        before = copy.deepcopy(projects.data)
        try:
            for order, data in enumerate(canonical):
                check()
                name = 'first_frame_' + uuid.uuid4().hex + '.jpg'
                store.write_media(name, data, owner)
                written.append(name)
                project['scenes'].append(dict(id=uuid.uuid4().hex, order=order,
                    narration='', prompt='Chuyển động nhẹ, giữ chủ thể và bố cục của ảnh đầu.',
                    duration=duration, approved=False, attempts=[], selected_attempt_id=None,
                    first_frame=dict(id=name, approved=False, sha256=hashlib.sha256(data).hexdigest())))
            check()
            projects.data['projects'][project['id']] = project
            projects.data.setdefault('image_imports', {})[key] = dict(project=project['id'], action='image-import', digest=digest)
            projects.save()
        except BaseException:
            projects.data = before
            for name in written:
                store.delete_media(name, owner_id=owner)
            raise
        return projects.public(project)


def import_receipt(projects, owner, rid):
    try:
        rid = str(uuid.UUID(rid))
    except ValueError:
        raise HTTPException(422, 'request_id must be a UUID') from None
    with projects.lock:
        receipt = projects.data.get('image_imports', {}).get(owner + ':' + rid)
        if not receipt or receipt['action'] != 'image-import':
            raise HTTPException(404, 'Image storyboard receipt not found')
        return projects.public(projects.owned(owner, receipt['project']))
