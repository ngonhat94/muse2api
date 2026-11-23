"""Isolated public-video downloader. No inherited provider/auth configuration."""
import ipaddress
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import threading
import time

MAX_BYTES = 128 * 1024**2
MAX_SECONDS = 600


def select_formats(context, quality):
    formats = list(reversed(context.get('formats') or []))
    videos = [f for f in formats if f.get('ext') == 'mp4' and f.get('vcodec') not in (None, 'none')
              and isinstance(f.get('width'), (int, float)) and isinstance(f.get('height'), (int, float))
              and 0 < min(f['width'], f['height']) <= quality]
    if not videos:
        return
    video = videos[0]
    if video.get('acodec') not in (None, 'none'):
        yield video
        return
    audio = next((f for f in formats if f.get('ext') == 'm4a' and f.get('vcodec') == 'none'
                  and f.get('acodec') not in (None, 'none')), None)
    if audio is None:
        yield video
        return
    yield dict(format_id=video['format_id']+'+'+audio['format_id'], ext='mp4',
               requested_formats=[video, audio], protocol=video['protocol']+'+'+audio['protocol'])


def public_address(host, port, family):
    if port not in (80, 443):
        raise PermissionError('Blocked destination port')
    answers = socket.getaddrinfo(host, port, family=family, type=socket.SOCK_STREAM)
    if not answers:
        raise PermissionError('Unresolved destination')
    for answer in answers:
        address = ipaddress.ip_address(answer[4][0])
        if not address.is_global or address.is_multicast or address.is_reserved or (address.version == 6 and address.ipv4_mapped and not address.ipv4_mapped.is_global):
            raise PermissionError('Blocked destination address')
    return answers[0][4]


def install_guards():
    # Patch the socket methods in this child only, including SSL subclasses.
    connect = socket.socket.connect
    connect_ex = socket.socket.connect_ex

    def guarded_connect(sock, address):
        return connect(sock, public_address(address[0], address[1], sock.family))

    def guarded_connect_ex(sock, address):
        return connect_ex(sock, public_address(address[0], address[1], sock.family))

    socket.socket.connect = guarded_connect
    socket.socket.connect_ex = guarded_connect_ex
    popen = subprocess.Popen
    binaries = {str(Path(p).resolve()) for n in ('ffmpeg', 'ffprobe') if (p := shutil.which(n))}

    class LocalMediaProcess(popen):
        def __init__(self, args, *extra, **kwargs):
            if not isinstance(args, (list, tuple)) or kwargs.get('shell'):
                raise PermissionError('Unsupported child process')
            executable = shutil.which(str(args[0]))
            if not executable or str(Path(executable).resolve()) not in binaries:
                raise PermissionError('Only local FFmpeg processes are allowed')
            safe = []
            for arg in args:
                if arg == '-i':
                    safe.extend(['-protocol_whitelist', 'file,pipe'])
                safe.append(arg)
            if Path(executable).stem == 'ffprobe' and '-i' not in args:
                safe[1:1] = ['-protocol_whitelist', 'file,pipe']
            super().__init__(safe, *extra, **kwargs)

    subprocess.Popen = LocalMediaProcess


