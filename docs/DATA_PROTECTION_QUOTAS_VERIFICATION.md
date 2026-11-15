# Data protection and quota verification

## Status: implementation handoff, independent acceptance required

**Follow-up UX handoff:** `docs/STORAGE_QUOTA_UX_VERIFICATION.md` documents the subsequently added Flutter own-storage/manual-refresh surface and web administrator graphical five-limit controls with retention dry-run only. The historical UX gaps and 317-test baseline below describe the original backend handoff; the follow-up records 332 Flutter tests, analysis and both builds. Parent independent acceptance remains required.

Synthetic verification only. No production startup, data migration, production cleanup, deployment, secret provisioning/rotation, Muse calls, browser launch, quota consumption, signing change, global installation, reset, clean or commit was performed. Existing dirty tracked and untracked work is preserved. The cryptography dependency was installed only in the pre-existing scratch verification venv. This is **not yet full acceptance of the requested slice**: Flutter currently has safe 429/507 error UX but no storage-usage/limit management view; administrative limit controls are API-only; browser-temporary-download disk usage is not bounded by the persisted-media quota; parent independent security review remains required.

## Protected backup made before code changes

`/Users/nhatngo/.hermes/cache/scratch/muse2api-protection-backup-20261115-131501/source-data.zip`

1481 source/data/Git metadata files; every member SHA-256 verified against source bytes. Protected containing directory mode 0700, archive and manifest 0600. Dependency/build caches omitted. Private Cookie/key data was not printed. This backup may contain legacy plaintext secrets: retain with the same care as production credentials, outside public folders. The scratch location is not a durable operator backup: move to approved encrypted storage and set an expiry before deployment; do not rely on scratch retention. Never publish this archive or manifest.

## Cookie encryption and provisioning

`cryptography>=43` Fernet authenticated encryption protects the **whole account store**, including Cookies and proxy credentials. No custom crypto. New writes atomically replace mode-0600 ciphertext with fsync; no plaintext temporary serialization. Public account metadata excludes Cookie values and redacts known Cookie values and URLs in notes. No stored master key, plaintext fallback or automatic production-secret generation. Missing/invalid keys, invalid ciphertext, wrong keys, corrupt JSON and legacy plaintext fail closed before ownership migration.

Configure exactly one external secret source:

- `MUSE2API_COOKIE_KEY`: a Fernet key injected by your secret manager.
- `MUSE2API_COOKIE_KEY_FILE`: an externally provisioned key file, outside checkout/data, regular file owned by runtime UID, no group/other permission bits, no symlink.

Provision once using your organization's secret manager and `cryptography.fernet.Fernet.generate_key()` in a private environment. Do not paste keys into shell history, chat, logs, docs, `.env` committed to Git, or public output. No production key was generated here.

### Explicit offline legacy migration

1. Stop all runtime processes and stop traffic. Verify a protected source+data backup. Back up the externally provisioned matching key separately with restore access control.
2. With the secret injected, run `python tools/migrate_accounts.py /absolute/private/path/accounts.json --confirm-backup` in the backend environment. The tool imports no app/config, launches no browser and makes no network calls. It takes the same data-directory runtime lock and refuses a running service.
3. Migration validates legacy list records, encrypts, decrypt-verifies, fsyncs and atomically replaces; repeated runs authenticate existing ciphertext without rewriting. Pre-replace failure leaves legacy bytes unchanged and cleans its private temporary file. Restore matching backup/key if interrupted; never delete ownership markers or regenerate a key to bypass authentication errors.
4. Independently verify synthetic and operator restore procedures, permissions and all operational limits, then deploy under explicit operator approval. Do not roll back to a plaintext-only release against encrypted data.

The account encryption does not encrypt browser profiles, task prompts, generated media, old backups, Chromium logs or remote Muse data. OS full-disk encryption/access isolation is still necessary. A missing account file is treated as a new empty account store; an existing unreadable/corrupt store is not.

## Per-owner controls and defaults

No admin exemption: administrator persisted media and authenticated API requests use the same environment defaults. User overrides persist in `users.json` and survive restart.

| Setting | Default | Scope |
| --- | --- | --- |
| `MUSE2API_STORAGE_BYTES` | 2147483648 bytes | persisted generated media per owner |
| `MUSE2API_STORAGE_FILES` | 1000 | existing generated media files per owner |
| `MUSE2API_MEDIA_RETENTION_DAYS` | 30 | age eligibility, **not automatic deletion** |
| `MUSE2API_REQUESTS_PER_MINUTE` | 120 | sliding 60-second authenticated API budget per owner |
| `MUSE2API_GENERATIONS_PER_MINUTE` | 12 | additional POST image/video/chat/responses budget per owner |

