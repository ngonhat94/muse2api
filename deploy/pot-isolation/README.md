# Optional UID10001 and PO Token network isolation bundle

Review-only infrastructure for PR #20's opt-in broker. It is **not** used by `deploy/instabox_release.py` and is never automatically enabled on production. No migration, production file ownership change, SSH access, attestation or real video download is performed by CI. The original backend Dockerfile/rollout behavior is retained.

## Images and trust boundaries

- `Dockerfile.api` repackages an explicitly supplied reviewed backend image for UID/GID **10001:10001**, HOME `/runtime` and profile path `/runtime/profiles`. It makes packaged `/app` code readable at build time only, creates fresh writable directory metadata and disables Python bytecode writes. It never copies mounted runtime data. A build without `MUSE_BACKEND_IMAGE` deliberately fails against scratch; there is no fallback to a floating public application image. Production builds must select immutable image references.
- `deploy/pot-provider/Dockerfile` also uses UID/GID **10001:10001** and owns its private copied source files accordingly. The provider refuses any other runtime UID/GID. No cookies/profiles/API data/environment or Docker socket are mounted there.
- `Dockerfile.guard` uses a digest-pinned Python base and is a small trusted root process with **NET_ADMIN only in its own dedicated network namespace**. It contains Python/nft/iproute, not provider code or application state. Provider shares this namespace with **all capabilities dropped**, read-only filesystem, bounded tmpfs/memory/CPU/PIDs and no-new-privileges. It has no public port or HTTP listener.

The guard installs one `inet muse_pot_guard` table atomically in its namespace, never flushes rulesets or edits host/Docker chains. Its health check compares a private root-owned proof against the **current namespace inode, validated policy digest and live nft rules fingerprint**; rule counters/handles do not invalidate a healthy policy. An invalid config, missing NET_ADMIN, missing/changed rule or stale proof is not healthy. Compose starts provider only after guard health passes. Reinstall of the same table is atomic. The guard does not dynamically reload config; recreate the review project when policy changes.

Docker may attach the guard's dedicated bridge before policy initialization, but the guard runs only trusted local firewall code; provider cannot start until policy installation/verification. No untrusted mint code runs in the unfiltered initialization window. The guard has no mint endpoint or access to the IPC socket. Restart policies are **no**, not always/unless-stopped. On recreate/reboot, recreate guard and provider together with Compose so provider cannot reuse a new unverified namespace; never independently start provider by bypassing dependency ordering. If guard exits, existing nft rules stay in the provider-held namespace. Docker health alone does not terminate a running provider; removal of rules by a privileged host administrator is outside the unprivileged-provider threat model. Health revokes readiness on such tampering, but cannot promise atomic confinement against an administrator deleting the policy.

## Network policy

`policy.example.json` is a starting **example**, not a production-ready inventory. Populate `deny_host_v4` with the reviewed VPS/public ingress/NAT-reflection/provider-management/tenant IPv4 addresses and routed networks. Existing private Docker/VPS ranges are included as examples; their presence does not prove the public ingress inventory is complete. A nonempty inventory is mandatory and injection/unbounded or malformed networks are rejected.

`net_guard.py` generates the policy from typed IP addresses, never raw nft snippets:

1. Drop all IPv6, plus IPv4 loopback/unspecified/private/link-local/CGNAT/test/benchmark/multicast/reserved ranges and the known special metadata endpoint 168.63.129.16.
2. Drop the configured host/tenant destinations **before** any allow rule.
3. Allow UDP/TCP53 only to the reviewed public `resolver_v4` and IPv4 TCP443 to remaining public destinations. Drop everything else. Input permits established/related replies only. Output filtering runs at priority 0, after namespace DNAT, so a public TCP443 destination translated to a private address is still denied.

This is IP/port isolation, not a domain allowlist. Arbitrary remaining public IPv4 HTTPS, including potential tunnelling services, is within the allow policy. Provider cannot resolve to or reach private/host destinations merely by DNS rebinding because filtering applies to the final destination IP. DNS-over-HTTPS to an allowed public address is not blocked by this design. Stricter domain restrictions require a separately reviewed gateway. Bind a read-only `resolv.conf` containing the same approved resolver (example `nameserver 1.1.1.1`); no blanket localhost/Docker DNS exception exists. DNS resolver and host deny ranges must not overlap. Account for cloud perimeter rules separately.

The guard namespace is independent of whether Docker on the host uses iptables or nftables. Its NET_ADMIN must actually work: unsupported kernels/capability limitations fail health and keep the Compose provider dependency blocked. No host networking, privileged container, host PID namespace or NET_ADMIN on provider/API is allowed.

