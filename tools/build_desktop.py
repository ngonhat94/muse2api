#!/usr/bin/env python3
"""Build on the target OS/architecture. Packages a Python engine and Chromium.

Use a dedicated build venv with desktop/requirements-build.txt installed.
No developer .env, accounts, keys or generated media are copied.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build" / "desktop"
DIST = ROOT / "dist" / "desktop"

ENGINE_SOURCES = (
    "app.py", "engine.py", "store.py", "config.py", "cdp.py", "proxy.py", "tenant.py", "protection.py",
    'authority.py', 'idempotency.py', 'operations.py', 'client_config.py',
    'video_projects.py', 'first_frames.py', 'image_projects.py', 'web_downloads.py', 'web_download_worker.py', 'reference_videos.py', 'thumbnails.py', 'generation_timing.py',
    'narration.py', 'shorts.py', 'shorts_render.py',
    "requirements.txt", "desktop/launcher.py", "desktop/requirements-build.txt",
    "tools/build_desktop.py",
)


def source_fingerprint():
    digest = hashlib.sha256()
    for name in ENGINE_SOURCES:
        digest.update(name.encode())
        digest.update((ROOT / name).read_bytes())
    return digest.hexdigest()


def engine_bundle_ready(directory):
    """Reject a missing, incomplete, stale or foreign-platform helper bundle."""
    directory = Path(directory)
    try:
        executable = directory / ("muse_engine.exe" if os.name == "nt" else "muse_engine")
        if not executable.is_file() or not os.access(executable, os.X_OK):
            return False
        manifest = json.loads((directory / "browser.json").read_text())
        relative = Path(manifest["executable"])
        if relative.is_absolute() or ".." in relative.parts or not (directory / relative).is_file():
            return False
        record = json.loads((directory / "engine-build.json").read_text())
        return record == {"source": source_fingerprint(), "system": platform.system(), "machine": platform.machine()}
    except (OSError, ValueError, KeyError, TypeError):
        return False


def copy_setup_resources(destination):
    """Ship only the setup entrypoint and required source, never user data."""
    for name in (*ENGINE_SOURCES, "desktop/install.py"):
        target = Path(destination) / name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / name, target)


def run(args, **kwargs):
    subprocess.run([str(arg) for arg in args], check=True, cwd=ROOT, **kwargs)


def build_engine():
    browser_cache = BUILD / "browsers"
    env = dict(os.environ, PLAYWRIGHT_BROWSERS_PATH=str(browser_cache))
    run([sys.executable, "-m", "playwright", "install", "chromium", "--no-shell"], env=env)
    # Resolve the exact executable for this installed Playwright version.
    result = subprocess.run([sys.executable, "-c", "from playwright.sync_api import sync_playwright;\nwith sync_playwright() as p: print(p.chromium.executable_path)"], env=env, check=True, capture_output=True, text=True)
    browser = Path(result.stdout.strip())
    relative = browser.relative_to(browser_cache)
    browser_root = browser_cache / relative.parts[0]
    manifest = BUILD / "browser.json"
    manifest.write_text(json.dumps({"executable": str(Path("browser") / relative)}))
    run([sys.executable, "-m", "PyInstaller", "--noconfirm", "--clean", "--onedir",
         "--contents-directory", ".", "--name", "muse_engine",
         "--paths", ROOT, "--distpath", DIST, "--workpath", BUILD / "pyinstaller",
         "--specpath", BUILD, "--collect-all", "uvicorn", "--collect-all", "fastapi",
         "--add-data", f"{manifest}{os.pathsep}.",
         ROOT / "desktop" / "launcher.py"])
    destination = DIST / "muse_engine" / "browser" / browser_root.name
    shutil.copytree(browser_root, destination, dirs_exist_ok=True, symlinks=True)
    engine = DIST / "muse_engine"
    (engine / "engine-build.json").write_text(json.dumps({
        "source": source_fingerprint(), "system": platform.system(), "machine": platform.machine(),
    }))
    if not engine_bundle_ready(engine):
        raise RuntimeError("Desktop engine bundle is incomplete")
    return engine


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--engine-only", action="store_true")
    parser.add_argument("--flutter", default=shutil.which("flutter") or "flutter")
    args = parser.parse_args()
    BUILD.mkdir(parents=True, exist_ok=True)
    DIST.mkdir(parents=True, exist_ok=True)
    engine = build_engine()
    if args.engine_only:
        print(f"Engine bundle: {engine}")
        return
    target = {"Darwin": "macos", "Windows": "windows", "Linux": "linux"}[platform.system()]
    subprocess.run([args.flutter, "build", target, "--release"], cwd=ROOT / "muse_app", check=True)
    if target == "macos":
        candidates = list((ROOT / "muse_app/build/macos/Build/Products/Release").glob("*.app"))
        if len(candidates) != 1:
            raise RuntimeError("Expected one macOS app bundle")
        app = DIST / candidates[0].name
        if app.exists():
            shutil.rmtree(app)
        shutil.copytree(candidates[0], app, symlinks=True)
        shutil.copytree(engine, app / "Contents/Resources/muse_engine", symlinks=True)
        copy_setup_resources(app / "Contents/Resources/desktop_setup")
        # Local runnable artifact. Distribution still needs Developer ID signing
        # of nested binaries, hardened-runtime entitlements and notarization.
        run(["codesign", "--force", "--deep", "--sign", "-", app])
    else:
        base = ROOT / f"muse_app/build/{target}"
        candidates = list(base.glob("*/runner/Release" if target == "windows" else "*/release/bundle"))
        if len(candidates) != 1:
            raise RuntimeError("Expected one desktop output directory")
        app = DIST / "MuseStudio"
        if app.exists():
            shutil.rmtree(app)
        shutil.copytree(candidates[0], app, symlinks=True)
        shutil.copytree(engine, app / "muse_engine", symlinks=True)
        copy_setup_resources(app / "desktop_setup")
    print(f"Desktop app: {app}")


if __name__ == "__main__":
    main()