def main(root):
    root = Path(root).resolve()
    os.chdir(root)
    if sys.platform == 'linux':
        import resource
        resource.setrlimit(resource.RLIMIT_AS, (1024**3, 1024**3))
        resource.setrlimit(resource.RLIMIT_FSIZE, (MAX_BYTES, MAX_BYTES))
    request = json.loads((root/'request.json').read_text())
    last = 0.0

    def report(stage, **fields):
        nonlocal last
        now = time.monotonic()
        if stage == 'downloading' and now - last < .4:
            return
        last = now
        output = root/'progress.tmp'
        output.write_text(json.dumps(dict(stage=stage, **fields)), encoding='utf-8')
        output.replace(root/'progress.json')

    parent = os.getppid()
    deadline = time.monotonic() + 480
    def watchdog():
        while True:
            if os.getppid() != parent or time.monotonic() > deadline:
                os._exit(1)
            time.sleep(.5)
    threading.Thread(target=watchdog, daemon=True).start()
    install_guards()
    # Import after the process guard so yt-dlp's Popen subclass inherits it.
    import yt_dlp
    from yt_dlp.globals import plugin_dirs
    plugin_dirs.value = []

    def check(info, *, incomplete=False):
        if incomplete:
            return None
        duration = info.get('duration')
        if info.get('is_live') or info.get('live_status') == 'is_live':
            return 'Live streams are unsupported'
        if not isinstance(duration, (float, int)) or not 0 < duration <= MAX_SECONDS:
            return 'Video duration limit'
        size = info.get('filesize') or info.get('filesize_approx')
        if size and size > MAX_BYTES:
            return 'Video size limit'
        return None

    def progress(value):
        total = value.get('total_bytes') or value.get('total_bytes_estimate')
        downloaded = value.get('downloaded_bytes') or 0
        if downloaded > MAX_BYTES or (total and total > MAX_BYTES):
            raise ValueError('Video size limit')
        info = value.get('info_dict') or {}
        report('downloading', downloaded=downloaded, total=total,
               title=str(info.get('title') or '')[:200])

    class Quiet:
        def debug(self, *args): pass
        def warning(self, *args): pass
        def error(self, *args): pass

    quality = request['quality']
    options = dict(
        format=lambda context: select_formats(context, quality),
        outtmpl=str(root/'video.%(ext)s'), paths={'home': str(root), 'temp': str(root)},
        noplaylist=True, playlist_items='1', cachedir=False, proxy='',
        cookiefile=None, cookiesfrombrowser=None, plugin_dirs=[], js_runtimes={},
        remote_components=set(), enable_file_urls=False, allow_unplayable_formats=False,
        socket_timeout=15, retries=0, fragment_retries=0, extractor_retries=0,
        concurrent_fragment_downloads=1, hls_prefer_native=True,
        external_downloader='native', skip_unavailable_fragments=False,
        max_filesize=MAX_BYTES, progress_hooks=[progress],
        merge_output_format='mp4', fixup='never', logger=Quiet(),
        quiet=True, no_warnings=True, windowsfilenames=True,
    )
    report('probing')
    try:
        with yt_dlp.YoutubeDL(options) as downloader:
            for name in list(downloader._request_director.handlers):
                if name != 'Urllib':
                    downloader._request_director.handlers.pop(name).close()
            info = downloader.extract_info(request['url'], download=False)
            if not info:
                raise ValueError('Video unavailable')
            if info.get('_type', 'video') != 'video':
                raise ValueError('Playlist unsupported')
            rejected = check(info)
            if rejected:
                raise ValueError(rejected)
            report('downloading', title=str(info.get('title') or '')[:200])
            downloader.params['match_filter'] = check
            result = downloader.process_ie_result(info, download=True)
        output = root/'video.mp4'
        if not output.is_file() or not 0 < output.stat().st_size <= MAX_BYTES:
            raise ValueError('Video size limit')
        probe = subprocess.run(
            ['ffprobe', '-v', 'error', '-protocol_whitelist', 'file', '-show_streams',
             '-show_format', '-of', 'json', str(output)],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, check=True, timeout=20)
        data = json.loads(probe.stdout)
        video = next(s for s in data['streams'] if s['codec_type'] == 'video')
        duration = float(data['format']['duration'])
        if ('mp4' not in data['format']['format_name'].split(',')
                or not 0 < duration <= MAX_SECONDS or not 0 < min(video['height'], video['width']) <= quality
                or max(video['height'], video['width']) > 4096 or video['height']*video['width'] > 8847360):
            raise ValueError('Video bounds limit')
        report('completed', title=str(result.get('title') or '')[:200], duration=duration,
               height=video['height'], width=video['width'], size=output.stat().st_size)
    except Exception as exc:
        message = str(exc).lower()
        code = 'unavailable'
        if 'limit' in message or 'bounds' in message:
            code = 'bounds'
        elif 'drm' in message:
            code = 'protected'
        elif any(s in message for s in ('sign in', 'login', 'cookies')):
            code = 'authentication_required'
        elif 'unsupported' in message:
            code = 'unsupported'
        report('failed', error_code=code)
        sys.exit(1)


if __name__ == '__main__':
    main(sys.argv[1])