Positive limits only; no implicit unlimited value. Existing 8-owner/64-global outstanding worker reservations are independent. Rate limits are process-local and reset on restart; one process/replica is mandatory. Static/health, OPTIONS and capability media delivery are exempt; raw API keys never identify rate buckets. Authentication/revocation runs before admission; rotation does not reset an owner's bucket. Media delivery needs separate reverse-proxy bandwidth/rate control.

- `GET /v1/storage`: own actual-byte/count usage and effective storage limits; accounting uncertainty returns safe 503.
- `GET /admin/users/{id}/storage`: administrator-only usage, including `admin`.
- `PATCH /admin/users/{id}/limits`: stored non-admin users only; targeting implicit `admin` explicitly returns 400 (configure environment defaults instead). No stored or graphical admin-target override is supported. Administrator-only bounded positive `storage_bytes`, `storage_files`, `retention_days`, `requests_per_minute`, `generations_per_minute`. This request is a complete limit configuration: omitted fields reset to schema defaults. Existing results are never deleted when limits are lowered.
- `POST /admin/users/{id}/retention`: administrator-only, `{}` is dry-run. Explicit `{"dry_run":false,"confirm_owner":"exact-owner-id"}` applies eligible owned deletions. Review preview and take a protected backup first. No such production request was executed.

Persisted output writes serialize accounting, byte/count checks, exclusive-create and ownership index publication under one lock. Quota applies to actual output bytes, not engine-reported size. Other owners cannot overwrite/reassign a filename; write/index failures clean only the privately created output. Accounting scans actual files on restart; missing/corrupt ownership indexes with existing blobs fail closed via unknown-file detection. Unindexed/symlink entries are logically quarantined, not moved/deleted. Empty-room admission checks before reference work prevent generation when already full; concurrent in-flight generations are not reserved for estimated output size: final actual-byte write decides, so an upstream operation may complete but output persistence may fail. Async tasks become failed, never automatically retry a POST. StorageQuotaExceeded bypasses account retry and yields 507 for synchronous delivery.

**Limits:** final media byte writes are bounded; browser downloads occur before final persistence and are not streaming-budgeted. The file-count quota does not cover task records, imports, profiles, temporary references, Chromium/browser downloads or filesystem metadata. Use OS/filesystem quotas and disk alarms. The existing engine page cleanup normally removes context download directories, but it is not a whole-disk guarantee. No automatic deletion of existing results on quota exhaustion.

Retention examines only indexed exact-owner regular media files. Unknown files remain inaccessible and listed for operator reconciliation; other owners' files are untouched. It does not delete task history, Cookie records, upstream assets or backup copies. Admin must separately approve account deletion and backup expiry; unlink is not physical secure erase. Recommended operator policy: daily encrypted data snapshots, separately escrowed key, 7 daily plus 4 weekly snapshots, restore drill before rollout, explicit tenant deletion tracking until every retained snapshot expires. This is documented policy, **not an installed backup scheduler**.

## Logging and UX

Application operational log messages are replaced with a fixed sensitive-details-omitted message; exception/stack payloads are removed. Uvicorn access records are suppressed before its positional-argument formatter can process sensitive URLs. A dedicated regression caught and repaired an initial formatter-argument mismatch. This intentionally sacrifices diagnostic detail. DOM debug dumps are disabled. Reverse proxy, third-party exceptions/process logs and external observability still require operator configuration: never record Authorization/Cookie headers, query strings, scoped media URLs or raw errors.

Web media library shows own disk bytes/files and retention eligibility separately from Muse balance; safe 429 copy respects bounded numeric Retry-After and warns against duplicate generation POST, safe 507 copy recommends owned-media deletion/admin help. Flutter safe Vietnamese 429/507 copy similarly does not expose raw server bodies or enable automatic POST retries. Flutter storage-usage display/admin forms are not implemented in this handoff. Existing polling recovery remains GET-only.

## Executed verification and evidence

Interpreter: `/Users/nhatngo/.hermes/cache/scratch/muse2api-update-20261114-171700/test-venv/bin/python`.

`tests/run_backend_offline.py` supplies a fresh synthetic HOME/data/profile/key and prohibits network/DNS, browser/engine startup and arbitrary subprocesses. Never invoke app startup against production data for verification. Example:

```
MUSE2API_TEST_TMP=/Users/nhatngo/.hermes/cache/scratch \
TMPDIR=/Users/nhatngo/.hermes/cache/scratch PYTHONDONTWRITEBYTECODE=1 \
/Users/nhatngo/.hermes/cache/scratch/muse2api-update-20261114-171700/test-venv/bin/python \
  tests/run_backend_offline.py tests/test_data_protection.py
```

