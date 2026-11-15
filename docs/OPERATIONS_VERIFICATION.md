# Offline operational preflight and protected recovery

## Handoff / acceptance

Backend-only addition: `operations.py`, `tools/operations.py`, `tests/test_operations.py`. Parent independent review/verification is required before deployment. No existing backend/frontend source changed. No production/private accounts/key contents were inspected, no production backup/migration/startup/restore/deletion, real Muse request, browser launch, quota consumption, signing change, global install, reset, clean or commit was performed.

Source-only safety copy before edits: `/Users/nhatngo/.hermes/cache/scratch/muse2api-operations-source-20261115-144431/source.zip` and `manifest.json`: 67 allowlisted backend/tools/tests/docs source files, per-member SHA-256 verified, containing directory 0700/files 0600. No runtime data, `.env`, account/key files, logs or profiles were selected. It is a bounded source snapshot, not a complete Git/Flutter backup or durable production backup. Scratch expires; retain approved source outside scratch before deployment.

## Operator commands

Run from repository root in the backend dependency environment. Inject secrets through your approved secret manager; **never put key values on command lines or in chat/logs**. Configure exactly one `MUSE2API_COOKIE_KEY` or `MUSE2API_COOKIE_KEY_FILE`; file must be a single-link regular owner-only file outside data, with no symlink components. No key generation is performed by tooling.

```
python tools/operations.py preflight /absolute/selected/data --json
python tools/operations.py preflight /absolute/selected/data --inspect-accounts --min-free-bytes 2147483648
python tools/operations.py backup /absolute/selected/data /private/backups/snapshot.enc --include-media --json
# Above is preview only: no source read or output write. Stop traffic and runtime first:
python tools/operations.py backup /absolute/selected/data /private/backups/snapshot.enc --include-media --apply --json
python tools/operations.py verify /private/backups/snapshot.enc --json
python tools/operations.py restore /private/backups/snapshot.enc /private/recovery/new-data --json
# Review authenticated preview, then publish into a NEW isolated destination only:
python tools/operations.py restore /private/backups/snapshot.enc /private/recovery/new-data --apply --json
```

Preflight exit codes: 0 no warning/block, 1 warnings, 2 blocked (CLI usage errors also 2). It always warns about unverified deployment conditions, so a successful current check normally returns 1, not 0. The command never loads `.env` or imports app/config/Store. Default accounts check deliberately does **not** read account data; explicit `--inspect-accounts` reads/authenticates ciphertext or reports legacy migration required, without revealing values. Other checks: owner-only existing data directory/no symlink components, existing safe runtime sentinel lock availability (noncreating), positive disk policy (default 1 GiB, explicit nonnegative byte override), selected dependency presence, admin-key presence and environment worker count. Key validation reads only the configured external key. Presence is not entropy/security audit, dependency presence is not version compatibility, lock/disk availability is point-in-time, and CLI launch flags/replicas/browser/OS quota/proxy/TLS/upstream session validity require operator verification. No migration, provisioning, cleanup or service startup occurs.

## Snapshot contract / consistency

Select the data directory explicitly; no default production path. Backup reads only required `accounts.json` (already encrypted), `users.json`, `tasks.json`, `media-index.json`, and `media-index.json.ownership-migrated` (must equal `1\n`), plus `media/` only with `--include-media`. All required metadata must exist; incomplete/legacy data fails closed. Runtime `.tenant-runtime.lock` must already exist: tooling refuses to create/delete it. Stop traffic, stop runtime gracefully, and stop other tools/writers first. Backup holds that exact existing runtime lock through reading and publication; busy/missing/unsafe locks refuse. Descriptor-relative nofollow source reads stay anchored if the directory pathname is replaced. Noncooperating local writers can still mutate individual regular files: offline operator exclusivity and filesystem access control are prerequisites, not a filesystem snapshot guarantee.

The output is **not ZIP or TAR**: it is a Fernet-authenticated encrypted JSON snapshot containing an encrypted manifest with schema, include-media flag, explicit per-file path, decoded byte size, SHA-256 and base64 data. The outer envelope encrypts user/task metadata and media too; account envelope bytes are preserved exactly, never decrypted/re-encrypted on disk. The same externally configured matching account key authenticates both layers; the key itself is never added. No arbitrary paths, `.env`, logs, browser profiles, downloads, master key, code or executables are accepted. Unrecognized fields, duplicate JSON keys/member paths, traversal/absolute/nested media paths, links, unknown/missing owners, unindexed/missing media, bad hashes and malformed records refuse. ZIP/TAR/link/compression inputs are never extracted. Limits: 10,000 payload files and 64 MiB decoded total; encrypted input capped at 128 MiB before decryption. This bounded in-memory format is intentionally unsuitable for larger installations; do not raise limits casually or claim streaming backup. It checks ownership references to stored users plus implicit `admin`; deleted-user orphan records require operator reconciliation, never silent reassignment.

