"""App-owned engine entrypoint; stdin is both bootstrap channel and parent lease.

No credentials in argv, ready messages, logs, or build assets. The HTTP socket is
bound before startup so no free-port discovery/rebind race exists.
"""
from __future__ import annotations

import asyncio
from contextlib import contextmanager
import json
import os
from pathlib import Path
import socket
import sys
import threading


class EngineInUseError(OSError):
    """Fixed classification; never includes account or exception payloads."""


def bootstrap(line: str) -> tuple[Path, str]:
    value = json.loads(line)
    key = value.get("api_key", "")
    if not isinstance(key, str) or len(key) < 32:
        raise ValueError("invalid bootstrap")
    directory = Path(value["data_dir"])
    if not directory.is_absolute():
        raise ValueError("absolute application data directory required")
    directory.mkdir(parents=True, exist_ok=True, mode=0o700)
    if os.name != "nt":
        os.chmod(directory, 0o700)
        os.umask(0o077)
    # Override before importing config; never load the maintainer's .env/data.
    os.environ.update({
        "MUSE2API_HOME": str(directory), "MUSE2API_KEY": key,
        "MUSE2API_HOST": "127.0.0.1", "MUSE2API_DESKTOP": "1",
        "MUSE2API_PROFILE_ROOT": str(directory / "profiles"),
        "MUSE2API_CONCURRENCY": "1", "MUSE2API_EXTRA_PATH": "",
    })
    return directory, key


def browser_path() -> Path:
    root = Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parent))
    manifest = json.loads((root / "browser.json").read_text())
    relative = Path(manifest["executable"])
    if relative.is_absolute() or ".." in relative.parts:
        raise ValueError("invalid browser manifest")
    executable = root / relative
    if not executable.is_file():
        raise FileNotFoundError("bundled browser missing")
    return executable


@contextmanager
def instance_lock(directory: Path):
    """Keep two installed app processes from editing the same pool/profile."""
    with open(directory / "desktop.lock", "a+b") as handle:
        handle.seek(0)
        try:
            if os.name == "nt":
                import msvcrt
                if not handle.read(1):
                    handle.write(b"0")
                    handle.flush()
                handle.seek(0)
                msvcrt.locking(handle.fileno(), msvcrt.LK_NBLCK, 1)
            else:
                import fcntl
                fcntl.flock(handle, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except OSError:
            raise EngineInUseError() from None
        yield


def protocol(event: str, **fields) -> None:
    print(json.dumps({"event": event, **fields}), flush=True)


async def serve(parent_input) -> None:
    import uvicorn
    import app as backend

    # Desktop does not expose maintenance/update or remote cookie-helper routes.
    from fastapi.responses import JSONResponse
    @backend.app.middleware("http")
    async def desktop_routes(request, call_next):
        path = request.url.path
        if (path == "/" or path.startswith("/admin/repo")
                or path.startswith("/admin/update")
                or path.startswith("/admin/extension")
                or path.startswith("/admin/cookie-helper")):
            return JSONResponse({"detail": "Not available in desktop mode"}, status_code=404)
        return await call_next(request)

    # Reserve a browser debugging port; desktop engine never reuses an existing
    # browser endpoint. The browser has a private profile for this installation.
    with socket.socket() as debug:
        debug.bind(("127.0.0.1", 0))
        backend.CFG.cdp_port = debug.getsockname()[1]
    listener = socket.socket()
    listener.bind(("127.0.0.1", 0))
    listener.listen(128)
    server = uvicorn.Server(uvicorn.Config(backend.app, log_level="critical", access_log=False, lifespan="on", timeout_graceful_shutdown=3))
    loop = asyncio.get_running_loop()
    parent_gone = threading.Event()

    def watch_parent():
        try:
            # Parent sends one bootstrap line, then keeps this pipe open.
            while parent_input.readline():
                pass
        finally:
            parent_gone.set()
            loop.call_soon_threadsafe(setattr, server, "should_exit", True)
            backend.engine.stop()

    threading.Thread(target=watch_parent, daemon=True).start()
    task = asyncio.create_task(server.serve(sockets=[listener]))
    try:
        while not server.started:
            if task.done():
                await task
                raise RuntimeError("startup failed")
            if parent_gone.is_set():
                server.should_exit = True
            await asyncio.sleep(0.025)
        protocol("ready", port=listener.getsockname()[1])
        await task
    finally:
        server.should_exit = True
        # Uvicorn lifespan already stops the engine on graceful shutdown.
        backend.engine.stop()
        listener.close()


def main() -> int:
    if os.name != "nt":
        os.umask(0o077)
    stage = "bootstrap"
    try:
        directory, _ = bootstrap(sys.stdin.readline(65536))
        stage = "browser"
        os.environ["MUSE2API_CHROMIUM"] = str(browser_path())
        stage = "runtime"
        with instance_lock(directory):
            asyncio.run(serve(sys.stdin))
        return 0
    except Exception as error:
        # No exception payload: dependencies may include cookie/credential data.
        code = "startup_failed"
        if isinstance(error, EngineInUseError):
            code = "engine_in_use"
        elif stage == "browser":
            code = "browser_missing"
        elif isinstance(error, PermissionError):
            code = "storage_denied"
        protocol("error", code=code)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
