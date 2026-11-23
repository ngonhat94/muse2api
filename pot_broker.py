"""Bounded per-job anonymous PO Token IPC; no tokens enter durable job state."""
import json
import os
from pathlib import Path
import re
import select
import socket
import stat
import struct
import threading
import time

SOCKET_PATH = '/run/muse-pot/provider.sock'
MAX_FRAME = 32768

class PotError(Exception):
    def __init__(self, reason='youtube_po_provider_failed'):
        self.reason = reason
        super().__init__(reason)


def enabled():
    # Deployment-only opt-in, never accepted from the download request.
    return os.name == 'posix' and os.environ.get('MUSE_YOUTUBE_POT_SOCKET') == SOCKET_PATH


def recv_frame(sock):
    def read(count):
        chunks = bytearray()
        while len(chunks) < count:
            part = sock.recv(count-len(chunks))
            if not part:
                raise PotError()
            chunks.extend(part)
        return bytes(chunks)
    size = struct.unpack('!I', read(4))[0]
    if not 0 < size <= MAX_FRAME:
        raise PotError()
    try:
        data = json.loads(read(size))
    except (ValueError, UnicodeError):
        raise PotError() from None
    if not isinstance(data, dict):
        raise PotError()
    return data


def send_frame(sock, data):
    data = json.dumps(data, separators=(',', ':')).encode()
    if len(data) > MAX_FRAME:
        raise PotError()
    sock.sendall(struct.pack('!I', len(data)) + data)


def validate_request(data, video_id):
    if set(data) != {'client', 'context', 'video_id', 'binding', 'binding_type'}:
        raise PotError('youtube_po_request_rejected')
    if data['client'] != 'mweb' or data['context'] != 'gvs' or data['video_id'] != video_id:
        raise PotError('youtube_po_request_rejected')
    if not isinstance(video_id, str) or not re.fullmatch(r'[A-Za-z0-9_-]{11}', video_id):
        raise PotError('youtube_po_request_rejected')
    if data['binding_type'] not in ('video_id', 'visitor_data'):
        raise PotError('youtube_po_request_rejected')
    binding = data['binding']
    if not isinstance(binding, str) or not re.fullmatch(r'[A-Za-z0-9_%=+/-]{1,2048}', binding):
        raise PotError('youtube_po_request_rejected')
    if data['binding_type'] == 'video_id' and binding != video_id:
        raise PotError('youtube_po_request_rejected')
    return dict(data)


def validate_response(data, request, now=None):
    now = time.time() if now is None else now
    if set(data) != {'token', 'expires_at', 'binding', 'binding_type', 'context', 'client', 'video_id'}:
        raise PotError()
    for key in ('binding', 'binding_type', 'context', 'client', 'video_id'):
        if data[key] != request[key]:
            raise PotError('youtube_po_binding_mismatch')
    token, expiry = data['token'], data['expires_at']
    if not isinstance(token, str) or not re.fullmatch(r'[A-Za-z0-9_-]{16,16384}={0,2}', token):
        raise PotError()
    if type(expiry) not in (int, float) or not now+5 < expiry <= now+86400:
        raise PotError('youtube_po_token_expired')
    return dict(data, expires_at=min(expiry, now+480))


def provider_exchange(request, cancelled, check):
    """Exact configured Unix endpoint. No HTTP, DNS, redirect, cookies or proxy."""
    check()
    if cancelled.is_set():
        raise InterruptedError()
    metadata = os.lstat(SOCKET_PATH)
    if (not stat.S_ISSOCK(metadata.st_mode) or metadata.st_uid != os.getuid()
            or stat.S_IMODE(metadata.st_mode) != 0o600):
        raise PotError('youtube_po_provider_failed')
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as conn:
        conn.settimeout(22)
        conn.connect(SOCKET_PATH)
        _, uid, _ = struct.unpack('3i', conn.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, 12))
        if uid != os.getuid(): raise PotError()
        # Cancel/revocation closes IPC while provider process is running.
        finished = threading.Event()
        def supervise():
            while not finished.wait(.1):
                try:
                    check()
                    if cancelled.is_set():
                        raise InterruptedError()
                except Exception:
                    try: conn.shutdown(socket.SHUT_RDWR)
                    except OSError: pass
                    return
        monitor = threading.Thread(target=supervise, daemon=True)
        monitor.start()
        try:
            send_frame(conn, request)
            result = recv_frame(conn)
        finally:
            finished.set()
            monitor.join(timeout=1)
    check()
    if cancelled.is_set():
        raise InterruptedError()
    return validate_response(result, request)


class JobBroker:
    """One instance per admitted worker: one binding, one mint attempt, no disk cache."""
    def __init__(self, video_id, check, cancelled, exchange=provider_exchange):
        self.video_id, self.check, self.cancelled = video_id, check, cancelled
        self.exchange = exchange
        self.request = self.response = None
        self.attempted = False

    def get(self, data):
        self.check()
        if self.cancelled.is_set(): raise InterruptedError()
        request = validate_request(data, self.video_id)
        if self.attempted:
            if request != self.request or self.response is None:
                raise PotError('youtube_po_request_rejected')
            if self.response['expires_at'] <= time.time()+5:
                raise PotError('youtube_po_token_expired')
            return self.response
        self.attempted = True
        self.request = request
        # Consume attempt before external call; no automatic retry on uncertainty.
        response = validate_response(self.exchange(request, self.cancelled, self.check), request)
        self.check()
        if self.cancelled.is_set(): raise InterruptedError()
        self.response = response
        return response

    def close(self):
        self.request = self.response = None


def serve_job(conn, broker):
    try:
        with conn:
            conn.settimeout(25)
            while not broker.cancelled.is_set():
                broker.check()
                if not select.select([conn], [], [], .2)[0]: continue
                data = recv_frame(conn)
                try:
                    response = broker.get(data)
                except PotError as exc:
                    send_frame(conn, {'error': exc.reason})
                    continue
                except (OSError, ValueError):
                    send_frame(conn, {'error': 'youtube_po_provider_failed'})
                    continue
                send_frame(conn, response)
    except Exception:
        pass
    finally:
        broker.close()
