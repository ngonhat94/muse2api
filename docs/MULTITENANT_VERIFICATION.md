# Multi-tenant security and verification

This release adds fail-closed tenant ownership to the existing backend, web console, and Flutter client. Verification used synthetic fixtures only: no real Muse account, Cookie, API key, quota, production server, or device was used.

## Security model

- `MUSE2API_KEY` remains the legacy administrator credential. It owns all safely migrated legacy records under owner ID `admin`.
- `POST /admin/users` creates a user and returns a high-entropy `m2u_...` key once. `POST /admin/users/{id}/key` rotates it and also returns the new raw key once. `data/users.json` stores only SHA-256 key hashes. `PATCH /admin/users/{id}` enables/disables a user; `DELETE /admin/users/{id}/key` revokes its key.
- `GET /v1/me` returns the authenticated principal's ID, label, role, and capabilities. User-management, global API-key rotation, source update, and other global controls require the administrator role server-side; hiding them in the clients is only a usability layer.
- Account IDs, Cookies, proxy configuration, quota/session checks, chat, image/video jobs, task aliases, deletion/cancellation, keepalive, and media indexes are owner-scoped. Unknown ownership is denied. A depleted user pool fails without falling back to admin or another user.
- Generation admission uses independent outstanding reservations: 8 per owner across image/video/chat/responses (including synchronous requests), 64 globally. Cancelling/deleting/clearing task records does not free reservations; actual workers release them in `finally`. Missing/deleted task records are cancellation tombstones for their live worker, not permission to resume. Checks run before/after browser acquisition, after account acquisition, and immediately before upstream generation.
- Worker authority captures the authenticated key version. Disable, revoke, or rotation invalidates queued work, including requests authenticated before rotation but submitted afterward. Already transmitted upstream operations cannot be recalled. Rotation intentionally cancels old-version queued authority, not only future authentication.
- User-store operations take a stable advisory file lock and reload current data inside each read/modify/write transaction. Authentication and capability checks see cross-process revocations. The JSON account/task scheduler still requires one runtime worker/replica; startup rejects multi-worker environment configuration and acquires an exclusive data-directory lifetime lock. Deploy on a local filesystem supporting `flock`, not independent data copies/network replicas.
- Built-in automatic source replacement, explicit GitHub upgrade, and publication are disabled (HTTP 409 for admin mutations). A clean checkout is not proof of a tenant-aware release. Install only a separately reviewed release manually; no upstream security-contract downgrade is supported.
- Tenant reference normalization always disables server-local files and private-network fetch, even when the legacy administrator explicitly enables trusted-single-user configuration options.
- Media is not public. API responses contain a short-lived HMAC capability bound to owner, exact filename, expiry, and key version. The media route rechecks current user state, key version, and current media ownership. Disable, revoke, or rotate invalidates previous capabilities. API keys never appear in media URLs.
- Filenames are basenames with bounded length and accepted media suffixes. Traversal, unknown files, cross-owner IDs, and unindexed files fail closed.
- Cookie values and raw keys are not logged. The server necessarily communicates requested content to Muse and may fetch user-supplied public references; this is not described as zero-data-leak or end-to-end zero trust.

## Migration and rollback preparation

Before deploying, back up `data/accounts.json`, `data/tasks.json`, existing media, `.env`, `data/users.json`, `data/media-index.json`, and `data/media-index.json.ownership-migrated` if present. A durable exclusive-create marker permits legacy ownership migration once only. On that first initialization, legacy account/task records lacking ownership become admin-owned; supported on-disk media are adopted only if no ownership index previously existed. Existing index records lacking ownership are not repaired. Subsequent unknown files, missing/corrupt indexes, or records lacking ownership fail closed. The marker is persisted before migration, so interruption may require explicit operator recovery from backup but cannot silently adopt newly created blobs. Never delete the marker to repair an index. Migration never tests Cookies or calls Muse.

The externally verified source backup for this work is:

`/Users/nhatngo/.hermes/cache/scratch/muse2api-multitenant-backup-20261115-010752/source.zip`

If rollback is required, stop the service, restore the complete matching backup rather than selectively deleting ownership fields, and retain post-migration data separately for audit/recovery.

## API contract summary

