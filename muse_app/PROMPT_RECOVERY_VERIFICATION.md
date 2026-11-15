# Prompt handoff + pending-generation recovery

## Scope / choices

Implemented prompt-tool → existing image/video form handoff first, then durable pending IDs. Preserved the existing native Flutter neutral/peach dashboard world; inferred the bounded interaction direction from the delegated brief (no interview tool in this subagent). No backend source edits, credentials probes, live generation/quota requests, signing/entitlement changes, dependency upgrades or OS automation.

Recovery uses one GET sweep on connection restoration and when opening Tasks; individual **Kiểm tra** retries are read-only. Active form polling remains unchanged. Multiple stored IDs are supported. Unknown/404 records are retained rather than declaring generation failed or deleting the recovery evidence. Terminal records are removed; completed output is accessible through the existing server Library. Recovery terminal notices are session-only. Storage is deliberately minimal `{version:1,tasks:[{kind,id}]}` under a SHA-256 namespace of URL + credential. No raw API key, cookies, prompts, references or image Base64 in preferences. This namespace isolates credentials, not an encryption mechanism.

A killed process cannot recover a task ID that the server had not yet returned or the app had not yet persisted. A storage failure keeps the admitted ID in the active form and blocks duplicate submission. Malformed persisted data is not overwritten. Disconnect/close never claims to cancel remote generation. iOS standalone remains **pending**.

## Source contract checked read-only

- `../app.py:1311–1328`: POST `/v1/images/tasks`; GET `/v1/images/tasks/{task_id}`. Wrong/missing image task → HTTP 404; completed result assembled with `_image_response`.
- `../app.py:1451–1513`: POST `/v1/videos` (alias `/v1/videos/generations`); GET `/v1/videos/{task_id}` (alias); missing task → HTTP 404; completed aliases normalized by backend.
- Existing `ImageRemoteDataSource`, `VideoRepositoryImpl`, task decoders reused. No invented endpoints.
- Existing secure credentials and chat-history storage were inspected; credential behavior was not replaced.

## Changed source

- `lib/app/{app,dependencies,shell}.dart`: composition and connection recovery, handoff controller ownership, overwrite confirmation, Tasks recovery panel.
- `lib/features/{image_prompt,text_prompt}/presentation/*_page.dart`: result actions.
- `lib/features/{images,videos}/presentation/pages/*_page.dart`: optional externally owned prompt controller, preserve form subtree when routing.
- `lib/features/{images,videos}/presentation/bloc/*_bloc.dart`: persist returned pending IDs before polling; remove confirmed terminal IDs; durable manually resumed video; storage failure retains admitted task.
- New `lib/core/storage/pending_generation_store.dart`, `lib/core/presentation/generation_recovery_{cubit,panel}.dart`.
- New `test/{prompt_handoff,pending_generation_store,generation_recovery}_test.dart`; extended `test/text_prompt_page_test.dart`.
- README usage/safety notes; root graph refreshed per AGENTS (`graphify-out/` generated outputs).

## TDD evidence

Logs under `verification/prompt-recovery/`:
- `handoff-red.log` → `handoff-green.log`: missing handoff interface then local routing/prepopulation/overwrite consent and zero requests.
- `store-red.log` → `store-green.log`: missing durable store then relaunch reconstruction, multi-ID serialized writes/dedupe, credential/server isolation and safe schema.
- `recovery-red.log` → `recovery-green.log`: missing recovery orchestration then admitted image → persisted → close/reconstruct → offline GET retained → GET-only success.
- `ui-recovery-red.log` → `ui-recovery-green.log`: missing Tasks recovery surface then connected composition.
- `storage-failure-red.log` → `storage-failure-green.log`: admitted ID lost on malformed storage reproduced; fixed without allowing a second POST.
- `refresh-red.log` → `refresh-green.log`: explicit read-only rescan API.
- `id-red.log`: returned task-ID mismatch reproduced; subsequent `latest-targeted.log` verifies guarded implementation.
- `resume-red.log`: manually resumed video not persisted reproduced; subsequent `latest-targeted.log` verifies durable GET-only resume.
- Additional regressions cover video relaunch, confirmed failure, retained 404, stale server/dispose reads, preserved form/reference-picker subtree, actual result button callbacks and no resubmission.

## Final verification

Final commands and full retained output:

| Command | Result | Log |
|---|---|---|
| `flutter analyze` | exit 0; No issues found | `verification/prompt-recovery/analyze.log` |
| `flutter test` | exit 0; **289 tests passed** | `verification/prompt-recovery/full-tests.log` |
| `flutter build macos --debug` | exit 0; `build/macos/Build/Products/Debug/muse_app.app` | `verification/prompt-recovery/macos-debug.log` |
| `flutter build web` | exit 0; `build/web` | `verification/prompt-recovery/web.log` |
| `graphify update .` (repository root) | exit 0 | `verification/prompt-recovery/graph-update.log` |

Warnings retained: flutter_secure_storage_macos lacks Swift Package Manager support; standard web succeeds but Wasm dry run flags existing secure-storage `dart:html`/`dart:js_util` dependencies. No dependency change attempted. Graph automatic community labels may need curator refresh; update reports this explicitly.

All network behavior here uses fakes/MockClient. Build success is not a live Muse compatibility, visual screenshot, macOS hardware UI, restart-with-real-key, or iOS verification claim. No manual OS-driven UI validation performed, per task boundary. Prompt-tool third-party CORS limitations remain unchanged.
