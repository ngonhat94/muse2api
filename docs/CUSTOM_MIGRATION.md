# Custom backend migration

## Provenance

Target baseline: upstream v1.6.12, f7f5be5fce4d4e3a4f7240a09ac95c02ed60ff46.
Custom source: ngonhat94/murouter main cb00d87a699590957dd4b78b26d08700f17a014c.
Common ancestor: 19db32a3d6ef50dc87567a8ee0e35dd50c8f7837.

Three-way integration preserves upstream history and the custom source ancestry. No writes to the author's repository. Main remains unchanged until PR review/merge. Historical commits contain the original monorepo/pipeline; those files are deliberately absent from the resulting migration tree. Old repositories and local-only changes remain untouched.

## Included

- Tenant/user ownership, authentication, CORS and shared client configuration.
- Key revocation, same-user reissue and encrypted key reveal; historical hash-only keys remain unrecoverable.
- Owner-bound media capabilities, data protection, storage quotas and guarded reference-image fetching.
- Durable generation idempotency, authority checks, operations and account migration helpers.
- Admin UI active/revoked filtering and extension 1.1.1 browser import/download behavior.
- Desktop engine/helper source and its regression tests, retained for future native packaging integration.
- Existing functional tests and historical verification documents. Historical results are not current verification claims.

## Deliberately excluded/deferred

- Flutter source (canonical repository: https://github.com/ngonhat94/muse_app).
- GitHub workflows, tools/ci_*, deploy scripts, bootstrap scripts and their dedicated tests, production compose overrides and deployment/CI documentation from murouter.
- Graphify generated artifacts (local-only).
- Changes to Dockerfile/build context from murouter. Upstream runtime Docker assets remain unchanged; image build and deployment are deferred.
- Actual production data, credentials, secrets, volumes, hosting configuration and deployments.

The desktop helpers still use the original ROOT/muse_app convention. For native packaging, a coordinated client checkout/path migration is required; full packaged desktop builds were NOT verified. Web/frontend source does not need to be copied back into this repository.

## Upstream compatibility

Preserve v1.6.12 version.json and full-size image-viewer implementation. Resolve initialization to create data_dir without weakening tenant/storage authority. Adapt the new viewer test to supply a synthetic owner/writer rather than bypass production checks. Extension-notice tests now validate the latest release metadata and separate extension guide instead of assuming v1.6.11 release-note text.

## Local verification

- 45 guarded backend scripts: all passed. Inventory is recorded in tests/custom_cases.json.
- Run all guarded cases locally: `python tests/run_custom_regressions.py`. This is a manual test tool, not CI/CD.
- 8 Node .mjs/.cjs regression scripts: all passed.
- 4 upstream integration scripts (cookie rotation, version reporting, release integration, FFmpeg thumbnails): passed with temporary synthetic secrets and outbound-network guard.
- Chromium full-size image viewer: 10 checks passed using synthetic HTML/images, no real Muse account.
- Socket-proxy and other existing real-browser suites were not all executed; no claim of full live-service or native verification.

No real users/accounts were created, revoked or rotated. No authenticated production tests or real generation calls. Test logs are local scratch artifacts, not committed secrets.

## Index and update discipline

Refresh local Graphify after migration; query narrowly then confirm source. Integrate future upstream updates on a review branch and run upstream plus custom regressions. Never reset the custom branch to upstream or blindly overwrite source. Do not use Sync fork with force on the customized branch.