## New runtime and socket layout

Use **new** reviewed paths, not `/data/home/muse2api-production`:

```
<new-review-root>/runtime/          10001:10001 0700
<new-review-root>/runtime/.env     10001:10001 0600 (prepared separately)
<new-review-root>/runtime/data/    10001:10001 0700
<new-review-root>/runtime/profiles/10001:10001 0700
<new-review-root>/ipc/             10001:10001 0700
.../ipc/provider.sock             10001:10001 0600
```

The runtime mount is API-only. The IPC directory is RW in provider, RO in API. Unix socket connect works on the RO mount with matching permissions and SO_PEERCRED, verified in the offline image test. Other UIDs cannot traverse the directory. Same-UID processes are trusted; this does not isolate mutually untrusted processes sharing that UID. Docker userns mappings must be checked so both peers actually see the intended identity.

`prepare_layout.py --root <new-path>` prints a plan only. Explicit `--create` requires root, a nonexistent path with a root-owned non-group/world-writable parent and no symlink parents. It creates only a fresh tree and sets ownership there; it never copies credentials, creates keys, recursively changes ownership, deletes an existing tree or migrates state. If interrupted, inspect and clean its new incomplete tree manually; rerunning against an existing path refuses rather than overwriting.

The API entrypoint reads only metadata before starting the application: exact UID/GID, real directories 0700, real nonempty config file 0600 and ownership 10001. Missing/wrong/symlink runtime config is rejected. These checks do not validate the contents or prove that encryption keys/auth state match a prior service. A **separate approved migration** must snapshot/copy runtime configuration, encrypted data and profiles, preserve key material without displaying it, prepare ownership on the copy, and verify tenant/auth/revocation/quota/data compatibility. Do not mass-chown/chmod current production state or merely run its current root image with --user10001. `/root/muse2api-profiles` is not used by the new image.

Provider can recover only its own refused stale Unix socket with correct UID and 0600, checking inode before unlink. It refuses live sockets, regular files, symlinks, foreign owners, unexpected permissions, timeouts and racing path changes. No recursive IPC deletion occurs. Stale-socket cleanup never calls mint.

## Compose review configuration

`compose.yaml` requires explicit reviewed image references, new runtime/IPC paths, policy/resolver files, a non-overlapping bridge subnet and an unused **loopback-only review port**. Bind mounts use `create_host_path:false`: missing directories/files are errors, not silently root-created production paths. API `MUSE_POT_OPT_IN` defaults empty, keeping token generation disabled even when the bundle is prepared. No compose up or activation command is run by the build.

Compose reference validation can be done with `docker compose -f deploy/pot-isolation/compose.yaml config --quiet` after supplying **synthetic review paths/images**; it never starts containers. Do not use this file as a replacement for the production rollout. An eventual deployment needs a separately approved migration, image digests, UID/GID collision and userns review, complete host/public ingress inventory, resolver/route review, write-safe cutover/rollback and recreate/reboot checks. Only after these pass may a separately approved activation set the exact broker socket path. This PR adds no rollout integration and changes no production configuration.

## Offline verification

- Guarded unit tests validate policy fields/injection, live-proof/namespace matching, missing/wrong runtime metadata, fresh layout refusal, live/foreign/symlink/stale socket behavior and Compose's identity/capability/startup gates.
- `ci_pot_isolation.py` uses uniquely labelled, disposable Docker containers on an **internal** network with synthetic endpoints. Public-looking test addresses are assigned to those fixtures only; no external server is contacted. It checks TCP443 and TCP/UDP DNS positives, non-443/host/metadata/loopback/IPv6 negatives, nft counters, atomic reinstall, health revocation and no-NET_ADMIN failure. Test resources are deleted only after their ownership label is checked; the existing running service is never selected.
- `ci_pot_runtime.py` uses fresh labelled Docker volumes and network-none containers, a fixed synthetic API key and synthetic encryption material (never displayed), and a fake Unix socket server. It verifies UID10001 startup/auth/profile writes, read-only IPC connect/SO_PEERCRED and restart persistence. Chromium renders only `about:blank` with background networking disabled and a fresh synthetic profile. No provider server or mint generator is run.
- Existing packaged sidecar checks still replace mint before requests and forbid a generator subprocess. The real upstream wrapper is tested with mocks; no real PO Token or YouTube request is generated.

These tests do not prove real attestation/download success, production migration readiness, external network accessibility or automatic recovery on the user's actual VPS. Existing root production pipeline and service stay untouched.
