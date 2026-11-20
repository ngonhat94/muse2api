# Image admission and web credential invalidation review fixes

## Behavior

- A lost image submission response is explicitly `admissionUncertain`. The captured immutable prompt, ratio, ordered references, connection and admission key remain in memory.
- Ordinary submits (including changed prompt/ratio/references) and ordinary clear cannot replace an uncertain admission. Inputs and fresh-submit control are disabled. Nothing retries automatically.
- “Thử lại cùng yêu cầu” manually submits the captured request with the same key, not the current editor contents.
- Discard requires a dialog explaining that the server may already have accepted the request, that discard does not cancel it, and that a new request may duplicate work and consume quota. Cancellation retains the uncertain admission. Confirmation is bound to the exact uncertain state: an old dialog cannot discard a replacement connection's request.
- Shell connection replacement explicitly resets image state and key. Late admission responses cannot update the replacement state or start polling. Closing the bloc invalidates late completions.
- Admin key rotation invokes the existing central `clearOperations()` and tenant-control invalidation before assigning the new credential. Rendered snapshots are cleared immediately, pending snapshots are invalidated, and refresh is enabled even before an old request returns.

## Verification executed

Strict RED/GREEN regressions observed:

1. Changed image intent after lost admission initially produced POST count 2 instead of 1; passed after guarding uncertain submit/clear.
2. Widget regression initially found the prompt enabled after uncertain admission; passed after locking inputs and adding explicit retry/discard controls.
3. Real `rotateKey()` regression initially failed `rotation clears rendered snapshot`; passed after wiring central invalidation. Also covers an in-flight response and refresh enablement.
4. Switching connection while a discard dialog was open initially discarded the replacement intent; passed after binding consent to the captured uncertain state.

Final executed commands from `muse_app/`:

- `flutter analyze --no-pub`: no issues found (2.5s).
- `flutter test --no-pub`: **340 tests passed**, exit 0.
- `flutter build macos --debug --no-pub`: built `build/macos/Build/Products/Debug/muse_app.app`, exit 0.
- `flutter build web --no-pub`: built `build/web`, exit 0.

From repository root, all four `tests/*_web.cjs` scripts passed: admission lifecycle, admin limits/retention, operations real rotation/rendered/in-flight invalidation, and storage errors/usage. `git diff --check` passed.

Build warnings remain: `flutter_secure_storage_macos` does not yet support Swift Package Manager; web Wasm dry-run reports `dart:html`, `dart:js_util` and `package:js` incompatibilities in secure-storage dependencies. Standard web compilation succeeds; no dependency changes were made.

Verification used synthetic repositories/HTTP fixtures; no live Muse, real credentials, private data, network probes, desktop automation, signing changes or commits. Existing dirty work and concurrent backend changes were preserved. Parent independent verification is still required before the completion phrase. Native device/manual visual verification was not performed. Scope deliberately excludes graph-output regeneration.
