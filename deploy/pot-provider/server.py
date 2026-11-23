"""Private Unix-only sidecar. Job state lives solely in a bounded child process."""
import json
import os
from pathlib import Path
import resource
import select
import signal
import socket
import stat
import struct
import subprocess
import threading
import time

from pot_broker import SOCKET_PATH, MAX_FRAME, PotError, recv_frame, send_frame, validate_request, validate_response

LIMIT = threading.BoundedSemaphore(2)


def check_ipc_directory(path):
    metadata=path.lstat()
    if (not stat.S_ISDIR(metadata.st_mode) or metadata.st_uid!=10001
            or metadata.st_gid!=10001 or stat.S_IMODE(metadata.st_mode)!=0o700):
        raise ValueError('Private UID10001 IPC directory is required')


def prepare_socket(path):
    """Remove only an owned, mode-0600, refused stale socket in private IPC."""
    try: before=path.lstat()
    except FileNotFoundError:return
    if (not stat.S_ISSOCK(before.st_mode) or before.st_uid!=os.getuid()
            or stat.S_IMODE(before.st_mode)!=0o600):
        raise ValueError('Refusing a foreign IPC path')
    with socket.socket(socket.AF_UNIX,socket.SOCK_STREAM) as probe:
        probe.settimeout(.5)
        try:probe.connect(str(path))
        except ConnectionRefusedError:pass
        else:raise ValueError('Provider socket is already serving')
    after=path.lstat()
    if (before.st_dev,before.st_ino)!=(after.st_dev,after.st_ino):
        raise ValueError('IPC path changed during verification')
    path.unlink()


def child_limits():
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
    resource.setrlimit(resource.RLIMIT_CPU, (20, 20))


def mint(conn, request):
    process = subprocess.Popen(['/usr/local/bin/node','--max-old-space-size=192','/opt/muse/mint.mjs'],
        stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,
        env={'PATH':os.defpath,'LANG':'C.UTF-8','HOME':'/tmp'},
        start_new_session=True,preexec_fn=child_limits)
    try:
        process.stdin.write(json.dumps(request).encode())
        process.stdin.close()
        response = bytearray()
        deadline = time.monotonic()+20
        while time.monotonic()<deadline:
            readable,_,_=select.select([conn,process.stdout],[],[],.1)
            if conn in readable:
                # Disconnect, cancellation or unexpected second frame: stop minting.
                raise PotError()
            if process.stdout in readable:
                data=os.read(process.stdout.fileno(),min(4096,MAX_FRAME+1-len(response)))
                if not data: break
                response.extend(data)
                if len(response)>MAX_FRAME: raise PotError()
        else:
            raise PotError()
        if process.wait(timeout=1)!=0: raise PotError()
        return validate_response(json.loads(response),request)
    finally:
        if process.poll() is None:
            os.killpg(process.pid,signal.SIGKILL)
            process.wait()
        process.stdout.close()


def handle(conn):
    try:
        with conn:
            conn.settimeout(23)
            # UID-scoped channel: backend and sidecar share this deployment identity.
            _,uid,_=struct.unpack('3i',conn.getsockopt(socket.SOL_SOCKET,socket.SO_PEERCRED,12))
            if uid!=os.getuid(): return
            request=recv_frame(conn)
            request=validate_request(request,request.get('video_id'))
            result=mint(conn,request)
            send_frame(conn,result)
    except Exception:
        # No provider stderr, stack traces, binding or token in logs/responses.
        pass
    finally:
        LIMIT.release()


def main():
    if os.getuid()!=10001 or os.getgid()!=10001:
        raise SystemExit('Provider requires UID/GID 10001:10001')
    path=Path(SOCKET_PATH)
    try:
        check_ipc_directory(path.parent)
        prepare_socket(path)
    except (OSError,ValueError):raise SystemExit('Provider socket is not safe to bind') from None
    os.umask(0o077)
    with socket.socket(socket.AF_UNIX,socket.SOCK_STREAM) as server:
        server.bind(str(path))
        os.chmod(path,0o600)
        server.listen(2)
        try:
            while True:
                conn,_=server.accept()
                if not LIMIT.acquire(blocking=False):
                    conn.close()
                    continue
                threading.Thread(target=handle,args=(conn,),daemon=True).start()
        finally:
            path.unlink(missing_ok=True)

if __name__=='__main__': main()