Final `docs/verification-logs/protection-results.json` records **13 separate backend scripts**, all zero exit. New data protection suite **17 unittest tests**; existing review suite **26**; reference admission **7**; session-health **177 checks**; other scripts have their own independent totals (do not sum as one suite). Two separately executed desktop source-copy/build validation scripts pass **5** and **7** tests with no actual installation/build. Python in-memory compile, extracted admin JS `node --check`, `node tests/test_storage_web.cjs`, and `git diff --check` pass.

Strict red logs include encryption, migration atomicity, rate boundary, public metadata, logging, admin limits, HTTP storage/admission/retention, web error UX and Flutter errors. Early missing-interface probes (`storage-red`, `engine-red`, `retention-red`) are retained as errors rather than falsely described as assertion-based RED. Migration/rate tests used inert interfaces and then observed the intended assertions fail. This test-first evidence is partial relative to the full requested threat matrix; key-file symlink/ownership, durable fsync crash boundaries, end-to-end real generation persistence and full temporary-disk limits still require parent review/additional tests.

Flutter: `CI=true FLUTTER_SUPPRESS_ANALYTICS=true flutter analyze` -> **No issues**; full `flutter test` -> **317 passed**; standard `flutter build web` and `flutter build macos --debug` -> success. Existing secure-storage WebAssembly dry-run and macOS Swift Package Manager plugin warnings remain. First full test run exposed an old fixture expecting the former 429 wording; expectation updated to the new actionable rate-limit wording and full suite rerun successfully. No app UI/browser/manual rendering verification or live Muse integration was performed. Builds do not refresh an installed bundled Python engine, and desktop encrypted-key provisioning is still operator-owned.

Parent must independently review security boundaries and verify current exact tree before acceptance. No completion phrase or deployment approval is implied.

## Independent backend blocker repairs (synthetic follow-up)

Backend-only follow-up: `store.py`, `protection.py`, `tenant.py`, `engine.py`, `app.py`; new `tests/test_protection_review_fixes.py`; affected synthetic fixtures in `tests/test_async_images.py` and `tests/test_reference_media_hardening.py`. No admin HTML/Flutter edits in this follow-up.

- Media directory components are opened from root with directory descriptors and `O_NOFOLLOW`. Writes and retention unlink use the opened directory descriptor, not re-resolved media parent paths. Indexed media is opened `O_NOFOLLOW`, checked regular with `fstat`, then streamed from that same descriptor; a swapped leaf cannot redirect delivery. Streaming closes the handle on completion/disconnect. Synthetic parent symlinks, parent replacement after accounting/at unlink, and leaf replacement before/after response construction are covered.
- Browser fallback uses captured-owner effective limits (including overrides above environment defaults), throws typed `StorageQuotaExceeded`, and removes its temporary download on persistence failure. Actual owner accounting still occurs in the writer. A synchronous HTTP fixture with two available accounts asserts 507, one acquire and one generation attempt. Temporary browser disk remains outside the quota.
- Account loading opens the leaf `O_NOFOLLOW|O_NONBLOCK` and checks regular type. A dangling account symlink fails closed instead of creating an empty account store. Key-file nofollow/UID/mode checks are preserved and regression-tested.
- Runtime lock is acquired during module initialization before `Store`/`UserStore` initialization and ownership migration, not merely during ASGI startup. Failed initialization closes its acquired lock. Independent synthetic module imports with distinct data directories remain supported; two imports targeting the same locked directory intentionally fail closed. A busy-directory test verifies Store is never constructed.
- Atomic account/task/media/user-state replacement now fsyncs its parent directory; the ownership guard marker is fsynced with its parent before any ownership mutations. The marker means **migration attempted**, not transaction completed. If migration is interrupted after marker publication, restart never re-adopts unidentified assets: missing ownership remains quarantined and accounting denies generation. Operator must restore the matching protected state backup; do not delete marker to retry adoption. A directory-fsync failure after replace is an **uncertain durability** error: replacement may already be visible; do not blindly retry POST/mutation. Tests cover this visible-new-state boundary and interrupted migration before index publication. These are failure-injection tests, not actual power-loss filesystem certification.
- Implicit administrator limits are environment-managed and explicitly rejected by PATCH with 400; no graphical admin-target editing is claimed. Stored user overrides remain supported.

### Follow-up exact evidence

Same scratch interpreter and offline runner shown above. Final machine-readable manifest: `docs/verification-logs/protection-review-fixes-results.json`. All **13 scripts** in that manifest exited 0, individually isolated. Exact retained outputs: new review regression **14 tests**, data protection **17 tests**, tenant review blockers **26 tests**, reference admission **7 tests**, session health **177 checks**. Multitenant/security, async images, concurrency, media deletion, proxy routing, refusal rotation, reference-media hardening and local-update safety have their own script outputs; do not combine these with unittest totals. Final log names begin `protection-review-fixes-`.