| Method | Route | Access | Purpose |
| --- | --- | --- | --- |
| `GET` | `/v1/me` | any authenticated principal | identity, role, capabilities |
| `GET` / `POST` | `/admin/users` | admin | list/create users |
| `PATCH` | `/admin/users/{id}` | admin | label or enabled state |
| `POST` | `/admin/users/{id}/key` | admin | rotate and show raw key once |
| `DELETE` | `/admin/users/{id}/key` | admin | revoke current key |
| `POST` | `/admin/tasks/{id}/cancel` | owner | cancel an active owned task |
| `POST` | `/v1/images/tasks/{id}/cancel` | owner | image cancellation alias |
| `POST` | `/v1/videos/{id}/cancel` | owner | video cancellation alias |
| `GET` | `/v1/media/{name}?cap=...` | valid capability | fetch exact owned resource |

Existing account, task, image, video, chat, quota, and media routes keep their shapes but now return only the caller's records. Media/task responses refresh capability URLs so clients can recover from expiry by reloading the resource.

## Test-first evidence

RED logs were captured before implementation:

- `docs/verification-logs/multitenant-red.log`: user creation contract absent.
- `docs/verification-logs/task-cancel-red.log`: cancellation contract absent.
- `docs/verification-logs/flutter-principal-red.log`: Flutter principal/role contract absent.
- `docs/verification-logs/flutter-media-red.log`: protected-media URL validation absent.

GREEN evidence:

```sh
MUSE2API_TEST_TMP="$PWD/.test-tmp" TMPDIR="$PWD/.test-tmp" \
  .verification-venv/bin/python tests/test_multitenant_security.py

.verification-venv/bin/python -m py_compile app.py store.py tenant.py config.py engine.py

CI=true FLUTTER_SUPPRESS_ANALYTICS=true XDG_CONFIG_HOME="$PWD/../.test-config" \
  .flutter-sdk/bin/flutter analyze

CI=true XDG_CONFIG_HOME="$PWD/../.test-config" \
  .flutter-sdk/bin/cache/dart-sdk/bin/dart run test \
  test/features/connection_bloc_test.dart test/features/next_phases_transport_test.dart

CI=true XDG_CONFIG_HOME="$PWD/../.test-config" \
  .flutter-sdk/bin/cache/dart-sdk/bin/dart run tool/multitenant_contract_check.dart

CI=true FLUTTER_SUPPRESS_ANALYTICS=true XDG_CONFIG_HOME="$PWD/../.test-config" \
  .flutter-sdk/bin/flutter build web
```

Results: the A/B/admin synthetic isolation suite passed; Python compilation passed; Flutter analysis reported no issues; 15 socket-free Flutter transport/BLoC tests passed; the protected-media contract check passed; and the standard web build succeeded. Focused backend scripts for concurrency, async images, media deletion, proxy routing, keepalive, session health (177 cases), task cancellation, and API error handling also passed. Logs are in `docs/verification-logs/`.

## Backend security-review follow-up

The review-blocker regressions in `tests/test_tenant_review_blockers.py` passed **17 tests**. Observed pre-fix failures included stale cross-instance users, restart adoption of unknown media, cancel/delete admission bypass, and unsafe updater status (502 rather than fail-closed 409). Additional regression cases cover cross-process revocation/writes, process lock exclusion, worker configuration rejection, 64 global reservations, video cancel/clear, synchronous image/chat admission, queued disable/revoke/rotation, acquisition-time cancellation, and tenant local/private reference denial.

Final isolated execution passed **15 backend scripts**, recorded separately (not represented as one unittest total) in `docs/verification-logs/review-backend-results.json` with full per-script `review-*.log` files. This includes the 17-test review suite, A/B/admin isolation, concurrency, async images, media deletion, reference safety/hardening/limits, account proxy/routing, keepalive, session health (177 checks), local update safety (2 tests), Cookie requirements and refusal rotation. Python compilation of app/store/tenant/config/engine, extracted admin JavaScript `node --check`, and `git diff --check` also passed.

Interpreter used: `/Users/nhatngo/.hermes/cache/scratch/muse2api-update-20261114-171700/test-venv/bin/python`. Each script ran in its own synthetic `MUSE2API_HOME` / `MUSE2API_TEST_TMP` / `TMPDIR`, with repository `PYTHONPATH`. The documented repository `.verification-venv` was absent on this machine. FastAPI reports existing `on_event` deprecation warnings. These runs do not supersede the separate Flutter writer's verification or establish real Muse behavior. Parent independent security verification remains required before acceptance.

## Independently reproduced backend blockers: second follow-up

The earlier 17-test pass did **not** cover first-SSE disconnects or maintenance authority after lock waits. Those two findings were reproduced before this repair. Backend-only changes preserve the concurrent Flutter writer's files.

