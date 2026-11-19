# Revoked-key views and rollout

The Flutter administrator page uses `key_active` independently of `enabled` and
`key_revealable`. Disabled and hash-only keys are not revoked. A server that omits
`key_active` cannot classify historical revocations safely: keep those rows and
show an explicit backend-update notice, rather than claiming their key still exists.
The HTML `/admin` console now offers the same active/revoked views. Reissue uses
rotation on the existing tenant ID; neither surface deletes tenant data.

## Investigated report

- The screenshot's Vietnamese strings match Flutter `AdminUsersPage`, not the
  Chinese HTML console. Its small crop cannot establish whether filters exist.
- PR #18 was merged as `62af51d118b66aa5354b336f8f18f07422a7b36f`.
- GitHub's Cloudflare Pages check reports that revision deployed at
  `https://4deaad20.muapp-3d6.pages.dev`. Browser readback loads Muse Studio and
  `main.dart.js` containing `key_active`. The user's exact viewing URL was not
  supplied, so that does not prove their tab runs this revision.
- That revision's server CI passed offline Python, upstream synthetic tests,
  JavaScript tests and image build, but **failed the SSH deployment step**.
  A frontend deployment is not a backend rollout.
- The local running `muse2api` container belongs to the separate
  `/root/mycode/muse2api` Compose project, not this repository. Its immutable
  `/app` code has no `tenant.py` and no `key_active` in app/store. It must not be
  restarted or overwritten as part of a frontend patch.

## Release verification

Merge/release only through the authorized deployment process. Repair the failed
backend rollout separately; do not bypass the deployment guard. On the exact
user-facing URL, verify the deployed revision and use an authorized administrator
session to inspect `/admin/users`: explicit boolean `key_active` must be present.
Only then test a disposable tenant's revoke/reload/reissue flow against an isolated
backend. Verify owner-linked data remains on the same ID. Do not declare the live
report fixed from a successful preview or synthetic fixture.
