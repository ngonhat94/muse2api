"""Bounded FFmpeg crop/trim pipeline; only store-opened local regular media."""
import html
import json
import math
import os
import shutil
import subprocess
import tempfile
import time
import uuid
from pathlib import Path
from fastapi import HTTPException

WIDTH, HEIGHT = 720, 1280
FONT_FILES = ('/usr/share/fonts/truetype/freefont/FreeSans.ttf', '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf')


def capability():
    available = bool(shutil.which('ffmpeg') and shutil.which('ffprobe'))
    filters = subprocess.run(['ffmpeg', '-hide_banner', '-filters'], capture_output=True, timeout=10).stdout.decode() if available else ''
    return dict(available=available, burn_captions=available and ' subtitles ' in filters and any(Path(f).is_file() for f in FONT_FILES),
                max_duration=60, width=WIDTH, height=HEIGHT)


def require_capability(burn=False):
    cap = capability()
    if not cap['available'] or (burn and not cap['burn_captions']):
        raise HTTPException(503, 'Local FFmpeg subtitles/font unavailable; use MP4 with separate SRT/VTT captions')


def clips(snapshot):
    cursor = 0.
    result = []
    for scene in snapshot['source']['scenes']:
        start, end = max(cursor, snapshot['start']), min(cursor + scene['duration'], snapshot['end'])
        if end > start:
            result.append(dict(scene, offset=start-cursor, length=end-start, output_start=start-snapshot['start']))
        cursor += scene['duration']
    return result


def caption_text(snapshot, format='srt'):
    if format not in ('srt', 'vtt'):
        raise HTTPException(422, 'Caption format must be srt or vtt')
    def stamp(seconds):
        ms = round(seconds * 1000)
        h, ms = divmod(ms, 3600000)
        m, ms = divmod(ms, 60000)
        s, ms = divmod(ms, 1000)
        return f'{h:02}:{m:02}:{s:02}' + ('.' if format == 'vtt' else ',') + f'{ms:03}'
    entries = []
    for c in clips(snapshot):
        speech_end = c.get('audio', {}).get('duration', c['duration'])
        length = min(c['offset'] + c['length'], speech_end) - c['offset']
        text = c['narration'].strip()
        if text and length > 0:
            # Plain-text export: prevent SRT/ASS markup injection and cue terminators.
            text = html.escape(' '.join(text.split()), quote=False)
            entries.append(f"{len(entries)+1}\n{stamp(c['output_start'])} --> {stamp(c['output_start']+length)}\n{text}\n")
    return ('WEBVTT\n\n' if format == 'vtt' else '') + '\n'.join(entries)


