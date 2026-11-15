# Server-only automatic CI and gated deployment

Deployment activation and existing-install limitations: [DEPLOYMENT.md](DEPLOYMENT.md).

For now `.github/workflows/ci.yml` runs **only the muse2api server** on every
`push`, `pull_request` and manual `workflow_dispatch`, without branch/path filters.
Flutter web/macOS jobs have been removed, including their artifact uploads.
Manual dispatch also runs only the server; no manual Flutter workflow is added.
Saving local files does not trigger Actions. Manual dispatch requires the workflow
on the default branch. No staging, commit, push or dispatch was performed.

## Gates and actual build

One `backend` job runs on Ubuntu 24.04, with a 30-minute timeout:

1. Install Python 3.13 root `requirements.txt` and use Node 22.
2. `python tools/ci_backend.py`: 41 inventoried Python scripts in independent
   guarded processes, each with a 120-second timeout. Unknown Python tests fail
   inventory validation rather than silently escaping coverage.
3. Run all five `tests/test_*.cjs` / `tests/test_*.mjs` synthetic admin suites.
4. Only after the tests pass, build the **actual server Dockerfile**:
   `docker build --pull --tag muse2api-ci:check --file Dockerfile .`.

The image uses the existing `python:3.11-slim-bookworm` base, not the Python 3.13
host test interpreter. Docker installs Chromium/fonts/system packages and Python
dependencies, but does **not** execute the image CMD, launch Chromium/the server
or contact Muse. Dependency/image/package downloads require public network access.
PRs, non-main pushes and manual dispatch stop at the build check. **Push main**
then transfers the exact image via pinned SSH for gated deployment; see
[DEPLOYMENT.md](DEPLOYMENT.md) for required known-host secret, explicit path,
bootstrap and legacy-cutover approval. No registry login/push is used.

The Dockerfile source list includes authority, idempotency, operations, protection
and tenant modules required by the current server. `.dockerignore` defaults to
deny-all and allowlists server build inputs; Flutter, Git metadata, data, profiles,
`.env`, accounts and caches are not sent as build context. Regression tests copy
literal Dockerfile file inputs to scratch, compile Python without importing the
application, and validate transitive local imports. This checks source packaging,
not Docker layers or Linux/browser compatibility.

**No downloadable artifacts are uploaded.** The `muse2api-ci:check` image exists
on the disposable runner; push-main deployments also retain the transferred image
and revision directory on the prepared VPS. No downloadable Actions artifacts exist. Previous client artifact
names/7-day retention no longer apply to new runs. Existing historical artifacts
are not deleted by this change.

## Offline test isolation and exclusions

`tests/run_backend_offline.py` installs deny-all socket connect/bind, DNS,
requests and browser/engine-start guards before each selected script. Disposable
fixture homes and a synthetic Fernet key replace real accounts/credentials.
Child Python processes are permitted only for the existing tenant cross-process
fixture. This is a Python guard, not an OS-level sandbox. Application regressions
are offline; public dependency installation and Docker builds are online.

Six Python scripts are explicitly excluded, not passed: `test_socks_proxy.py`
(real local sockets), `test_admin_layout.py`, `test_composer_send_browser.py`,
`test_reference_upload_browser.py`, `test_media_selection.py`,
`test_muse_video_delivery.py` (real Chromium/CDP/local HTTP).
`test_account_proxy.py --offline` excludes socket/browser cases;
`test_proxy_status_receipt.py --backend-only` omits its renderer subprocess
(the Node suites still run). No live Muse, native app launch or production data
behavior is established by these gates.

Scratch selection: `RUNNER_TEMP`, then `MUSE2API_TEST_TMP`, `TMPDIR`, then Python's
temp directory; paths resolve macOS `/var` symlinks for no-follow safeguards.
For local verification, choose writable scratch outside the repository:

```bash
set -euo pipefail
python3 -m venv "$TMPDIR/muse-ci-venv"
"$TMPDIR/muse-ci-venv/bin/python" -m pip install -r requirements.txt
RUNNER_TEMP="$TMPDIR" PYTHONDONTWRITEBYTECODE=1 \
  "$TMPDIR/muse-ci-venv/bin/python" tools/ci_backend.py
for test in tests/test_*.cjs tests/test_*.mjs; do node "$test"; done
# Requires a running Docker daemon; builds only, never starts the image:
docker build --pull --tag muse2api-ci:check --file Dockerfile .
```

## Safety and publication

Read-only `contents: read`, nonpersisted checkout credentials, commit-pinned
actions, requirements-keyed pip cache, noncancelable concurrency per event/ref or PR.
No `pull_request_target`, frontend signing or registry publish. Production SSH
secrets are scoped to the push-main deployment step only. No Flutter SDK or frontend source changes are needed for this workflow.
Server dependency constraints and the existing base tag are not immutable locks;
`--pull` follows the base tag, so future upstream package changes can affect builds.

Review the dirty checkout and exact remote before an authorized publication;
preserve unrelated work and never blanket-add generated files or credentials.
The workflow, CI runner/tests, Dockerfile, `.dockerignore`, requirements and server
sources must be included in any reviewed publication. Local changes have not
activated remote Actions, and no hosted run URL exists. See
[CI_VERIFICATION.md](CI_VERIFICATION.md) for actual results and Docker limitations.
