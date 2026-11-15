# CI local verification evidence

## Repeat-run deployment repair (local only)

Inspected HEAD `c448fe1` with existing bootstrap/documentation/inventory edits;
those changes are preserved. Source-grounded defect: the upload used exclusive
`mkdir incoming/<SHA>`, so any earlier complete or interrupted attempt blocked a
rerun. This does not establish the latest hosted failure's exact cause without
its failing-step log. RED reproduced identical upload-directory commands for two
same-SHA runs; the fixed transport uses random per-attempt paths and noclobber.

- Guarded `tests/test_deploy.py`: **27 tests pass**. Coverage includes real local
  Bash upload commands through an exact synthetic SSH stub: interrupted archive
  retained, successful same-SHA retries with different expected image IDs, old
  SHA directory preserved, competing partial-file/symlink writes refused. No
  external SSH/Docker is run. Remote tests prove exact attempt/revision binding,
  backward-compatible four-argument deploy, no-follow private lock rejection and
  two-thread serialization, missing/symlink archive rejection, immutable image
  ID/revision/contract failures before stop, and safe image-load failure stages.
- Full scratch root-dependency Python venv `tools/ci_backend.py`: **exit 0,
  42 guarded scripts; 6 explicit browser/socket exclusions**. Evidence:
  `/Users/nhatngo/.hermes/cache/scratch/deploy-fix-backend.log`.
- All **5 Node scripts**, actionlint (`-shellcheck=`; optional shellcheck not
  installed), `bash -n tools/deploy_ssh.sh tools/bootstrap_vps.sh` and
  `git diff --check`: **exit 0**.
- Command failures/timeouts use fixed sanitized stages; raw subprocess/SSH
  stderr, configuration and token-bearing command strings are not published.
  Docker load retains its 180-second timeout; a failed load does not stop the
  runtime. No destructive retry cleanup or bootstrap behavior was added.
- No network, live SSH/VPS/Muse, secret lookup, production change, global install,
  commit or push was performed. Docker image build and hosted Actions deploy are
  not verified by these local regressions. Publishing the changes and a new
  authorized push-main run remain pending; rerunning an old revision cannot load
  these unpushed scripts.

## InstaBox token transport (local only)

Starting checkout HEAD: `3668e70` (clean); the earlier async-image fix is retained.
Regression RED: `python3 tests/test_deploy.py` ran 15 tests and failed exactly on
missing token-mode keyless support and unknown-mode acceptance. After transport
implementation, guarded deployment tests pass **17/17**, including safe token
syntax, required pins, default key requirement, ignored stale key in token mode,
strict SSH argv, stderr token redaction, preserved exit 255 and private-file
cleanup. SSH is an exact local synthetic stub, never an external connection.

- Scratch root-dependency `ci-clean-venv` full `tools/ci_backend.py`: **exit 0,
  41 guarded scripts, 6 explicit exclusions**. Evidence:
  `/Users/nhatngo/.hermes/cache/scratch/ci-instabox-backend.log`.
- All **5 Node scripts**: exit 0. `bash -n tools/deploy_ssh.sh`,
  `git diff --check`, actionlint 1.7.12 with `-shellcheck=`: exit 0.
- Official InstaBox SSH guide and token API were read: token authentication uses
  SSH `none`; token response includes `hostKeyFingerprint`. Deployment docs
  distinguish the gateway host CA/raw key from the guest's unrelated sshd key.
- Docker remains unavailable in this environment; no image-build success claimed.
  No real SSH token, external SSH/scan, Muse request, private data, secret/settings
  change, commit/stage/push or deployment was used/performed. No hosted run URL.


## Async-image runner timing fix (2026-11-15)

Investigated clean HEAD `88be6b89521bdcee246312f3c97ebc6d70486b41`.
The Ubuntu/Python 3.13.18 failure occurs in the guarded Python step, before
Docker or SSH; it does not diagnose `VPS_KNOWN_HOSTS`. Production
`images_generations` dispatches `_queue_image`, which starts a worker and returns
202 without joining it. No production/security/workflow changes were needed.

The old test released generation after 250 ms and required total request time
below 200 ms. Injecting 300 ms before ASGI dispatch deterministically reproduced
`async_generation_http=202 returned_before_completion=False` and exit 1 on the
old test. This demonstrates a false failure, not a production synchronous route.
The replacement asserts causality: a worker has entered generation, HTTP has
returned 202, and generation is still blocked on the unreleased event. Independent
request execution allows a synchronous event-loop-blocking mutation to fail.
Five/ten/fifteen-second waits are deadlock watchdogs, not latency requirements.
All application workers are released and joined in `finally`, including storage
and admission cleanup after their terminal task update, before HOME deletion.
The threading proxy is module-local; executor thread creation is not patched.