Output parent must already be owner-only, owned by current UID, without symlink components, and outside selected data. Snapshot encrypted temporary bytes use 0600; publication uses atomic no-clobber hard-link, then parent fsync, removing only the private temporary name. Existing snapshots are never overwritten. Keep approved encrypted backups outside scratch with expiry/tenant deletion tracking, e.g. 7 daily plus 4 weekly according to your policy. No scheduler is installed.

**Metadata-only mode:** without `--include-media`, media ownership index remains intact but blobs are omitted. Restore reports `include_media:false`; this is NOT a ready-to-run full recovery with referenced assets. Reconcile/restore the matching separate media snapshot offline before runtime use. For a full restore drill use `--include-media`.

## Verification and isolated restore

`verify` decrypts/authenticates in memory and checks the complete manifest/ownership graph without writing/extracting. Missing/wrong key, corruption, unsupported schema/paths/type fields or size violations fail closed. Restore does the same checks first, then preview by default. `--apply` writes owner-only files into an unpredictable 0700 private staging directory, fsyncs files/directories, publishes atomically with OS no-replace semantics (macOS `renameatx_np(RENAME_EXCL)` / Linux `renameat2(RENAME_NOREPLACE)`), and cleans only its private staging directory on prepublication failure. Unsupported platforms fail closed. Existing or concurrently created destinations survive untouched. It creates a fresh runtime lock sentinel only **inside the new isolated restored directory**, never in production. No key is restored. Destination is selected **data-directory contents**, not a complete server HOME; do not point it at the current live service or automatically switch configuration.

Post-publication parent-fsync failure can leave a visible new archive/destination with uncertain durability. Error output explicitly advises inspecting output before retry; do not assume any failure means nothing was published. These are synthetic failure/race tests, **not physical power-loss/crash certification**. Same-UID hostile staging writers, inode-level tampering, backup access policy, key escrow, disk durability and crash recovery are not certified.

Recovery drill: escrow the matching external key separately under independently tested access controls; create full offline snapshot, verify it, restore to an unused isolated path, run explicit inspect preflight there, independently check owner/media/task consistency, and only then approve any deployment switch. No real Muse validation is implied. If key is lost, no recovery bypass exists. Old snapshots require their matching historical key: retain escrow until all associated snapshots expire. Rotation is **not implemented by this tool**: never replace the key and assume existing ciphertext/snapshots will work, never delete the ownership marker, never rerun implicit migration or roll back to plaintext-only source. Plan explicit backed-up offline re-encryption separately.

## Executed offline checks

Exact reproducible per-script command (substitute SCRIPT from manifest):

```
MUSE2API_TEST_TMP=/Users/nhatngo/.hermes/cache/scratch \
TMPDIR=/Users/nhatngo/.hermes/cache/scratch PYTHONDONTWRITEBYTECODE=1 \
/Users/nhatngo/.hermes/cache/scratch/muse2api-update-20261114-171700/test-venv/bin/python \
 tests/run_backend_offline.py tests/test_operations.py
```

`docs/verification-logs/operations-results.json` and `operations-*.log` record 14 individually isolated scripts: operations, data protection, protection review fixes, media boundary, tenant blockers, multitenant security, reference admission, async images, concurrency, media delete, account proxy routing, reference-media hardening, local update safety and session health. They all exited 0. Final operations suite: **17 tests passed**, including an intentionally unmocked DNS/socket call proving the offline guard refuses before external IO. Data protection 17, protection review 14, media boundary 14, tenant blockers 26, reference admission 7, local update safety 2; session health 177 script checks. Script totals are separate, not one combined unittest count. Existing FastAPI lifecycle deprecation warnings remain. Socket-bind/Node-subprocess tests excluded by the deny-network runner are not claimed verified here.

TDD evidence: observed assertion RED then GREEN for read-only preflight, round-trip snapshot tracer, source-directory replacement, CLI output/preview, key-file parent-symlink validation and missing administrator config. Initial missing-module/interface runs were errors, not valid assertion RED. Additional dangerous-manifest, missing/wrong key, corruption, symlink/hardlink, disk/size/permission, runtime-busy, unknown owner/media, cleanup and competing-destination tests characterize the shared validated implementation; they were not each independently RED. Do not characterize the entire security matrix as independent strict TDD cycles. Exact source compile and `git diff --check` also executed; CLI `--help` exercised directly without private data.

Remaining roadmap: actual approved two-user Muse E2E (may consume quota), dashboard/health UX, idempotency; no claims those are complete. No Flutter edits/build needed for this bounded backend/tools/docs slice. Parent must independently review current tree before the user completion phrase/deployment acceptance.