- Chat and Responses now use an explicitly closing streaming response. The request owns admission until `safe_chat_stream` transfers ownership immediately before starting its worker. Closing before that transfer releases the reservation, including unstarted iterator `aclose`, first-SSE `aclose`, and an actual ASGI first-body-send `OSError`. After transfer, only the worker's `finally` releases admission; disconnect cannot free a running worker's slot.
- Account test, account/global relogin, account/global quota, and single/batch keepalive share the existing **8 per owner / 64 global** outstanding budget with generation. Reservations are acquired before executor submission or keepalive-lock waits. One captured authority version covers a whole batch; `ContextVar` propagates it into executor workers. Checks occur after browser/account/keepalive waits and before upstream refresh, renewal, and quota calls. Async request cancellation shields the bounded maintenance operation so live workers retain their reservations. Already-transmitted upstream operations cannot be recalled.
- Aliases delegate to the same bounded implementations. Background tenant keepalive also captures current authority at batch admission. Global relogin is now async at the HTTP boundary so it reserves before dispatching its blocking probe into the executor.

Strict RED evidence (actual assertions, not import failures):

- `docs/verification-logs/blockers-stream-red.log`: 4 failed subcases, both routes × first-iterator-close / ASGI first-send failure.
- `docs/verification-logs/blockers-maintenance-red.log`: 21 failed subcases, 7 maintenance routes × revoke/disable/rotation during account acquisition, with forbidden upstream calls observed on synthetic fakes.
- `docs/verification-logs/blockers-unstarted-red.log`: unstarted iterator close still leaked; covered by the final explicit iterator wrapper.
- `docs/verification-logs/blockers-relogin-dispatch-red.log`: global relogin was synchronous, so framework dispatch preceded admission; its async boundary now reserves first.

Final command pattern, run separately for each script:

```sh
MUSE2API_TEST_TMP=/Users/nhatngo/.hermes/cache/scratch \
TMPDIR=/Users/nhatngo/.hermes/cache/scratch PYTHONDONTWRITEBYTECODE=1 \
/Users/nhatngo/.hermes/cache/scratch/muse2api-update-20261114-171700/test-venv/bin/python \
  tests/run_backend_offline.py tests/test_tenant_review_blockers.py
```

**9 isolated scripts passed**, listed with exact return codes and log paths in `docs/verification-logs/blockers-backend-results.json`: expanded review (**24 unittest tests**), multitenant isolation, concurrency, account proxy routing, keepalive scheduling, session health (**177 checks**), local update safety, Cookie requirements, and refusal rotation. These are separate script results, not one aggregate unittest count. `blockers-test_tenant_review_blockers.log` records `Ran 24 tests in 2.132s` / `OK`. Additional subcases cover live chat/Responses worker retention, shared admission across all maintenance aliases, stale authenticated principals, generation/keepalive lock invalidation, and cancellation while a quota worker remains live. Python AST compilation of the three changed backend Python files and `git diff --check` passed.

`tests/run_backend_offline.py` creates synthetic HOME/profile/data under the supplied scratch directory and prohibits socket connect/connect_ex/bind, DNS resolution, HTTP session requests, real engine entry points, and subprocess launches except the review suite's Python-only user-store/file-lock children. Session-health alone exercises real renewal/page-validation code against its mocked HTTP responses and page object; browser startup and sockets remain forbidden. No application startup/lifespan, live Muse requests, browser launch, private data reads, deployment, signing, global installs, commits, or Flutter edits were performed in this repair. Existing FastAPI `on_event` deprecation warnings remain. The async-image script's explicit startup path and socket/browser suites were not rerun under this no-startup contract.

Parent independent security review is still required. These offline results do not establish live Muse compatibility, recall transmitted operations, or justify multi-runtime deployment. The graph index was not regenerated because this repair is backend/docs only and another writer owns the client; source and executable tests are authoritative for these changes.

## Final proxy-diagnostics lifecycle repair

`POST /admin/accounts/{aid}/proxy/test` now admits asynchronously through `_bounded_maintenance` **before** executor dispatch, capturing the authenticated principal's key version. The synchronous worker rechecks after account acquisition, immediately before the fixed ipify GET (after proxy/session context entry), and before `renew_session_http`. Request cancellation does not cancel the shielded maintenance task: its reservation remains occupied until the executor operation finishes and the bounded wrapper's `finally` runs.