Local evidence uses scratch `ci-clean-venv` Python **3.13.0**, not Ubuntu 3.13.18:

- Injected 300 ms request overhead: old test exit 1; revised test exit 0.
- Mutated `_queue_image` to join its real worker while still returning HTTP 202:
  revised test exit 1, `image endpoint still synchronous`; no remaining threads.
- Injected an assertion before release plus 300 ms of post-release generation:
  expected assertion exit 1, no remaining threads and no temporary-HOME error.
- Revised unmodified offline script: **20/20** fresh-process repetitions passed.
- Resumed exact `tools/ci_backend.py`: **exit 0, 41 guarded scripts, 6 explicit
  browser/socket exclusions**, using scratch `RUNNER_TEMP`, `TMPDIR` and
  `MUSE2API_TEST_TMP`. The earlier deployment-fixture failure was reproduced
  (1 failure, 4 errors) and corrected only in `tests/test_deploy.py`: a module-local
  mock maps the exact fixture root to a permitted lexical path. Real ownership,
  permissions, symlink, authority, release-ID and filesystem checks still run;
  production `tools/deploy_remote.py` is unchanged. **11 deployment tests pass**,
  including a dotted/spaced fixture proving production path rejection, other-path
  rejection, private-file rejection, and mock restoration.
- Separate full-inventory diagnostic: **41/41 passed**. Repeated focused test:
  **20/20 passed** again. Rechecked 300 ms delay: exit 0; synchronous mutation and
  injected assertion: expected exit 1, both `remaining_threads_after_failure=set()`.
- All **5 Node scripts** passed; `git diff --check` passed.

Raw files under `/Users/nhatngo/.hermes/cache/scratch/`:
`async-image-probe.py`, `async-image-verify.py`, `async-image-red-slow.log`,
`async-image-green-slow.log`, `async-image-sync-negative.log`,
`async-image-assertion-cleanup.log`, `async-image-repeat.log`,
`async-image-full-backend.log`, `async-image-inventory.log`, `async-image-node.log`.
Resume evidence: `async-image-resume-backend.log`, `async-image-resume-slow.log`,
`async-image-resume-sync.log`, `async-image-resume-assertion.log`; inventory,
repeat and Node logs above were refreshed. `pip check` reports no broken requirements.
Scratch evidence expires. Reproduce the standard gate with the commands in
CI.md; synthetic fixtures now also work in dotted/spaced scratch paths.
Hosted Linux rerun and parent
independent verification remain pending. No live Muse/app, network, Docker,
SSH/deployment, credential access, global install, commit or push was performed.

## Standalone isolated bootstrap verification (2026-11-15)

`tools/bootstrap_vps.sh` replaces fragile multiline terminal initialization.
RED detected the missing script; real embedded-code execution then detected a
missing cookie-key environment assignment before explicit ledger creation.
Both corrected and verified. `tests/test_bootstrap_vps.py`: **9 tests pass** under
the guarded offline runner, including synthetic Docker sequencing, failed init
without success/approvals, partial-key/marker rejection, empty-directory reuse,
unsafe permission/symlink refusal, embedded Python compilation and actual
synthetic authority/encrypted-ledger initialization in disposable scratch.
`bash -n tools/bootstrap_vps.sh` passes. Inventory and narrow exact-stub subprocess
allowance updated; full `tools/ci_backend.py` exits 0: **42 guarded scripts,
6 explicit exclusions**. No live Docker, SSH, VPS, Muse, production credentials,
commit or push. This is not proof of a running image/VPS deployment.

## Auto-deployment revision (2026-11-15)

Current workflow adds push-main-only pinned SSH deployment after tests/build.
Earlier sections below describe the previous build-only revision, not current
activation. New deployment tests use synthetic command mocks, not a VPS.
Required activation: VPS_KNOWN_HOSTS, explicitly prepared VPS_DEPLOY_PATH and
operator bootstrap/cutover approvals; see DEPLOYMENT.md. No remote execution,
commit, staging, push or secret reading occurred. Docker build remains blocked
by unavailable daemon and missing buildx. Verified: guarded backend runner exit 0
(41 scripts, 6 explicit exclusions); 10 synthetic deployment tests included; all
5 Node suites exit 0; actionlint 1.7.12 (shellcheck disabled), bash -n and git
diff --check exit 0. Graphify update exit 0. Evidence: scratch
`ci-deploy-backend.log`, `ci-deploy-graph.log`. No hosted run URL or image/startup
success is claimed.

