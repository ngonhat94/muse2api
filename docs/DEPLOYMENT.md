# Server deployment: explicit activation, no automatic initialization

Only a **push to main**, after the guarded Python/Node suites and real Docker
build succeed, transfers the exact built image over SSH and deploys it. PRs,
other branches and manual dispatch only test/build. No GHCR credentials needed.
Nothing here has been deployed remotely. Workflow edits must be reviewed and
published separately; do not blanket-add unrelated checkout changes.

## Required GitHub configuration

Repository secrets: `VPS_HOST`, `VPS_PORT`, `VPS_USER` (`user`), `VPS_SSH_KEY`,
and **`VPS_KNOWN_HOSTS`**. The last secret is additional to the four already
reported populated. Obtain the host public key/fingerprint using a trusted VPS
console or provider channel. Compare the fingerprint out of band before saving
a known_hosts line (`[host]:port` for nonstandard ports). `ssh-keyscan` output
alone is not trust. The workflow never disables strict host verification.

Set repository variable **`VPS_DEPLOY_PATH`** only after preparation. There is
**no default**. Suggested opt-in path: `/data/home/muse2api-production`, separate
from the existing `/data/home/muse2api` checkout. Paths must be absolute,
non-symlink, ASCII letters/digits/underscore/hyphen/slash, no spaces/dots.
Debian 13 needs Docker Engine, Compose v2, Python 3 and an amd64 VPS (the current
GitHub Ubuntu build is amd64). The dedicated deployment account requires Docker
access, effectively root-equivalent: protect its SSH key/repository main branch.
Use an authorized_keys restriction such as `restrict` (no forwarding/PTY);
do not enable shell tracing or print Docker inspect/config/env/logs to CI.

## Existing upstream installation / authorized replacement

The reported old repo is `/data/home/muse2api`, with modified
`deploy/nginx.example.conf`, container `muse2api`, image `muse2api:latest`, public
18610, plus n8n/cloudflared. This automation **does not edit that repo, nginx,
n8n, cloudflared, old mounts or old credentials**. It refuses a deployment root
containing `.git` or `docker-compose.yml`. It detects even a stopped old
`muse2api` container and refuses takeover absent an owner-only
`LEGACY_CUTOVER_APPROVED` file containing its exact full container ID.

The user authorized replacement and considers old data unimportant. Still do
not initialize new state over old state: use the isolated path below. If retaining
accounts is later desired, stop and plan an explicit offline authenticated
migration instead; old encrypted stores/keys must match. No migration runs here.
Before cutover, record old mount paths, restart policy and proxy topology privately.
A complete offline backup would include all mounted data, ledger+markers,
authority+markers, profiles and matching keys/config; the old operations backup
alone is **not** a complete recovery backup. No backup has been taken by this work.

## Manual bootstrap on VPS — isolated new state only

These are operator instructions, **not normal deployment steps**. They do not
start the production app. Select a reviewed image built from this checkout and
loaded on the VPS by a trusted operator (`IMAGE` below is its sha256 image ID).
Do not use the old upstream `muse2api:latest` image. Verify its revision privately.
Do not paste generated secrets into chat or GitHub logs. Run as the deployment
account; never run with `set -x`. First check the selected path does not exist:

