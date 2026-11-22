"""Scene-bound first frames. Only canonical, owner-scoped JPEGs reach generation."""
import base64
import copy
import hashlib
import io
import uuid

from fastapi import HTTPException
from PIL import Image, ImageOps

MAX_UPLOAD = 8 * 1024 * 1024


def canonical_image(data):
    try:
        with Image.open(io.BytesIO(data), formats=('JPEG', 'PNG', 'WEBP')) as src:
            if src.width * src.height > 16_000_000 or getattr(src, 'n_frames', 1) != 1:
                raise ValueError()
            img = ImageOps.exif_transpose(src).convert('RGB')
            img.thumbnail((2560, 2560))
            out = io.BytesIO()
            img.save(out, 'JPEG', quality=90)
            return out.getvalue()
    except (OSError, ValueError, Image.DecompressionBombError, SyntaxError):
        raise HTTPException(422, 'Invalid or oversized still image') from None


def find_scene(project, sid):
    for scene in project['scenes']:
        if scene['id'] == sid:
            return scene
    raise HTTPException(404, 'Scene not found')


def read_frame(store, owner, frame):
    name = frame['id']
    if store.media_owner(name) == owner:
        try:
            with store.open_media(name) as source:
                data = source.read(MAX_UPLOAD + 1)
            if data.startswith(b'\xff\xd8') and 0 < len(data) <= MAX_UPLOAD:
                if frame.get('sha256') and hashlib.sha256(data).hexdigest() != frame['sha256']:
                    raise HTTPException(409, 'First frame changed; replace and review it')
                return data
        except (ValueError, OSError):
            pass
    raise HTTPException(409, 'First frame unavailable; replace and review it')


def generation_reference(store, owner, frame):
    return 'data:image/jpeg;base64,' + base64.b64encode(read_frame(store, owner, frame)).decode('ascii')


def edit_frame(projects, store, owner, pid, sid, revision, *, image=None, approve_id=None, check):
    with projects.lock:
        original = projects.owned(owner, pid)
        projects.revision(original, revision)
        project = copy.deepcopy(original)
        scene = find_scene(project, sid)
        old = scene.get('first_frame')
        new_id = None
        check()
        if image is not None:
            new_id = 'first_frame_' + uuid.uuid4().hex + '.jpg'
            store.write_media(new_id, image, owner)
            scene['first_frame'] = {'id': new_id, 'approved': False, 'sha256': hashlib.sha256(image).hexdigest()}
            project['first_frame_mode'] = 'review'
        else:
            if not old or approve_id != old['id']:
                raise HTTPException(409, 'First frame changed; review the current image')
            old['sha256'] = hashlib.sha256(read_frame(store, owner, old)).hexdigest()
            old['approved'] = True
        try:
            check()
            projects.data['projects'][pid] = project
            projects.changed(project)
        except BaseException:
            projects.data['projects'][pid] = original
            if new_id:
                store.delete_media(new_id, owner_id=owner)
            raise
        if new_id and old and old['id'].startswith('first_frame_'):
            store.delete_media(old['id'], owner_id=owner)
        return projects.public(project)
