# Direct media save verification

## Result

Implemented explicit **Lưu về máy** for desktop generated images, video preview, Library preview and completed Task result preview. Reuses file_selector Save As, with no dependency/signing/entitlement/backend edits. Source inspection confirmed `../app.py:1832–1839` serves `/v1/media/{name}` without `Depends(auth)`. Download transport consequently sends no API key/cookies and follows no redirects. Existing browser-open action remains separate.

## Execution evidence

All paths below are relative to `muse_app/`. Final execution:

| Command | Result | Log |
| --- | --- | --- |
| `flutter test test/media_save_test.dart test/media_save_button_test.dart` | 25 passed | `build/save-verification/targeted-tests.log` |
| `flutter analyze` | No issues found | `build/save-verification/analyze.log` |
| `flutter test` | 280 passed | `build/save-verification/full-tests.log` |
| `flutter build macos --debug` | Success | `build/save-verification/macos-build.log` |
| `flutter build web` | Success (standard JS build) | `build/save-verification/web-build.log` |
| `graphify update .` | Success, app graph refreshed | `build/save-verification/graph-update.log` |

Artifacts exist at `build/macos/Build/Products/Debug/muse_app.app` and `build/web/index.html`. Build logs retain the existing flutter_secure_storage macOS SwiftPM adoption warning and flutter_secure_storage_web Wasm dry-run incompatibilities; neither blocks the requested builds. No Wasm compatibility claim.

## RED/GREEN evidence and coverage

Test-first initial missing API probe: `red-core.log`. After interface-only scaffold, behavioral RED returned cancelled rather than saved: `red-core-behavior.log`; GREEN: `green-core.log`. Safety RED: `red-safety.log`; GREEN: `green-safety.log`. Button RED: `red-widget.log`; GREEN: `green-widget.log`. Shared preview missing-button RED: `red-integration.log`. Credential-bearing filename RED: `red-credential-name.log`. Final targeted/full runs supersede intermediate integration runs (one intermediate run identified a test-only platform override teardown issue, fixed without weakening the product assertion). Later added regression tests exercise already-covered behavior; not every later regression test was independently red.

Coverage includes original image bytes and safe PNG suggestion; streamed video bytes; real local HTTP request path with reverse-proxy prefix and no auth/cookie/query; malformed/untrusted URL, userinfo, traversal/double-encoding, query and unsupported extension rejection; credential-like filename rejection; HTTP 302/401/404/500 without replacing existing destination; picker cancellation/no network; stale picker/response; network idle timeout and staging cleanup; duplicate calls while picker pending; shared preview button; explicit-only save; progress; cancel/dispose invalidation and no false success; 320px width with 2x text scaling. Fixtures are synthetic bytes only; local socket tests use loopback. No real Muse generation, quota calls, or private file transfer.

## Implementation and limits

- Domain source/use case/adapter contract: `lib/core/domain/save_media.dart`. Native adapter: `lib/core/data/media_saver_io.dart`; conditional factory/stub retain standard web build compatibility. UI component: `lib/core/presentation/media_save_button.dart`; composition through `AppDependencies`/`RepositoryProvider`.
- Remote download writes each chunk through RandomAccessFile, without collecting a full video in RAM. A private sibling staging directory keeps final rename on the same filesystem. Existing destination is only replaced after successful response, content-length check when supplied, flush, close and final stale check. Existing-image bytes are not re-encoded.
- Picker itself has no programmatic cancellation API; dismiss its native dialog to cancel. Hủy lưu cancels the transfer after selection, closing HTTP on cancellation checks. Network idle timeout: 30 seconds; total network deadline: 20 minutes. No automatic retry or background export.
- Cancellation/stale checks occur before network and before writes/commit, but OS filesystem calls already in progress cannot be revoked. There is an unavoidable small race between final stale check and filesystem rename. Cleanup is best-effort on disconnected/unwritable storage; force-killing the process may leave `.muse-save-*` staging directories.
- Native Save As overwrite confirmation is delegated to file_selector/OS, not manually exercised here. No lock against another program concurrently changing the selected destination. Windows/Linux overwrite and filesystem behavior has not been run on those systems; rename failure reports failure, not success.
- Direct-save UI supports desktop only. Web/mobile show an explicit desktop-support explanation. URL media retains browser-open fallback; generated in-memory images do not gain a web export path in this slice.
- No desktop automation/CuaDriver/computer_use was installed or used. No live OS dialog/manual native UI, real codec/media generation, or real-service integration tested. Native screenshot verification is not claimed. Existing macOS sandbox is disabled; no entitlement changes made. Future sandbox-enabled distribution needs appropriate user-selected write permission.
- Design was inferred from the delegated bounded brief and incumbent PRODUCT.md/DESIGN.md rather than a user interview; native Flutter Operate-mode controls preserved, no website scaffold introduced.

No commits made. Changes are scoped to muse_app, including its refreshed graph and generated build/test outputs. Existing parent desktop engine changes remain untouched.
