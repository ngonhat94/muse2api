"""Opt-in scene narration providers and PCM WAV validation."""
import hashlib
import io
import json
import os
import re
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


def _bounded_body(response, limit, deadline):
    if response.status_code != 200:
        raise ValueError('Narration provider failed')
    data = bytearray()
    for chunk in response.iter_content(8192):
        if time.monotonic() > deadline or len(data) + len(chunk) > limit:
            raise ValueError('Narration response limit exceeded')
        data.extend(chunk)
    return bytes(data)


class VieNeuSpeech:
    provider = 'vieneu-gradio'
    # The Gradio operator selects the loaded model outside Muse.
    model = None

    def __init__(self):
        self.origin = os.getenv('MUSE_TTS_GRADIO_URL', '').rstrip('/')
        self.voice = os.getenv('MUSE_TTS_VOICE', 'Thiện Minh')

    def preflight(self):
        if not (re.fullmatch(r'https://[a-zA-Z0-9.-]+(?::[0-9]{1,5})?', self.origin)
                and self.voice.strip() and shutil.which('ffmpeg') and shutil.which('ffprobe')):
            raise HTTPException(503, 'Narration provider is not configured')

    def generate(self, text, maximum):
        self.preflight()
        if not isinstance(text, str) or not 1 <= len(text.strip()) <= 4000:
            raise ValueError('Invalid narration text')
        # The raw Gradio 5 /call protocol requires slots for both hidden State
        # inputs (mode and session), even though /info omits them.
        inputs = [text, self.voice, None, None, None, 'Standard (Một lần)',
                  False, 1, 0.8, 256, True, None]
        options = dict(timeout=(5, 30), stream=True, allow_redirects=False)
        deadline = time.monotonic() + 180
        with requests.Session() as session:
            session.trust_env = False
            events = self._call(session, 'wrapper', inputs, options, deadline)
            path = self._audio_path(events)
            # Rebuild on the configured origin. Never follow a provider-supplied URL.
            with session.get(self.origin + '/gradio_api/file=' + path, **options) as response:
                data = _bounded_body(response, MAX_AUDIO, deadline)
        return data, validate_audio(data, maximum)

    def _call(self, session, handler, inputs, options, deadline):
        endpoint = self.origin + '/gradio_api/call/' + handler
        with session.post(endpoint, json={'data': inputs}, **options) as response:
            ticket = json.loads(_bounded_body(response, 1024, deadline))
            event_id = ticket.get('event_id') if isinstance(ticket, dict) else None
        if not isinstance(event_id, str) or not re.fullmatch('[0-9a-f]{32}', event_id):
            raise ValueError('Invalid Gradio event')
        with session.get(endpoint + '/' + event_id, **options) as response:
            events = _bounded_body(response, 128 * 1024, deadline).decode('utf-8')
        return events

    def voices(self):
        self.preflight()
        try:
            with requests.Session() as session:
                session.trust_env = False
                events = self._call(session, '_srt_voices', [], dict(
                    timeout=(3, 8), stream=True, allow_redirects=False), time.monotonic() + 15)
            choices = self._result(events)[0]['choices']
            if not isinstance(choices, list) or len(choices) > 500:
                raise ValueError()
            catalog = {}
            for entry in choices:
                if not isinstance(entry, list) or len(entry) != 2:
                    continue
                label, voice = entry
                if (isinstance(label, str) and isinstance(voice, str) and
                        0 < len(voice) <= 128 and 0 < len(label) <= 512 and
                        voice.isprintable() and label.isprintable()):
                    catalog[voice] = label
            return catalog
        except (requests.RequestException, ValueError, TypeError, IndexError, KeyError):
            raise HTTPException(503, 'Voice catalog unavailable') from None

    @staticmethod
    def _result(events):
        for frame in events.replace('\r\n', '\n').split('\n\n'):
            lines = frame.splitlines()
            if 'event: error' in lines:
                break
            if 'event: complete' in lines:
                payload = '\n'.join(line[5:].lstrip() for line in lines if line.startswith('data:'))
                return json.loads(payload)
        raise ValueError('Gradio request failed')

    @staticmethod
    def _audio_path(events):
        result = VieNeuSpeech._result(events)
        if isinstance(result, list) and result and isinstance(result[0], dict):
            path = result[0].get('path')
            if isinstance(path, str) and re.fullmatch(r'/(?:data/)?tmp/gradio/[0-9a-f]{32,64}/[A-Za-z0-9_-]+\.wav', path):
                return path
        raise ValueError('Gradio returned no valid narration file')


def speech_adapter():
    if os.getenv('MUSE_TTS_PROVIDER') == VieNeuSpeech.provider:
        return VieNeuSpeech()
    return OpenAISpeech()


def capability():
    adapter = speech_adapter()
    try:
        adapter.preflight()
        available = True
    except HTTPException:
        available = False
    return dict(available=available, provider=adapter.provider if adapter.provider in ('openai', VieNeuSpeech.provider) else None,
                timing='scene', max_characters=4000,
                **({'voice_selection': True, 'default_voice': adapter.voice}
                   if isinstance(adapter, VieNeuSpeech) and available else {}))


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