## Current server-only revision (2026-11-15)

The user narrowed automatic builds to the server. The current workflow has only
one Ubuntu `backend` job for push, pull request and manual dispatch; Flutter jobs
and client uploads were removed. No frontend files were changed by this revision.
The checkout was already dirty (including earlier CI files and unrelated work);
those existing changes were preserved, not reset, staged or published.

| Gate | Actual current result |
| --- | --- |
| Regression RED before edits | `test_ci_backend.py` exit 1: two expected failures, detecting the automatic Flutter job and missing Docker runtime modules. |
| actionlint 1.7.12 | Exit 0 on revised `.github/workflows/ci.yml`; shellcheck integration disabled (not installed). |
| Python command equivalent | Existing scratch Python 3.13 venv with only root dependencies: `python tools/ci_backend.py` exit 0, **40 guarded scripts, 6 explicitly excluded**. |
| Docker source packaging alternative | CI tests copy Dockerfile's literal root file inputs into scratch, compile copied Python, and check transitive local imports using AST without importing/starting app. Passed as part of the guarded suite. This is not an image build. |
| Node command equivalents | All **5** `.cjs` / `.mjs` scripts exit 0 using Node 22.21.1. |
| Actual Docker build attempt | `docker build --pull --tag muse2api-ci:check --file Dockerfile .` **exit 1**: Docker daemon unavailable at the local desktop-linux socket. The Docker CLI also reports a missing buildx plugin. **No successful local image build is claimed.** |

The Dockerfile previously omitted `authority.py`, `idempotency.py`,
`operations.py`, `protection.py` and `tenant.py`; these are now copied into the
server image. New deny-all `.dockerignore` permits only server build inputs.
The GitHub Ubuntu runner will attempt a real Docker image build after synthetic
tests pass. Base pulls, apt/pip installation, Docker layers and Python 3.11/Linux
image compatibility remain **unverified locally** until a daemon-backed build
runs. The packaging check is narrower evidence, not a substitute image-success
claim. No Docker daemon was started or production configuration changed.

Current raw evidence in `/Users/nhatngo/.hermes/cache/scratch/`:
`ci-server-backend.log` and `ci-server-docker.log`; the checksum-validated
`ci-actionlint/actionlint` tool was reused. No secrets, application startup,
Muse request, commit/push/stage, image publish, deploy or remote run occurred.
`gh` is not installed locally, so no GitHub CLI authentication/remote CI check was
possible; no remote success is claimed. No artifact upload remains in the workflow.

## Historical broader verification — no longer the automatic CI scope

The results below belong to the earlier local backend + Flutter verification.
They are retained as historical evidence only: Flutter is **not** rerun by or
included in the current server-only workflow. Earlier client artifact/retention
references below do not apply to current CI runs.

Executed on 2026-11-15 in the actual checkout at
`/Volumes/CAI_MAC/mycode/muse2api`, not on a GitHub-hosted runner.
Baseline was clean at `abe7a95`, with no `.github` workflows. The live checkout
was different from the older parent context (which described uncommitted source
and upstream `b60f474`); no user changes were reset or staged.

## Results from actual commands