```bash
set -eu
umask 077
ROOT=/data/home/muse2api-production  # choose/confirm; NOT the old repo
# IMAGE=sha256:... # reviewed new image ID; set explicitly before proceeding
: "${IMAGE:?set reviewed immutable new image ID}"
test ! -e "$ROOT"
mkdir -m 700 "$ROOT"
mkdir -m 700 "$ROOT/data" "$ROOT/profiles" "$ROOT/config" "$ROOT/incoming"
# Network disabled, one-shot library calls only, no server/browser startup.
docker run --rm -i --network none --user "$(id -u):$(id -g)" \
  --mount "type=bind,src=$ROOT/config,dst=/bootstrap" \
  --mount "type=bind,src=$ROOT/data,dst=/bootstrap/data" \
  --env MUSE2API_HOME=/bootstrap --entrypoint python "$IMAGE" - <<'PY'
import base64, os, secrets
from pathlib import Path
os.umask(0o077)
base = Path('/bootstrap')
# Exclusive create: never replace existing credentials.
with (base / '.env').open('x') as output:
    output.write('MUSE2API_KEY=' + secrets.token_urlsafe(48) + '\n')
    output.write('MUSE2API_COOKIE_KEY=' + base64.urlsafe_b64encode(os.urandom(32)).decode() + '\n')
    output.write('MUSE2API_PUBLIC_BASE=https://muse.dntrip.xyz\n')
from config import CFG
from authority import AdminAuthority
from idempotency import GenerationLedger
AdminAuthority(str(base / 'data/admin-authority.json'), CFG.api_key)
GenerationLedger(str(base / 'data/generation-ledger.json'), initialize=True)
PY
# Approval for this prepared isolated state, NOT a bootstrap flag for normal runs:
printf '%s\n' muse2api-storage-v1 > "$ROOT/DEPLOY_READY"
# Only when authorizing this specific legacy container's replacement:
docker inspect --format '{{.Id}}' muse2api > "$ROOT/LEGACY_CUTOVER_APPROVED"
chmod 600 "$ROOT/DEPLOY_READY" "$ROOT/LEGACY_CUTOVER_APPROVED"
```

If bootstrap fails, leave it stopped and investigate privately; never silently
retry initialization or delete markers. The isolated new deployment starts empty:
old accounts/cookies are not copied, old files remain untouched. Access the new
admin key only via a private operator session/password manager.

At deploy time, after image/approval checks, the script disables the old
container's restart policy and stops it by the approved ID **without removing it
or its mounts**. It then stops the managed runtime before starting exactly one
new replica/uvicorn worker. Old-container recovery is manual; do not run both.
The approval remains tied to the old ID; a changed old container fails closed.

## Proxy and verification

The new service binds **127.0.0.1:18610 only**; no CDP port is published. Persistent
data is mounted at `/app/data` and `/app/runtime/data` (same directory);
`MUSE2API_HOME=/app/runtime`, config directory `/app/runtime` permits atomic admin
key rotation, profiles `/app/profiles`. UID/GID match the deployment account;
owner-only files and `umask 077`, no-new-privileges. Normal deploy requires existing
ledger/authority plus markers and explicit credentials and sets ledger init=0.

Manually arrange HTTPS `muse.dntrip.xyz` reverse proxy to 127.0.0.1:18610, Cloudflare
Full (strict) and a valid origin certificate as appropriate. If cloudflared runs
inside Docker, its 127.0.0.1 is **not the host**; current Docker-network routing
will not automatically reach this loopback-only service. Confirm/plan a host-side
proxy or reviewed routing change before cutover. This work does not change tunnel,
DNS, TLS or nginx configuration. Port reachability/HTTPS remain unverified.

A VPS file lock plus noncancelable Actions event/ref concurrency serializes main
push deployments. Do not cancel an active deploy; timeout/transport interruption
needs operator inspection. Health checks use container-local `/healthz`, expected
image ID, OCI revision and `/app/version.json`, 30 attempts with 2-second delays;
per-command timeouts are finite. Health is not readiness/account/Muse validation.
No credentials/server stderr/config are printed. Failed health stops the new
runtime. Automatic image-only rollback requires owner-only `ROLLBACK_COMPATIBLE`
containing `muse2api-storage-v1` AND the prior image's matching storage-contract
label. Create that approval only after reviewing actual schema compatibility;
labels alone cannot prove it. Failure remains a failed CI run even after recovery.
No ledger snapshot restoration, cleanup, pruning, migration or key generation is
performed by deploy. Legacy rollback is always manual (stop new first, then
restore old restart policy/start if explicitly approved).

Uploaded revision directories/images are retained, not pruned. A retry of the same
SHA refuses an existing upload directory; inspect interrupted state privately
and prepare a new reviewed commit rather than deleting production files blindly.
No frontend job/build/signing is enabled.