Strict RED/GREEN evidence:

- `proxy-lifecycle-red.log`: three assertion failures, revoke/disable/rotate during account acquisition still sent the synthetic ipify GET. `proxy-lifecycle-green.log` passes after admission/account-check changes.
- `proxy-outbound-red.log`: six assertion failures, three invalidations during proxy-context entry still sent GET and three invalidations inside the synthetic GET still renewed Muse. The final expanded suite passes both outbound boundaries.
- Expanded maintenance matrix includes **eight route functions**: `test_account_proxy`, `test_account`, `relogin_account`, `relogin`, `query_quota`, `query_any_quota`, `trigger_keepalive_single`, `trigger_keepalive_all`. Each has revoke/disable/rotate-after-account-acquisition, eight-reservation saturation and stale-principal rotation checks. Proxy-specific cancellation tests block at account acquisition, ipify and renewal separately; every case retains one reservation after cancellation, rejects a ninth admission without executor dispatch, then releases only after the worker finishes. Existing quota and chat/Responses lifetime tests remain.

Final offline run: **13 separate scripts passed**, recorded with exact arguments, return codes and logs in `docs/verification-logs/proxy-backend-results.json`. Expanded review reports **26 unittest tests**, account-proxy offline subset **4 tests**, and session health **177 checks**; these are not combined into one test total. Includes multitenant isolation, proxy routing/receipts, keepalive, concurrency, update safety, Cookie/refusal and reference-safety suites. Six changed Python files compiled via in-memory `compile`; `git diff --check` passed.

All runs used the existing scratch venv interpreter and `tests/run_backend_offline.py` with synthetic HOME/data, forbidden DNS/socket connect/bind, forbidden HTTP session requests, forbidden browser/startup and subprocess guards. `test_account_proxy.py --offline` excludes its localhost HTTP/CONNECT fixture; its other four tests exercise mocked HTTP/page objects, with browser start and sockets still forbidden. `test_proxy_status_receipt.py --backend-only` executes all backend receipt checks but deliberately excludes its Node renderer subprocess. Initial unrestricted account-proxy attempts failed at the guard (including the localhost bind); retained `proxy-test_account_proxy-offline.log` is an unsuccessful earlier attempt, not final evidence. No live calls or application startup occurred. Existing FastAPI deprecation warnings remain.

### Concrete outbound-route coverage inventory

AST inventory `docs/verification-logs/proxy-route-call-inventory.json` enumerates **50 HTTP route functions / 57 registrations**, with source lines and direct/nested call names. Source inspection followed delegated helpers rather than treating absence of direct `requests` calls as proof:

| Route family | Outbound operations / protection / coverage |
| --- | --- |
| `/admin/accounts/{aid}/proxy/test` | ipify GET then Muse HTTP renewal; asynchronous bounded admission plus post-account and per-operation checks; new invalidation/cancellation/saturation matrix and existing routing/receipt scripts. |
| `/admin/accounts/{aid}/test`, `/relogin`; `/admin/relogin` | browser start, refresh and (account test) quota; bounded test/relogin, per-operation authority checks; all alias matrix plus generation-lock invalidation tests. |
| `/admin/accounts/{aid}/quota`, `/admin/quota` | browser start/quota through bounded `query_quota`; all alias matrix, account/GEN_LOCK invalidation and live quota cancellation tests. |
| `/admin/accounts/{aid}/keepalive`, `/admin/accounts/keepalive` | HTTP renewal, optional helper browser quota; bounded single/batch with captured context; matrix, KEEPALIVE_LOCK invalidation, scheduling and session-health tests. Background owner batches use the same bounded implementation. |
| `/v1/images/tasks`, `/v1/images/generations`, `/v1/images/edits`, `/v1/videos`, `/v1/videos/generations` | shared generation worker renewal/browser/generation and retry paths use `OutstandingJob`; cancel/delete/clear admission and queued key-version tests remain. Reference normalization now shares the same pre-dispatch admission and captured authority through `_bounded_reference`; see the reference-admission follow-up below. Destination policy remains independently covered by the reference safety suites. |
| `/v1/chat/completions`, `/v1/responses` | shared `safe_chat_stream` renewal/browser/chat with worker authority and explicit reservation transfer; both-route early ASGI/iterator disconnect and live-worker lifetime coverage. |
| `/admin/update/check`, `/admin/repo/status` | administrator-only `_check_update_sync` GitHub metadata requests; not tenant Cookie maintenance. Not executed against network. |
| `/admin/update/upgrade`, `/admin/repo/pull`, `/admin/repo/push` | fail-closed before source replacement/publication; local update safety tests. Unreachable legacy request code is not an active outbound path. |
| All remaining registered routes | local store/identity/status/task/media reads and mutations, local static/extension file serving and key management; no tenant upstream operation found. Media capability delivery is local, not a remote fetch. |

