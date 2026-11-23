"""Isolated public-video downloader. No inherited provider/auth configuration."""
import functools
import importlib.metadata
import ipaddress
import json
import os
from pathlib import Path
import re
import shutil
import signal
import socket
import subprocess
import sys
import threading
import time

MAX_BYTES = 128 * 1024**2
MAX_SECONDS = 600
DENO_VERSION = '2.9.8'
EJS_VERSION = '0.8.0'

# Values below, never exception text, may cross the worker boundary.
DIAGNOSTICS = {
    'upstream_failure': 'Nguồn video không trả kết quả tải hợp lệ.',
    'youtube_bot_check': 'YouTube yêu cầu xác minh chống bot. Không tự thử lại hoặc dùng cookie.',
    'youtube_login_required': 'Video YouTube yêu cầu đăng nhập hoặc quyền truy cập riêng.',
    'youtube_po_token_required': 'YouTube yêu cầu PO Token; máy chủ chưa cung cấp token phù hợp.',
    'youtube_js_runtime_missing': 'Máy chủ thiếu Deno để giải challenge YouTube.',
    'youtube_js_runtime_unsupported': 'Phiên bản Deno chưa nằm trong cấu hình được kiểm thử.',
    'youtube_ejs_missing': 'Máy chủ thiếu đúng phiên bản EJS đã ghim.',
    'youtube_js_challenge_failed': 'Không giải được challenge JavaScript của YouTube.',
    'upstream_rate_limited': 'Nguồn video đang giới hạn yêu cầu. Không tự thử lại.',
    'upstream_forbidden': 'Nguồn video từ chối truy cập. Chưa xác định nguyên nhân cụ thể.',
    'blocked_destination': 'Worker đã chặn đích mạng không được phép.',
    'blocked_process': 'Worker đã chặn tiến trình hoặc tùy chọn không được phép.',
    'authentication_required': 'Nguồn video yêu cầu đăng nhập.',
    'protected': 'Video có bảo vệ nội dung.',
    'bounds': 'Video vượt giới hạn được phép.',
    'unsupported': 'Nguồn hoặc loại video chưa được hỗ trợ.',
}


def safe_diagnostic(reason, flags=()):
    reason = reason if isinstance(reason, str) and reason in DIAGNOSTICS else 'upstream_failure'
    flags = flags if isinstance(flags, (list, tuple, set)) else ()
    return dict(reason=reason, message=DIAGNOSTICS[reason],
                flags=sorted({f for f in flags if isinstance(f, str) and f in DIAGNOSTICS})[:8])


def classify_error(value, youtube=False):
    # Strip URLs before matching: a query string/FAQ URL is not evidence of login.
    message = re.sub(r'https?://\S+', '', str(value)[:16384]).lower()
    if youtube:
        if any(s in message for s in ('not a bot', 'confirm you’re not', "confirm you're not")):
            return 'unavailable', 'youtube_bot_check'
        if ('po token' in message or 'po_token' in message) and any(s in message for s in ('missing', 'required', 'requires', 'not provided', 'no po token')):
            return 'unavailable', 'youtube_po_token_required'
        if 'javascript runtime' in message and any(s in message for s in ('no supported', 'missing', 'not found')):
            return 'unavailable', 'youtube_js_runtime_missing'
        if 'ejs' in message and any(s in message for s in ('missing', 'not available', 'not installed', 'unavailable')):
            return 'unavailable', 'youtube_ejs_missing'
        if 'challenge' in message and any(s in message for s in ('failed', 'failure', 'unable to solve')):
            return 'unavailable', 'youtube_js_challenge_failed'
        if any(s in message for s in ('private video', 'members-only', 'members only', 'age-restricted', 'login_required', 'sign in to verify your age')):
            return 'authentication_required', 'youtube_login_required'
    if 'blocked destination' in message or 'unresolved destination' in message:
        return 'unavailable', 'blocked_destination'
    if any(s in message for s in ('unsupported child process', 'unsupported deno', 'only local ffmpeg')):
        return 'unavailable', 'blocked_process'
    if 'http error 429' in message or 'too many requests' in message:
        return 'unavailable', 'upstream_rate_limited'
    if 'http error 403' in message or 'http error 401' in message:
        return 'unavailable', 'upstream_forbidden'
    if 'limit' in message or 'bounds' in message:
        return 'bounds', 'bounds'
    if 'drm' in message:
        return 'protected', 'protected'
    if any(s in message for s in ('please sign in', 'please log in', 'login required', 'requires authentication', 'requires login')):
        return 'authentication_required', 'youtube_login_required' if youtube else 'authentication_required'
    if 'unsupported' in message:
        return 'unsupported', 'unsupported'
    return 'unavailable', 'upstream_failure'


class DiagnosticLogger:
    """Retain only fixed flags; no raw messages, URLs or provider tracebacks."""
    def __init__(self, youtube):
        self.youtube, self.flags = youtube, set()

    def debug(self, *args):
        pass

    def warning(self, message):
        _, reason = classify_error(message, self.youtube)
        if reason != 'upstream_failure':
            self.flags.add(reason)

    error = warning


@functools.lru_cache(maxsize=4)
def _deno_version(path):
    try:
        result = subprocess.run([path, '--version'], capture_output=True, text=True, timeout=5,
                                env={'PATH': os.defpath, 'DENO_NO_UPDATE_CHECK': '1'})
        match = re.match(r'deno (\d+\.\d+\.\d+)\b', result.stdout)
        return match[1] if result.returncode == 0 and match else None
    except (OSError, subprocess.SubprocessError):
        return None


