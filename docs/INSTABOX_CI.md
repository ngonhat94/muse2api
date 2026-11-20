# Backend CI and Instabox release

This automation supersedes the migration's CI/CD deferral without importing the retired pipeline. `main` remains upstream tracking; PRs target `master`. No merge or production rollout is performed by setting up a PR.

## Gates and trust boundary

`test` runs the existing guarded synthetic backend manifest (45 scripts), all eight offline JS scripts, and release safety tests. No Muse cookies or live users are used. `build` builds the actual Dockerfile and tests custom module imports, unauthenticated rejection, synthetic authenticated access, revision identity, persistent state/keys, replacement and failed-candidate rollback. It does not prove native desktop packaging, real Muse/browser generation, or production account readiness.

All jobs use GitHub-hosted `ubuntu-latest` runners. Instabox is only the persistent backend runtime, so CI does not consume an additional Instabox sandbox slot. Enable GitHub Settings → Actions → General → **Require approval for all external contributors** for public external-fork PRs. This setup does not alter that policy.

Only a push to `master` may export the tested image and enter `production`. The Environment permits `master` only. There is no manual dispatch or PR deployment bypass. Workflow and host locks serialize releases; in-progress releases are not cancelled.

## Approved runtime

- Machine: `m_agq7oogrt4nfem7wmwfcgpvanm` (`muse2api-backend-v2`). Never create or select another runtime implicitly.
- Environment Variables: `INSTABOX_MACHINE_ID`, `DEPLOY_PATH=/data/home/muse2api-production`, `CONTAINER_NAME=muse2api-production`, `PUBLIC_URL` from `instabox port publish ... 18610`.
- Environment Secret: `INSTABOX_API_KEY` (never a repository plaintext file).
- Persistent host directories: `data`, `config`, `profiles`. `config/.env` is generated owner-only on the runtime, contains stable independent admin/encryption keys, and is never emitted. Administrative key rotation updates the mounted config directory atomically.
- Admin key retrieval, if needed, must use an operator's protected terminal on the runtime, never Actions logs or chat.

Free runtime policy currently allows 120-minute runs, a 30-minute idle auto-pause and possible cooldowns. This is **not a 24/7 hosting guarantee**. CI runs on GitHub and does not require another Instabox machine; do not delete the runtime for CI.

## Release/rollback/retention

Actions transfers a compressed Docker image using Instabox API `cp`, then runs `deploy/instabox_release.py` through API `exec`. It never sends SSH archives. Runtime image import validates service ownership and the full revision. The prior container remains as `-rollback`; a failed candidate is removed, the prior container is restored and its health/revision checked. The release marker changes only after successful checks. First deployment has no prior version to restore.

The script deletes only the current invocation's upload on success or failure; Actions has an additional EXIT cleanup for failed upload/exec. It retains only current and previous service-owned image IDs after successful rollout, never globally prunes Docker, and never deletes persistent data/config/profiles. A failed rollout retains its labelled candidate image for diagnosis until a later successful release cleans it. Prior container rollback is not a data-schema backup; back up encrypted data **with its matching encryption key** before changes that migrate storage formats.

Liveness `/healthz` plus container/image revision checks gate rollout. An empty new service correctly reports `no_account` on authenticated `/readyz`; do not import real credentials merely to make CI green. Actions also checks the public health endpoint after rollout.

## Local verification

```sh
pip install -r tests/requirements-ci.txt
python tests/run_custom_regressions.py
for test in tests/*.mjs tests/*.cjs; do node "$test"; done
python -m unittest discover -s tests -p 'test_ci_*.py' -v
docker build --build-arg BUILD_SHA="$(git rev-parse HEAD)" -t muse2api-ci .
python tests/ci_image_smoke.py muse2api-ci "$(git rev-parse HEAD)"
```

Docker smoke uses only unique `ci-*` service labels and temporary synthetic directories; it does not touch the production container. Follow PR checks with `gh pr checks --watch` and verify GitHub job runner labels for the exact head SHA. `instabox ci` does not list these GitHub-hosted jobs; Instabox is used only by the deploy step after merge.