No additional **maintenance-route** omission was found beyond proxy diagnostics. The pre-admission reference-fetch observation above is explicitly outside that claim and should be evaluated by the parent's independent review rather than silently treated as covered. Engine methods can themselves perform multiple HTTP exchanges; these tests establish application-operation boundaries, not recall of already transmitted requests or an atomic revocation/network transaction. Graph index was read but not rewritten to avoid another writer's client/index scope; current AST/source inventory is authoritative. No frontend edits, commits, global installs, signing or CuaDriver use. Parent independent acceptance remains required.

## Reference URL admission follow-up

All image generation/task/edit and video aliases now reserve **before normalization executor dispatch**, using the authenticated key version and the existing shared 8-owner/64-global budget. Image tasks are async at the HTTP boundary. The same reservation is transferred to synchronous generation or the queued worker, not reserved twice. Replays/errors before worker transfer release it; live normalization/generation retains it through request cancellation. Cancellation marks authority invalid so normalization cannot proceed to another source or generation after the currently transmitted operation finishes.

The normalizer checks before/after every reference. Its request-local copied engine carries the captured check through public DNS, post-DNS/pre-open, each redirect iteration, and pre-body-read. The checked-address pinning, no-proxy opener, public-only destinations and tenant local/private-source denial are unchanged. Checks are application-operation boundaries, not atomic revocation/network transactions and cannot recall an already transmitted request.

RED evidence: `reference-admission-red.log` records five route-subcase assertion failures for pre-admission normalization. `reference-dns-red.log` records a synthetic HTTP open after revocation during DNS; that assertion passes after the engine callback change. Final `reference-test_reference_admission.log` reports **7 tests / OK**, covering route saturation, stale authority/global saturation, revocation/disable/rotation during normalization, cancellation with live read and slot retention, synchronous worker retention, and queued image/video last-slot transfer without double admission.

Final verification runs **17 separate scripts**, with exact interpreter/arguments/logs in `docs/verification-logs/reference-backend-results.json`. This includes the 26-test security review/proxy maintenance lifecycle suite, multitenant isolation, all three reference policy/media/limit suites plus hardening, proxy diagnostics/routing/receipts, concurrency, keepalive, session health, update safety, cookie/refusal, and media deletion. These are separate script results, not an aggregate test count. Reproduce each with:

```sh
MUSE2API_TEST_TMP=/Users/nhatngo/.hermes/cache/scratch \
TMPDIR=/Users/nhatngo/.hermes/cache/scratch PYTHONDONTWRITEBYTECODE=1 \
/Users/nhatngo/.hermes/cache/scratch/muse2api-update-20261114-171700/test-venv/bin/python \
  tests/run_backend_offline.py tests/test_reference_admission.py
```

Use `--offline` for `test_account_proxy.py` and `--backend-only` for `test_proxy_status_receipt.py`. No live requests, application startup, browser, private credentials, Flutter edits, installs, deployment, signing, commits or resets were used. One new queued-handoff test initially timed out because its fake Thread also intercepted first executor initialization; it now initializes the real executor before replacing only the worker-start phase. Existing FastAPI deprecation warnings remain. Parent independent acceptance is still required; this evidence does not establish live Muse compatibility.

## Environment-blocked verification

The following commands were run but cannot complete inside this managed sandbox:

- Full `flutter test`: Flutter's tester attempts to bind `127.0.0.1:0`; the sandbox returns `OS Error: Operation not permitted`. Log: `flutter-test-full.log`. Socket-free Dart tests above were run as real substitutes, not reported as the full suite.
- `flutter build macos --debug`: Xcode cannot access CoreSimulator/XPC services or create its temporary package-resolution file in the managed environment. Log: `flutter-build-macos-debug.log`.
- Local HTTP/SOCKS and Chromium fixtures likewise cannot bind localhost. Their non-socket portions passed; failures are recorded as environment restrictions, not test passes.

Real Muse generation, private credential probing, quota consumption, deployment/restart, OS save dialogs, codec playback, and device UI testing were intentionally not performed.
