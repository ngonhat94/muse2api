# Operational dashboard — bounded implementation handoff

## Delivered scope / acceptance pending

Added `GET /v1/operations` (authenticated own owner only) and `GET /admin/operations` (administrator-only aggregate), plus a manually refreshed operational section in the existing web console. No Flutter edits. Preserve the incumbent visual system; this is an operational extension, not a redesign. Independent parent review/verification is required; this is not completion of dashboard + idempotency together.

The snapshot contains only local persisted task counts (queued, processing mapped to running, failed, completed, cancelled, unknown), oldest queued age, and actual owned media usage/limits. Queue age is not predicted wait; `wait_estimate_seconds` is explicitly null. Historical/persisted tasks can include interrupted work; counts are **not proof of a live upstream worker**, account health or Muse credit. Unknown status is counted separately. Missing storage accounting returns null, not zero or guessed availability. Snapshots are point-in-time, not an atomic cross-owner filesystem transaction.

Administrator aggregation uses stored user IDs plus implicit admin, never labels, tasks, prompts, errors, account IDs, Cookies, raw credentials, media names, filesystem paths or capability URLs. Deleted/orphan owners absent from the user store are not auto-adopted or included. Data-filesystem free/total bytes are informational, not a storage quota or whole-machine inventory. `temporary_bytes` is explicitly null: this implementation does not recursively scan browser profiles/downloads/temp trees or claim those paths are bounded. Storage unknown-file quarantine behavior is unchanged.

Manual refresh makes GET requests only; no new timers, upstream probes, Muse calls or browser startup. Admin aggregate is fetched only for a known administrator. Results and errors render via textContent, generic failure copy does not echo exception bodies, and sequence + captured credential/owner guards discard late results. Credential replacement/401 clears rendered operational data immediately. The whole existing console still has pre-existing independent polling/version behavior; no claim it was made globally manual-refresh-only.

## Source-only safety copy

Before changes: `/Users/nhatngo/.hermes/cache/scratch/muse-dashboard-source-20261115-150503/source.zip` and `manifest.json`. 70 allowlisted root/backend/tests/tools/docs source files, every SHA-256 verified, directory 0700 and files 0600. No runtime `data`, .env, private key, Cookie store, profiles, generated assets or logs selected. It is a bounded source safety copy, not a production backup or full Flutter/Git snapshot; scratch expiry applies.

## Actual offline verification

Run from repository root:

```
MUSE2API_TEST_TMP=/Users/nhatngo/.hermes/cache/scratch \
TMPDIR=/Users/nhatngo/.hermes/cache/scratch PYTHONDONTWRITEBYTECODE=1 \
/Users/nhatngo/.hermes/cache/scratch/muse2api-update-20261114-171700/test-venv/bin/python \
 tests/run_backend_offline.py tests/test_operational_dashboard.py
node tests/test_operations_web.cjs
node tests/test_limits_web.cjs
node tests/test_storage_web.cjs
git diff --check
```

- `dashboard-red.log`: expected assertion 404 versus 200 before endpoint implementation; corresponding `dashboard-green.log` passes.
- `dashboard-disk-red-assertion.log`: expected missing disk field assertion before implementation; corresponding `dashboard-disk-green.log` passes. Earlier `dashboard-disk-red.log` is KeyError, not valid assertion RED.
- `dashboard-web-red.log`: expected missing dashboard assertion before markup/functions; `dashboard-web-green.log` passes.
- Final `dashboard-final.log`: **3 unittest cases pass**. The added revocation/unknown-status case characterizes existing shared guards, not a separately observed RED cycle.
- `dashboard-results.json` records **15 isolated backend scripts**, all exit 0: dashboard, data protection, protection review fixes, media boundary, tenant review blockers, multitenant security, reference admission, async images, concurrency, media delete, account proxy routing, reference media hardening, operations, local update safety, session health. At that batch dashboard had 2 cases; final 3-case rerun supersedes it. Separate scripts retain their own totals; these are not one combined unittest count.
- Node dashboard, limits and storage checks pass; all inline web JavaScript passes `node --check`; `git diff --check` passes.
- Local code-only graph refresh and no-label clustering both exit 0; retained `dashboard-graph-extract.log` / `dashboard-graph-cluster.log`. No semantic extraction or model/network call requested.
- Strict runner denies socket connect/bind, DNS, requests, subprocess and engine startup/generation before app import. Only synthetic isolated HOME is used. No live server, browser or Muse call was exercised.
- Design detector executed once over incumbent `admin.html`; exit 2, output `dashboard-design-detect.log` includes existing whole-page contrast/other findings. Not a clean UI audit. No rendered visual/viewport test was run because this delegated scope prohibits browser launch/OS automation; no claim of visually verified responsiveness. Existing theme and layout are preserved. No Flutter builds required because Flutter was not edited.

## Idempotency audit — deliberately not implemented in this bounded slice

Existing `_queue_image` has a partial task-record-based optional key hash; do not represent it as the requested durable idempotency contract. It hashes after reference normalization (can repeat reference work), is coupled to deletable task history, has no explicit retention/cap/unknown-admission ledger, and the video aliases have no corresponding key contract. Middleware charges generation-rate admission before lookup, so bolting video lookup onto endpoints alone would still double-count retries. A crash between task creation and key metadata write leaves an unsafe admission gap. References containing capability URLs and canonical operation aliases need careful pre-normalization request binding, without storing plaintext private payloads. Existing upstream retry behavior must be audited separately; request deduplication alone cannot promise never resubmitting upstream after ambiguous outcomes.

Next bounded implementation should first TDD an encrypted minimal durable admission ledger, scoped to owner + canonical async image/video operation (and authority policy), request hash and key hash; publish reservation before executor/reference work, link task once, preserve unknown outcomes fail-closed across restart, and never reuse expired unknown keys silently. Then integrate dedup before generation quota, reservation and reference work, preserving auth/revocation first and general request budget. Test concurrent same key, different-payload 409, normalized video aliases, restart/deletion/unknown outcomes, rotation/revocation, capacity/TTL, disk/write/thread-start failures and no double quota/reservation/upstream calls. Explicitly reject unsupported idempotency headers on sync image/edit/chat/responses until covered. Flutter key lifecycle and manual uncertain retry must be a later verified native slice, not a new auto-POST retry mechanism. No idempotency backend/client code was changed here.

## Synthetic two-user acceptance fixture / actual Muse test checklist

`tests/test_operational_dashboard.py` prepares two synthetic owners, owned queued/running/failed tasks and media under deny-network guards; it checks own counts, cross-owner exclusion, admin role denial, invalid/revoked credentials, administrator aggregate, safe storage failure and unknown status. This is synthetic ASGI acceptance, **not real two-user Muse E2E**.

For a separately approved actual E2E: obtain two independently provisioned user credentials and distinct real Muse pools without sharing secrets in logs; confirm TLS/log redaction, matching key escrow and protected backup; record initial owned queue/media/quota; intentionally submit once per owner, record task IDs, GET-poll only; compare each owner's dashboard/library/tasks and administrator aggregate; attempt cross-owner GET/cancel/media access; revoke one credential and confirm denial without affecting the other. Review actual Muse quota consumption and interrupted outcomes. Do not run uncertain POST retries until the durable idempotency slice is independently accepted. No actual Muse E2E, production migration/deletion, startup, deployment, install, signing, commit, push, reset or clean occurred.
