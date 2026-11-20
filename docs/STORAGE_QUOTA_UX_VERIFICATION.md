# Storage/quota UX handoff

## Delivered surface

- Flutter library now includes **Lưu trữ của bạn trên server** with an explicit **Làm mới lưu trữ** action. No implicit request on mount, tab changes, connection changes or a timer. Reads only `GET /v1/storage`; displays validated integer byte/file usage, effective limits, retention eligibility and full-quota guidance separately from Muse credits and local downloads. No admin mutation controls in Flutter.
- BLoC/Cubit presentation, domain storage interface/entity and existing media data adapter remain separated. Composition root supplies the existing authenticated transport. Authenticated `media` capability gates the surface; unverified remote connections fail closed, local legacy connections use their existing local authority. Connection identity changes clear the snapshot and invalidate pending results, including same-URL/key object replacement. Unknown is not zero. 401/403/404/429/507/503 and malformed response bodies never display secrets or silently retry.
- Web admin Users table has **存储与限制**. Five labeled bounded integer controls submit all five fields to the actual complete-replacement `PATCH /admin/users/{id}/limits` contract, only after a confirmation listing the target and values. Successful PATCH bodies are discarded; users and storage are authoritatively re-read. Failed/uncertain mutations remain disabled until manual re-read; no automatic mutation retry. Limits are not presented as saved merely because fields changed.
- Retention button explicitly sends `{dry_run:true}` only, shows candidate/quarantine counts, and does not render filenames, paths or raw response/error bodies. No destructive cleanup action or scheduler exists in this panel.
- New form holds only numeric values and target public identity, never copies API keys/Cookies into fields, DOM, form state or browser persistence. Form clears on close, authentication loss, saved-key changes and principal refresh; late reads cannot repopulate a closed/replaced target. Existing separate credential-management UI was preserved, not redesigned.

## Backend contract limitations (not invented)

`GET /admin/users` exposes saved rate overrides, but neither it nor storage reports effective environment request/generation rates when overrides are absent. Those two inputs remain blank with an explicit inheritance/unknown explanation and require intentional numeric entry before a complete replacement. No guessed defaults, zero or unlimited values are submitted. Administrator own limits cannot be PATCHed through `UserStore.set_limits` (admin is not a tenant row); the UI says these remain environment-managed. No backend files or endpoints were edited.

## Executed verification

All fixtures synthetic; no live service, Muse, private runtime data, app/server startup, browser, device/OS automation, dependency install, signing changes or commits.

- Strict TDD: initial adapter test failed on missing `loadStorage`; inert widget surface then failed expected missing manual-refresh/unknown-state assertions; implementation passed. JS test first failed `graphical tenant limit controls absent`, then passed against the implemented inline source. Follow-up edge cases test existing safe behavior. RED output was observed in tool results, not retained as fabricated log files.
- `flutter test --no-pub`: **332 passed**, including **15** storage adapter/widget tests. Coverage includes manual-only requests, capability denial, stale identity completion, error-body suppression, 401/403/404/429/507/503, malformed numeric data, and 390px/2x text layout. Log: `docs/verification-logs/storage-ux-flutter-tests.log`.
- `flutter analyze --no-pub`: **No issues found** after fixing two brace-style infos. Log: `storage-ux-analyze.log`.
- `flutter build web --no-pub`: passed; pre-existing secure-storage WASM dry-run incompatibility warnings remain. Log: `storage-ux-web-build.log`.
- `flutter build macos --debug --no-pub`: passed; existing secure-storage Swift Package Manager warning remains. Log: `storage-ux-macos-build.log`.
- `node tests/test_limits_web.cjs`: passed validation, confirmation cancellation, explicit five-field payload, authoritative reload, dry-run-only, permission denial, safe failures, unknown rate inheritance and late-close response checks.
- `node tests/test_storage_web.cjs`: passed. Extracted all inline script bodies and `node --check` via stdin: exit 0.
- Existing backend synthetic `tests/run_backend_offline.py tests/test_data_protection.py`: **17 tests passed**; no backend mutation beyond isolated fixture data. Log: `storage-ux-backend-fixtures.log`; existing FastAPI lifecycle deprecation warnings remain.
- Code-only incremental graph extraction refreshed changed source without LLM/network or reading runtime secrets; log: `storage-ux-graph.log`. Unsupported platform formats remain excluded as before. `git diff --check` passed.

## Boundaries and parent acceptance

Native design/theme and existing credential persistence preserved. Subagent used supplied bounded brief instead of an unavailable interview interface. No manual rendering/browser/screen-reader/live-service acceptance was performed; headless widget layout tests and builds are not substitutes. Parent must inspect and independently verify the final shared tree, concurrent backend review findings and this new form's boundaries. Original encryption, whole-disk/temp-download and operator provisioning limitations in DATA_PROTECTION_QUOTAS_VERIFICATION.md still apply. No deployment or overall completion claim is implied.