def geometry(width, height, position):
    if not (2 <= width <= 4096 and 2 <= height <= 4096 and math.isfinite(position) and 0 <= position <= 1):
        raise ValueError('Unsupported crop bounds')
    cw = min(width // 2 * 2, int(height * 9 / 16) // 2 * 2)
    ch = min(height // 2 * 2, int(width * 16 / 9) // 2 * 2)
    if min(cw, ch) < 2:
        raise ValueError('Crop too small')
    x = min(width - cw, int((width-cw)*position)) // 2 * 2
    y = (height-ch) // 4 * 2
    return f'crop={cw}:{ch}:{x}:{y},scale={WIDTH}:{HEIGHT},setsar=1'


class Pipeline:
    def __init__(self, store, owner, root, deadline):
        self.store, self.owner, self.root, self.deadline = store, owner, root, deadline
        self.bytes = 0

    def run(self, args, capture=False, limit=90):
        remaining = self.deadline - time.monotonic()
        if remaining <= 0:
            raise ValueError('Render deadline exceeded')
        return subprocess.run(args, stdout=subprocess.PIPE if capture else subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                              check=True, timeout=min(remaining, limit)).stdout

    def local(self, mid, name, maximum):
        if self.store.media_owner(mid) != self.owner:
            raise ValueError('Source not owned')
        target = self.root/name
        with self.store.open_media(mid) as source, target.open('xb') as out:
            size = os.fstat(source.fileno()).st_size
            self.bytes += size
            if not 0 < size <= maximum or self.bytes > 512*1024**2:
                raise ValueError('Input size limit')
            shutil.copyfileobj(source, out, 1024*1024)
        return target

    def probe(self, path):
        return json.loads(self.run(['ffprobe','-v','error','-protocol_whitelist','file','-show_streams','-show_format','-of','json',str(path)],True,30))

    def source(self, clip, index):
        source = self.local(clip['media_id'], f'input{index}.mp4',256*1024**2)
        info = self.probe(source)
        video = next((s for s in info['streams'] if s['codec_type']=='video'), {})
        duration = float(info.get('format',{}).get('duration',0))
        rate = video.get('avg_frame_rate','0/1').split('/')
        if not math.isfinite(duration) or not 0 < duration <= 300 or duration + .05 < clip['offset']+clip['length']:
            raise ValueError('Source too short or invalid')
        if not 0 < float(rate[0])/float(rate[1]) <= 240:
            raise ValueError('Unsupported frame rate')
        return source, video, any(s['codec_type']=='audio' for s in info['streams'])

    def base(self, source):
        return ['ffmpeg','-v','error','-nostdin','-threads','1','-filter_threads','1','-protocol_whitelist','file','-noautorotate','-i',str(source)]


def preview_frame(store, owner, snapshot, scratch, at):
    if not math.isfinite(at) or not 0 <= at < snapshot['end']-snapshot['start']:
        raise HTTPException(422, 'Frame time outside Short')
    require_capability()
    Path(scratch).mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='short-frame-',dir=scratch) as folder:
        p=Pipeline(store,owner,Path(folder),time.monotonic()+30)
        clip=next(c for c in clips(snapshot) if c['output_start'] <= at < c['output_start']+c['length'])
        source, video, _=p.source(clip,0)
        output=p.root/'frame.jpg'
        p.run(p.base(source)+['-ss',str(clip['offset']+at-clip['output_start']),'-vf',geometry(video['width'],video['height'],snapshot['crop_x']),'-frames:v','1','-threads','1',str(output)])
        data=output.read_bytes()
        if not 0 < len(data) <= 4*1024**2:
            raise ValueError('Preview size limit')
        return data


def render_short(store, owner, snapshot, scratch):
    require_capability(snapshot['burn_captions'])
    usage=store.storage_usage(owner)
    if usage['bytes'] >= usage['limits']['bytes'] or usage['files'] >= usage['limits']['files']:
        from protection import StorageQuotaExceeded
        raise StorageQuotaExceeded('Storage quota exceeded')
    Path(scratch).mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='short-render-',dir=scratch) as folder:
        p=Pipeline(store,owner,Path(folder),time.monotonic()+300)
        parts=clips(snapshot)
        for i,c in enumerate(parts):
            source,video,has_audio=p.source(c,i)
            cmd=p.base(source)
            if c.get('audio'):
                from narration import validate_audio, MAX_AUDIO
                speech=p.local(c['audio']['media_id'],f'speech{i}.wav',MAX_AUDIO)
                actual=validate_audio(speech.read_bytes(),c['duration'])
                if abs(actual-c['audio']['duration']) > .001:
                    raise ValueError('Narration duration changed')
                cmd += ['-protocol_whitelist','file','-i',str(speech)]
                audio_map='1:a:0'
            elif has_audio:
                audio_map='0:a:0'
            else:
                cmd += ['-f','lavfi','-i','anullsrc=r=48000:cl=stereo']
                audio_map='1:a:0'
            vf=f"trim=start={c['offset']}:duration={c['length']},setpts=PTS-STARTPTS,"+geometry(video['width'],video['height'],snapshot['crop_x'])+',fps=24'
            af=f"apad,atrim=start={c['offset']}:duration={c['length']},asetpts=PTS-STARTPTS,aresample=48000"
            cmd += ['-map','0:v:0','-map',audio_map,'-vf',vf,'-af',af,'-t',str(c['length']),'-c:v','libx264','-threads','1','-preset','veryfast','-crf','23','-pix_fmt','yuv420p','-c:a','aac','-ac','2','-ar','48000','-b:a','128k','-map_metadata','-1','-fs',str(64*1024**2),str(p.root/f'part{i}.mp4')]
            p.run(cmd)
        (p.root/'cuts.txt').write_text(''.join(f"file 'part{i}.mp4'\n" for i in range(len(parts))))
        output=p.root/'final.mp4'
        cmd=['ffmpeg','-v','error','-nostdin','-threads','1','-filter_threads','1','-protocol_whitelist','file','-f','concat','-safe','1','-i',str(p.root/'cuts.txt')]
        if snapshot['burn_captions']:
            (p.root/'captions.srt').write_text(caption_text(snapshot),encoding='utf-8')
            font = next(Path(f) for f in FONT_FILES if Path(f).is_file())
            # Fixed generated filenames only; caller paths never enter a filter expression.
            shutil.copyfile(font,p.root/'font.ttf')
            safe_path = str(p.root/'captions.srt').replace('\\','\\\\').replace(':','\\:').replace("'","\\'")
            cmd += ['-vf',f"subtitles=filename='{safe_path}':force_style='FontName={ 'FreeSans' if font.name=='FreeSans.ttf' else 'DejaVu Sans'},FontSize=20,Outline=2,MarginV=36'",'-c:v','libx264','-threads','1','-preset','veryfast','-pix_fmt','yuv420p','-c:a','copy']
        else:
            cmd += ['-c','copy']
        cmd += ['-movflags','+faststart','-map_metadata','-1','-fs',str(256*1024**2),str(output)]
        p.run(cmd)
        info=p.probe(output)
        streams=info['streams']; video=next((s for s in streams if s['codec_type']=='video'),{});audio=next((s for s in streams if s['codec_type']=='audio'),{})
        expected=snapshot['end']-snapshot['start']
        if len(streams)!=2 or video.get('width')!=WIDTH or video.get('height')!=HEIGHT or video.get('codec_name')!='h264' or audio.get('codec_name')!='aac':
            raise ValueError('Output stream validation failed')
        for duration in (info['format']['duration'],video.get('duration',0),audio.get('duration',0)):
            if not math.isfinite(float(duration)) or abs(float(duration)-expected) > .3:
                raise ValueError('Output timing mismatch')
        p.run(['ffmpeg','-v','error','-xerror','-nostdin','-threads','1','-protocol_whitelist','file','-i',str(output),'-map','0:v:0','-map','0:a:0','-f','null','-'])
        if not 0 < output.stat().st_size < 256*1024**2:
            raise ValueError('Output size limit')
        mid='short_'+uuid.uuid4().hex+'.mp4'
        store.write_media(mid,output.read_bytes(),owner)
        return mid