Strict assertion-based RED/GREEN logs retained as `review-dangling-*`, `review-parent-*`, `review-leaf-*`, `review-lock-*`, `review-fsync-*`; `review-fallback-red.log` contains the genuine former above-default ValueError plus failed cleanup assertion, followed by passing GREEN. `review-admin-red.log` catches former 404 versus explicit 400; `review-user-fsync-red.log` catches missing user-state directory fsync. Additional crash/race and HTTP tests characterize and strengthen the repaired paths; they were not all independently RED before the shared fix and are not represented as separate TDD cycles.

Initial affected-suite failures were retained: async-image fixture omitted indexed ownership and exhausted the new default rate budget; fixed by synthetic ownership registration and explicit high test-only request limits. Reference-media fixture omitted the required owner writer; fixed by wiring a real synthetic Store. These do not weaken production controls. `test_account_proxy.py` socket-bind case and the Node subprocess segment of `test_proxy_status_receipt.py` remain **unverified under this strict runner**: it intentionally forbids sockets/subprocesses. Their captured `review-test_account_proxy.log` / `review-test_proxy_status_receipt.log` are failures, not passes. No guard was relaxed. Parent should independently run permitted local-only fixtures if required. Existing FastAPI on_event deprecation warnings remain. `git diff --check` passes.

Remaining limits: no live integration, production startup/migration, actual production deletion, network/DNS/browser, global install, desktop automation, signing or commits; no whole-disk temporary-download bound or graphical implicit-admin override. Parent independent acceptance/review of the exact concurrent tree remains required.

## Persisted-media consumer boundary follow-up (acceptance pending)

Backend-only edits: `app.py`, `store.py`, `engine.py`; new `tests/test_media_boundary.py`. No frontend changes. Base64 delivery ignores the engine result's `path`, checks filename ownership through registration, and reads all bytes from the same `Store.open_media` nofollow descriptor. Single/batch deletion and cancelled image/video worker cleanup use `Store.delete_media`; retention shares its lock-held, owner-checked `_delete_media_at` primitive. Parent directories are opened component-by-component without following symlinks; unlink is relative to that descriptor. A leaf swapped after stat can cause the substituted directory entry (including a symlink itself) to be unlinked, never its symlink target. This is not an inode-identity transaction against a hostile local filesystem writer.

The remaining persisted-media consumers were searched explicitly: capability streaming already uses `open_media`; library listing now uses `fstat` on that descriptor; public task capability refresh checks the descriptor rather than pathname `isfile`; initial legacy media adoption lists/stats the opened directory without following leaf symlinks; browser fallback reports the length of persisted bytes instead of reopening the output pathname for size. Engine result `path` remains internal metadata but no application media read/delete consumer uses it. Browser-download temporary inputs, administrator-enabled local reference inputs, profile files and operational logs are separate filesystem boundaries, not claimed protected by persisted-media ownership/quota. No new remote tenant symlink-creation primitive was demonstrated: symlink substitutions model a hostile local filesystem writer.

Strict RED evidence: `media-boundary-b64-red-assertions.log` catches outside bytes and parent/leaf following; `media-boundary-delete-list-red.log` catches outside deletions (FileNotFoundError reading the deleted synthetic sentinel), missing deletion checks, and metadata following; `media-boundary-audit-red.log` catches both cancelled worker deletions, unsafe adoption and task capability refresh; `media-boundary-result-size-red.log` catches outside size 22 versus expected 5. The earlier `media-boundary-b64-red.log` is a fixture authorization error, not valid assertion RED. Corresponding b64/delete-list/audit GREEN logs are retained. One initial protection-regression failure arose from migration creating a formerly absent media directory; fixed by not creating a directory during legacy scanning, with original behavior restored. Its output is retained as `media-boundary-protection-regression-initial.log`.

Latest completed offline run is recorded in `docs/verification-logs/media-boundary-results.json`: nine scripts exited 0, including boundary **13 tests**, protection review **14**, data protection **17**, tenant blockers **26**, reference admission **7**, plus multitenant security, async images, media deletion and reference-media hardening scripts. Existing FastAPI lifecycle deprecation warnings remain. `git diff --check` passed at that run. Since then, the test file gained one additional late leaf-substitution case and a removed unused binding; the resulting **14-test boundary file was subsequently executed independently by the parent and passed**, together with the 14-test protection-review suite and `git diff --check`. A separate read-only review accepted the repaired persisted-media boundary within the documented scope; no new concrete blocker was found. The child's final rerun was initially approval-gated; the subsequent parent execution and independent source review above supersede that pending status. No production startup/deletion, live/private data access, network/DNS/browser, installs, signing, commits or desktop automation occurred.

