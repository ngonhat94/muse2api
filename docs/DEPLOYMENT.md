# Server deployment: explicit activation, no automatic initialization

Only a **push to main**, after the guarded Python/Node suites and real Docker
build succeed, transfers the exact built image over SSH and deploys it. PRs,
other branches and manual dispatch only test/build. No GHCR credentials needed.
Nothing here has been deployed remotely. Workflow edits must be reviewed and
published separately; do not blanket-add unrelated checkout changes.

## Required GitHub configuration

Choose the SSH transport explicitly in **Settings → Secrets and variables →
Actions → Variables**. `VPS_SSH_MODE` defaults to `key` when absent/empty; the only
other accepted value is `instabox-token`. Unknown values fail before SSH.

| Setting | Direct SSH (`key`, default) | InstaBox (`instabox-token`) |
| --- | --- | --- |
| Variable `VPS_SSH_MODE` | `key` or unset | **`instabox-token`** |
| Secret `VPS_HOST` | Direct SSH hostname | **`ssh.instabox.sh`** (use provider-issued endpoint) |
| Secret `VPS_PORT` | Direct SSH port | **`2222`** (match provider command) |
| Secret `VPS_USER` | Linux account, e.g. `user` | **Only the exact token before `@`**, not `i`, guest account, or full command |
| Secret `VPS_SSH_KEY` | Required private client key | Not required; ignored even if an old value remains |
| Secret `VPS_KNOWN_HOSTS` | Independently pinned direct SSH host | Independently pinned **gateway** identity for **`[ssh.instabox.sh]:2222`** |
| Variable `VPS_DEPLOY_PATH` | Explicit prepared path below | Same; SSH transport does not prepare the guest |

Never send the token/key in chat, put the token in Variables, or echo the SSH
command in CI. Create/copy tokens privately from the machine's dashboard
**Connect → SSH tokens → Create token**, or run `instabox ssh-token <machine>` on
your own trusted terminal. Preserve the issued token exactly. API-issued tokens
are documented as `ibssh_` plus 26 lowercase base32 characters; the deploy script
intentionally checks only safe SSH username syntax (1–256 ASCII letters, digits,
underscore, dot or hyphen, starting with a letter/digit/underscore), not an
invented fixed token encoding that could reject other issued token contracts.
Whitespace, `@`, shell metacharacters and leading option syntax fail closed.

The official [SSH guide](https://instabox.sh/docs/access/ssh) and
[token API](https://instabox.sh/docs/api-reference/connections/issue-an-ssh-token-for-a-plain-%60ssh%60-command-without-a-key.md)
document token-as-username access without an SSH key. Token mode uses BatchMode,
disables public-key/password/keyboard-interactive/GSSAPI/hostbased auth, and lets
the gateway accept SSH's initial `none` authentication request. It does not pass
`-i` or `IdentitiesOnly`. The token resides only in an owner-private temporary SSH
config, not SSH argv; SSH stderr redacts it and temporary files are removed on
exit. This is locally mock-tested, **not a live gateway authentication test**.
Tokens expire after **7 days by default**, configurable up to **30 days**, or
`--ttl never` (higher exposure). Renew `VPS_USER` before expiry, revoke leaked or
unused tokens; `instabox ssh-token --revoke <machine>` revokes all machine tokens.
API-key revocation/expiry can also invalidate tokens issued by that key.

### Pin the gateway, not the guest

`StrictHostKeyChecking=yes` remains mandatory in both modes. The gateway
terminates SSH: the guest's `/etc/ssh/ssh_host_*` keys are **wrong** here. The
trusted official CLI `instabox ssh <machine>` obtains a certificate and writes
its gateway **host CA** known_hosts line; `instabox ssh-config <machine>` prints
the matching client configuration. On your trusted authenticated computer,
inspect that configuration and the CLI-managed known_hosts file. Transfer only
the matching **public** gateway CA entry, for example
`@cert-authority [ssh.instabox.sh]:2222 <host CA public key>`, to
`VPS_KNOWN_HOSTS`, after checking its identity through the trusted provider
channel. Do not copy certificates, client keys or token-bearing configuration.
The guide does not publish a universal gateway fingerprint or promise a
dashboard fingerprint display; if the trusted CLI/provider cannot establish the
identity, stop and obtain confirmation from InstaBox support.

Alternatively, collect candidate gateway public keys **on your own terminal**:

```bash
umask 077
ssh-keyscan -p 2222 -t ed25519 ssh.instabox.sh > gateway-known-hosts.candidate
ssh-keygen -lf gateway-known-hosts.candidate -E sha256
```

These commands only collect **untrusted candidates**. Independently compare the
SHA256 gateway fingerprint with the **`hostKeyFingerprint`** returned in the
official token-issuance API response over authenticated HTTPS (the API documents
this as the SSH server's host-key fingerprint), or another authenticated
provider trust source/support, before saving the matching `[ssh.instabox.sh]:2222` line in
`VPS_KNOWN_HOSTS`. A host CA fingerprint and a raw host key fingerprint are
*different*: compare like with like, or use the verified CA entry instead.
Never trust `ssh-keyscan` alone, click through an unverified first-use prompt,
or disable checking to bypass an exit 255. No scan/connection is performed by
this implementation work. Direct SSH users instead verify the direct sshd
identity through their trusted VPS console/provider channel.

Saving settings alone does not publish local workflow/script changes. Review and
commit/push separately; rerunning an old workflow revision does not load local
fixes. No GitHub settings, tokens or remote state were changed by this work.

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