def youtube_support():
    reason = None
    try:
        ejs = importlib.metadata.version('yt-dlp-ejs')
    except importlib.metadata.PackageNotFoundError:
        ejs = None
    runtime = shutil.which('deno')
    version = _deno_version(runtime) if runtime else None
    if ejs != EJS_VERSION:
        reason = 'youtube_ejs_missing'
    elif not runtime:
        reason = 'youtube_js_runtime_missing'
    elif version != DENO_VERSION:
        reason = 'youtube_js_runtime_unsupported'
    return dict(available=reason is None, runtime='deno', runtime_version=version,
                ejs_version=ejs, diagnostic=safe_diagnostic(reason) if reason else None,
                live_verified=False)


DENO_INPUT_OPTIONS = frozenset((
    '--ext=js', '--no-code-cache', '--no-prompt', '--no-remote', '--no-lock',
    '--node-modules-dir=none', '--no-config', '--no-npm', '--cached-only',
    '--v8-flags=--jitless',
))
DENO_SAFE_OPTIONS = (
    '--ext=js', '--no-code-cache', '--no-prompt', '--no-remote', '--no-lock',
    '--node-modules-dir=none', '--no-config', '--no-npm', '--cached-only',
    '--deny-read', '--deny-write', '--deny-net', '--deny-env', '--deny-run',
    '--deny-ffi', '--deny-sys', '--deny-import',
    '--v8-flags=--jitless,--max-old-space-size=128',
)


def configure_limits():
    if sys.platform == 'linux':
        import resource
        # V8 reserves a large PROT_NONE cage, so RLIMIT_AS prevents startup.
        # RLIMIT_DATA bounds committed data allocations, not virtual reservations.
        resource.setrlimit(resource.RLIMIT_DATA, (1024**3, 1024**3))
        resource.setrlimit(resource.RLIMIT_CPU, (90, 90))
        resource.setrlimit(resource.RLIMIT_FSIZE, (MAX_BYTES, MAX_BYTES))
        resource.setrlimit(resource.RLIMIT_CORE, (0, 0))


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
    deno = shutil.which('deno')
    deno = str(Path(deno).resolve()) if deno else None

    class RestrictedProcess(popen):
        def __init__(self, args, *extra, **kwargs):
            if (not isinstance(args, (list, tuple)) or not args or kwargs.get('shell')
                    or kwargs.get('executable') or kwargs.get('preexec_fn')):
                raise PermissionError('Unsupported child process')
            executable = shutil.which(str(args[0]))
            executable = str(Path(executable).resolve()) if executable else None
            if deno and executable == deno:
                if list(args[1:]) == ['--version']:
                    safe = [deno, '--version']
                elif (len(args) >= 3 and args[1] == 'run' and args[-1] == '-'
                      and all(a in DENO_INPUT_OPTIONS for a in args[2:-1])):
                    safe = [deno, 'run', *DENO_SAFE_OPTIONS, '-']
                else:
                    raise PermissionError('Unsupported Deno invocation')
                kwargs['env'] = {'PATH': os.defpath, 'LANG': 'C.UTF-8', 'NO_COLOR': '1',
                                 'DENO_NO_UPDATE_CHECK': '1', 'DENO_NO_PROMPT': '1',
                                 'DENO_DIR': str(Path.cwd()/'.deno')}
                kwargs['cwd'] = str(Path.cwd())
                super().__init__(safe, *extra, **kwargs)
                return
            if not executable or executable not in binaries:
                raise PermissionError('Only local FFmpeg processes are allowed')
            safe = []
            for arg in args:
                if arg == '-i':
                    safe.extend(['-protocol_whitelist', 'file,pipe'])
                safe.append(arg)
            if Path(executable).stem == 'ffprobe' and '-i' not in args:
                safe[1:1] = ['-protocol_whitelist', 'file,pipe']
            super().__init__(safe, *extra, **kwargs)

    subprocess.Popen = RestrictedProcess


def main(root):
    root = Path(root).resolve()
    os.chdir(root)
    configure_limits()
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
                if os.name == 'posix' and os.getpgrp() == os.getpid() and os.getpid() > 1:
                    os.killpg(os.getpid(), signal.SIGKILL)
                os._exit(1)
            time.sleep(.5)
    threading.Thread(target=watchdog, daemon=True).start()
    from urllib.parse import urlsplit
    host = (urlsplit(request['url']).hostname or '').lower().rstrip('.')
    youtube = host == 'youtu.be' or host.endswith('.youtu.be') or host == 'youtube.com' or host.endswith('.youtube.com')
    if youtube:
        support = youtube_support()
        if not support['available']:
            report('failed', error_code='unavailable', diagnostic=support['diagnostic'])
            return
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

    logger = DiagnosticLogger(youtube)
    quality = request['quality']
    options = dict(
        format=lambda context: select_formats(context, quality),
        outtmpl=str(root/'video.%(ext)s'), paths={'home': str(root), 'temp': str(root)},
        noplaylist=True, playlist_items='1', cachedir=False, proxy='',
        cookiefile=None, cookiesfrombrowser=None, plugin_dirs=[],
        js_runtimes={'deno': {'path': shutil.which('deno')}} if youtube else {},
        remote_components=set(), enable_file_urls=False, allow_unplayable_formats=False,
        socket_timeout=15, retries=0, fragment_retries=0, extractor_retries=0,
        concurrent_fragment_downloads=1, hls_prefer_native=True,
        external_downloader='native', skip_unavailable_fragments=False,
        max_filesize=MAX_BYTES, progress_hooks=[progress],
        merge_output_format='mp4', fixup='never', logger=logger,
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
        code, reason = classify_error(exc, youtube)
        report('failed', error_code=code, diagnostic=safe_diagnostic(reason, logger.flags))
        sys.exit(1)


if __name__ == '__main__':
    main(sys.argv[1])
