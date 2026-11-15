# Upstream v1.6.10 update verification

## Source and preservation

- Before: `8a3dab9db13b23ac694d21af29e65504bc7e69b1` (v1.6.9).
- After: `b60f474977f125210eb7c71b0fc6668b2f1dd700` (v1.6.10); `git ls-remote origin refs/heads/main` confirmed the same SHA at completion.
- Fast-forwarded main without committing local work. No hard reset or clean.
- Verified backup: `/Users/nhatngo/.hermes/cache/scratch/muse2api-update-20261114-171700/source-and-git.tar.gz`, with `manifest.json`, `before.patch`, and `before-status.txt` alongside. All 1192 archived files verified against SHA-256; 129 Flutter lib files included. Excluded regenerated builds, dependency/cache directories; archive also includes Git metadata. No backed-up source files missing after update (`preservation-audit.json`).
- Kept local .gitignore, desktop Config field, app/desktop/tools/tests/docs, prompt tools, direct save, and theme. Reconciled engine startup-lock indentation with existing desktop sandbox/CDP isolation. Missing desktop attribute on upstream SimpleNamespace fixtures now defaults to false.
- No dependency lockfile, native AVFoundation pin, signing, entitlement or SwiftPM configuration changes. Test dependencies were installed only into an isolated scratch virtualenv because the available Python lacked backend dependencies; no global environment modified.

## Contracts and bounded app change

Upstream changes account selection to strict LRU rotation for image/video/chat, default concurrency from 2 to 8, narrows Muse composer Send selection, retries unsent composer content once, serializes browser startup, and adds silent background self-updates. Existing generation routes, models, request payloads, media and prompt-tool APIs remain unchanged. These scheduler/browser changes stay in Python, not duplicated in Flutter; configured concurrency overrides remain intact.

Flutter now recognizes the specific v1.6.10 composer-not-sent error and displays a static Vietnamese explanation directing users to check task status before retrying. It never exposes upstream body details or auto-retries POST. New fixture test failed first, then passed in the full suite. This is bounded compatibility support, not a claim of full admin UI parity.

**Safety deviation from upstream:** the new silent updater invokes an existing force-checkout updater. Added a fail-closed worktree guard in `_silent_upgrade_worker` so modified/untracked local work or an unverifiable repository cannot be overwritten by automatic updates. Two tests failed before implementation and pass afterward. The explicit administrative upgrade endpoint remains upstream behavior and is not a safe replacement for the backup/merge workflow used here; do not invoke it on this customized checkout.

## Executed verification

Logs and fixtures are in `/Users/nhatngo/.hermes/cache/scratch/muse2api-update-20261114-171700/`.

- `flutter analyze`: no issues (`flutter-analyze.log`).
- `flutter test --reporter expanded`: **281 passed** (`flutter-suite.log`).
- `flutter build macos --debug`: built `build/macos/Build/Products/Debug/muse_app.app` (`flutter-macos.log`). This is the Flutter build only, not a newly packaged Python/browser engine bundle.
- `flutter build web`: built `build/web` (`flutter-web.log`). Existing secure-storage WebAssembly dry-run warnings remain; standard JS web build succeeds. macOS logs retain the secure-storage plugin SwiftPM-support warning.
- **31 isolated non-browser Python test scripts passed**, each in a separate process to respect their environment/CLI conventions (`backend-isolated-results.json` and individual logs). Includes 17 desktop unittest cases, 10 quota parser cases, scheduler/API/reference tests and 2 new updater safety cases; script count is not a pytest case count.
- Real installed Chrome, synthetic local fixtures: composer Send scoping and reference-upload browser tests passed (`test_composer_send_browser.py.browser.log`, `test_reference_upload_browser.py.browser.log`). Existing Chrome was invoked headless through a scratch-only wrapper; no OS automation tooling installed. Media-selection browser fixture also passed (`test_media_selection.py.browser.log`).
- `node tests/test_admin_api_error_messages.mjs`: all checks passed.
- `git diff --check`: clean.
- `graphify update .`: refreshed code graph, 3011 nodes / 5533 edges. Community labels changed; graph tool recommends optional label refresh. No semantic LLM rebuild was performed.

## Remaining limits and failures

- Full unittest discovery is not a valid runner for this repository: several test files parse command-line arguments or execute at import time, contaminating shared app state. Its failed attempt is retained in `backend-suite.log`; separate script execution passed as above.
- Upstream web-admin layout test still fails at English 320px viewport: measured body width 326px (viewport 320px), with `Page overflows the viewport`. Earlier tested sizes passed. Retained in `test_admin_layout.py.browser.log`; no unrelated web-admin redesign made. This is not Flutter layout failure.
- No live Muse generation, quota calls, private uploads, OS dialog interaction, native credential persistence, runtime app restart or packaged desktop engine rebuild was performed. Existing already-installed engine bundles may need rebuilding/reinstalling through the established desktop workflow to pick up the new Python source; Flutter build alone does not refresh them. No app installation or replacement of a running app was attempted.
