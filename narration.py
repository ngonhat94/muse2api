"""Opt-in OpenAI speech adapter. No SDK, automatic retry or simulation."""
import hashlib
import io
import json
import os
import shutil
import struct
import time
import wave

import requests
from fastapi import HTTPException
from pydantic import Field

MAX_AUDIO = 8 * 1024**2


def binding(scene):
    return hashlib.sha256(json.dumps([scene['narration'], scene['duration']], ensure_ascii=False).encode()).hexdigest()


def validate_audio(data, maximum):
    """Strict bounded PCM WAV; read complete payload, reject truncated/empty/silent."""
    try:
        if not 44 <= len(data) <= MAX_AUDIO or data[:4] != b'RIFF' or data[8:12] != b'WAVE':
            raise ValueError()
        if struct.unpack('<I', data[4:8])[0] + 8 != len(data):
            raise ValueError()
        with wave.open(io.BytesIO(data), 'rb') as w:
            channels, width, rate, frames, compression, _ = w.getparams()
            duration = frames / rate
            if channels not in (1, 2) or width != 2 or not 8000 <= rate <= 96000 or compression != 'NONE' or not 0.05 <= duration <= maximum + 0.05:
                raise ValueError()
            pcm = w.readframes(frames)
            if len(pcm) != frames * channels * width:
                raise ValueError()
            # No invented narration from empty/silent payloads. This is signal validation,
            # not proof that a provider pronounced every requested word.
            if max((abs(v[0]) for v in struct.iter_unpack('<h', pcm)), default=0) < 32:
                raise ValueError()
            return duration
    except (wave.Error, EOFError, ZeroDivisionError, struct.error, ValueError):
        raise ValueError('Invalid narration audio') from None


class OpenAISpeech:
    def __init__(self):
        # Read only on explicit server operation; never exposed in public capability.
        self.provider = os.getenv('MUSE_TTS_PROVIDER', '')
        self.key = os.getenv('MUSE_TTS_API_KEY', '')
        self.model = os.getenv('MUSE_TTS_MODEL', 'gpt-4o-mini-tts')
        self.voice = os.getenv('MUSE_TTS_VOICE', 'coral')

    def preflight(self):
        if self.provider != 'openai' or not self.key or not shutil.which('ffmpeg') or not shutil.which('ffprobe'):
            raise HTTPException(503, 'Narration provider is not configured')

    def generate(self, text, maximum):
        self.preflight()
        if not isinstance(text, str) or not 1 <= len(text.strip()) <= 4000:
            raise ValueError('Invalid narration text')
        deadline = time.monotonic() + 60
        # Explicit single attempt, fixed HTTPS origin; no ambient proxy credentials.
        with requests.Session() as session:
            session.trust_env = False
            with session.post('https://api.openai.com/v1/audio/speech',
                              headers={'Authorization': 'Bearer ' + self.key, 'Accept': 'application/octet-stream'},
                              json={'model': self.model, 'voice': self.voice, 'input': text, 'response_format': 'pcm', 'speed': 1.0},
                              timeout=(5, 20), stream=True, allow_redirects=False) as response:
                if response.status_code != 200 or response.headers.get('Content-Type', '').split(';')[0].lower() not in ('audio/pcm', 'application/octet-stream'):
                    raise ValueError('Narration provider failed')
                data = bytearray()
                for chunk in response.iter_content(65536):
                    if time.monotonic() > deadline or len(data) + len(chunk) > MAX_AUDIO:
                        raise ValueError('Narration response limit exceeded')
                    data.extend(chunk)
        # OpenAI documents PCM as signed 16-bit little-endian, mono 24 kHz.
        # Wrap explicitly rather than trusting streaming WAV sentinel lengths.
        if not data or len(data) % 2 or len(data) / 48000 > maximum + .05:
            raise ValueError('Invalid narration PCM')
        output = io.BytesIO()
        with wave.open(output, 'wb') as wav:
            wav.setparams((1, 2, 24000, 0, 'NONE', 'not compressed'))
            wav.writeframes(data)
        data = output.getvalue()
        return data, validate_audio(data, maximum)


def capability():
    adapter = OpenAISpeech()
    try:
        adapter.preflight()
        available = True
    except HTTPException:
        available = False
    return dict(available=available, provider='openai' if adapter.provider == 'openai' else None,
                timing='scene', max_characters=4000)


def captions(scenes, fmt):
    if fmt not in ('srt', 'vtt'):
        raise HTTPException(422, 'Caption format must be srt or vtt')
    def stamp(seconds):
        ms = round(seconds * 1000)
        h, ms = divmod(ms, 3600000)
        m, ms = divmod(ms, 60000)
        s, ms = divmod(ms, 1000)
        return f'{h:02}:{m:02}:{s:02}{"," if fmt == "srt" else "."}{ms:03}'
    blocks, cursor = [], 0
    for scene in sorted(scenes, key=lambda s: s['order']):
        audio = current_audio(scene)
        # Prevent cue injection / markup; plain readable scene text only.
        import re
        text = re.sub(r'<[^>]*>', '', scene['narration']).replace('-->', '→')
        text = ' '.join(text.split())
        blocks.append(f'{len(blocks)+1}\n{stamp(cursor)} --> {stamp(cursor + audio["duration"])}\n{text}')
        cursor += scene['duration']
    return ('WEBVTT\n\n' if fmt == 'vtt' else '') + '\n\n'.join(blocks) + '\n'


def current_audio(scene):
    state = scene.get('narration_audio')
    if not state or state['status'] != 'completed' or state['source_revision'] != binding(scene) or not state.get('media_id'):
        raise HTTPException(409, 'Every scene requires current completed narration audio')
    return state
