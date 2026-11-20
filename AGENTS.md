# Custom Muse2API backend

- Upstream main remains the author's baseline; custom work goes through reviewed branches. Never push to the author's repository.
- Flutter client is maintained separately: https://github.com/ngonhat94/muse_app. No Flutter source is bundled here.
- Preserve tenant isolation, owner-bound media access, idempotency, quotas, revocation and encrypted key escrow. Do not relax server authorization for client convenience.
- Never commit/log API keys, cookies, private environment files or deployment credentials.
- CI/CD and deployment automation are explicitly deferred in this migration. Keep existing upstream Docker/runtime assets; do not add the old murouter pipeline.
- Use local Graphify index first for locating flows, then inspect actual source. Refresh with `graphify update . --no-cluster` and `graphify cluster-only . --no-label --no-viz`; graphify-out is local-only.
- For UI work load design-taste-frontend, impeccable and ui-ux-pro-max. This migration preserves existing admin UI, not a redesign.
- Run synthetic, isolated regressions; never test against real users or Muse credentials. Report browser/native verification limits honestly.
- Historical verification documents describe original revisions, not guarantees about current HEAD. Consult docs/CUSTOM_MIGRATION.md for migration scope.