| Gate | Observed result |
| --- | --- |
| Portable orchestration RED | New `test_ci_backend.py` failed twice with `portable CI runner is missing` before implementation. |
| Packaging RED | `test_desktop_build.py` failed because `authority.py` was missing from `ENGINE_SOURCES` before allowlist correction. |
| Fresh dependency environment | Created scratch-only Python 3.13.0 venv and installed **only** root `requirements.txt`; exit 0. No global tools installed. |
| `python tools/ci_backend.py` in fresh venv | Exit 0: **40 guarded scripts passed; 6 explicitly excluded**. This is a script count, not a fabricated unified unittest total. |
| All Node `.cjs` / `.mjs` suites | Exit 0, **5 scripts**, including legacy admin error-message test. |
| `flutter pub get --enforce-lockfile` | Exit 0, lock honored. Flutter **3.47.5**, Dart **3.13.4**. |
| `flutter analyze --no-pub` | Exit 0, **No issues found**. |
| `flutter test --no-pub --reporter expanded` | Exit 0, **340 tests passed**. |
| `flutter build web --release --no-pub` | Exit 0, **Built build/web** (JavaScript release). |
| `flutter build macos --release --no-pub --config-only` | Exit 0. |
| Workflow-equivalent `xcodebuild` Release, signing disabled | Exit 0, **BUILD SUCCEEDED**, Xcode **16.2 / 16C5032a**, CocoaPods **1.16.2**. |
| Native binary inspection | Universal Mach-O **x86_64 + arm64**. `codesign -dv` showed **adhoc,linker-signed**, **TeamIdentifier=not set**; no Developer ID/development signing credentials used. |
| `ditto` artifact archive | Exit 0, ZIP contains **260 entries**; checked no path components `.env`, `data`, `chrome-profile`, `muse2api-profiles`, `desktop_setup`, `muse_engine`. |
| actionlint | **1.7.12**, exit 0 after fixing invalid job-level `runner.temp` context. Shellcheck integration disabled because shellcheck is not installed; action/schema/expression checking ran. |
| Graph refresh | `graphify update .` exit 0, code-only/no LLM: **3788 nodes, 7117 edges, 226 communities**. Existing unsupported platform formats remain excluded; semantic docs not refreshed. |

Actionlint was downloaded into scratch only from its GitHub release and checked
against the release checksum file before execution:
`actionlint_1.7.12_darwin_arm64.tar.gz`, SHA-256
`aba9ced2dee8d27fecca3dc7feb1a7f9a52caefa1eb46f3271ea66b6e0e6953f`.
Action commit pins were resolved against public GitHub tag references, not guessed.
Runner image documentation confirms Xcode 16.2 exists on macos-15; actual remote
image execution remains unverified.

## Fixture problems exposed and corrected (not product bypasses)

The first broad guarded run found three older fixtures incompatible with current
security behavior. They remain selected, not excluded:

- Keepalive fake configuration lacked `api_key` required by fresh admin authority
  checks; it now retains the real synthetic configuration's key.
- The reference-image validation matrix exhausted rate windows before finishing
  validation cases; it now creates a fresh real limiter per independent case.
  Rate protection remains exercised by protection suites; no production limits
  were changed.
- Reference-limit endpoint checks outlived their temporary HOME; durable authority
  reads therefore failed. Their fixture HOME now survives through all endpoint
  calls and is cleaned at process exit.
- Legacy Node fetch fake lacked `headers.get`, and its 429 expectation predated
  the safe manual-retry guidance. The fake now implements headers; assertions
  require the existing default 60-second/manual-no-resubmit message. No product
  source was weakened to accommodate tests.

Desktop packaging source allowlist now includes `authority.py`, `idempotency.py`
and `operations.py`; tests verify their exact source bytes are copied. CI client
artifacts intentionally do not bundle the Python engine, so this is not evidence
of a full packaged desktop-engine build.

## Retained machine-local raw evidence

Under `/Users/nhatngo/.hermes/cache/scratch/`:

- `ci-clean-backend.log`, `ci-backend-final.log`, `ci-inventory.json`;
- `ci-pip.log`, `ci-macos-build.log`, `ci-graph-update.log`;
- `ci-actionlint/actionlint` (isolated validated tool).

Flutter pub/analyze/test/web command's complete captured tool output is retained
at `/Users/nhatngo/.hermes/cache/terminal-output/out-1794737237-5311-7950.log`.
Generated local client artifacts are in ignored `muse_app/build/web/` and
`muse_app/build/ci-artifacts/muse-macos-unsigned.zip`. These local scratch paths
are evidence locations, not hardcoded workflow requirements or committed data.

## Limits

No remote run URL exists: no commit, push, manual workflow dispatch or remote
Actions execution occurred. GitHub-hosted Ubuntu/macOS and action download/cache
behavior cannot be certified by local command success. Branch protection is not
configured. CI source must be reviewed, tracked and pushed with user permission.
The selected suite is not the full socket/browser backend suite; exclusions and
invocation flags are documented in `CI.md` and printed by the runner. Native
app launch, playback, signing/notarization/distribution, bundled backend startup,
production data and real Muse/cookie/API behavior were not exercised.

Existing nonfatal FastAPI lifecycle deprecations, Flutter secure-storage SwiftPM
warning and secure-storage WebAssembly dry-run incompatibility warnings remain.
The requested JavaScript web build and CocoaPods macOS build succeed despite
these warnings. No global signing, native entitlement or automation-permission
changes were made.
