# Library filtering and batch-save verification

## Delivered
- Type filter, trimmed case-insensitive name search, newest-first default; unknown dates last, stable equal-date ordering; server order toggle. Query does not mutate repository items.
- Query changes clear selection explicitly; selected files offer save-to-folder separately from destructive confirmed deletion.
- One directory picker, sequential streaming through existing NativeMediaSaver; validated source names/routes, credential-free GET, redirects disabled, sibling staging and final rename. Existing destinations, including symlinks, and duplicate names are skipped. Recheck before rename refuses destinations appearing during transfer. No automatic retries.
- Current-file byte progress, cancellation predicate, per-file saved/failed/skipped/cancelled results and exact saved count. Completed files survive later failure/cancellation. Desktop-only UI and adapter guard; web conditional stub.

## Actual execution
Working directory: `/Volumes/CAI_MAC/mycode/muse2api/muse_app`.

Final commands (all exit 0):
```
flutter analyze
No issues found! (ran in 2.0s)
flutter test
00:25 +299: All tests passed!
flutter build macos --debug
✓ Built build/macos/Build/Products/Debug/muse_app.app
flutter build web
✓ Built build/web
```
Retained raw logs:
- `/Users/nhatngo/.hermes/cache/scratch/library-analyze.log`
- `/Users/nhatngo/.hermes/cache/scratch/library-full-tests.log`
- `/Users/nhatngo/.hermes/cache/scratch/library-macos.log`
- `/Users/nhatngo/.hermes/cache/scratch/library-web.log`
- `/Users/nhatngo/.hermes/cache/scratch/library-query-red.log`
- `/Users/nhatngo/.hermes/cache/scratch/library-batch-red.log`

Observed RED→GREEN: missing library query API; missing batch saver API; selection/search save action absent; mobile adapter guard missing; empty filtered-result explanation absent. Additional regression tests for existing safe primitives passed on first run; these are coverage, not new RED cycles.

Coverage: query type/search/order/unknown dates; selection cleared on search; no-match explanation; 320px/2x text; existing delete/preview regression tests; single-save regression suite; batch partial HTTP error, collision skip, bytes/progress, cancelled picker, duplicate picker, unsafe URL before picker, real loopback HTTP cancellation during second file retaining first success, destination appearing during transfer. No Muse/private media transfers or quota usage.

## Warnings and remaining limits
- macOS build reports flutter_secure_storage_macos lacks Swift Package Manager support (existing plugin warning).
- Standard web build succeeds; wasm dry-run warns about existing secure-storage dart:html/js_util dependencies. No dependency upgrades made.
- Directory picker not manually exercised; no desktop automation installed/used. Native rendered visual review and Windows/Linux builds not performed.
- Superseded by hardening below: no-replace saves now use atomic hard-link publication, never check-then-rename. Windows and filesystems without hard-link support fail closed; no unsafe fallback.
- Dedicated injected widget acceptance tests now cover picker/transfer pending cancellation, disposal and server switching, stale progress/errors/success suppression, partial results, and selected/progress/results at 320×800 with 2× text.
- Whole-page scrolling fixes the observed 266px bottom overflow in selected narrow layout. Widget evidence establishes layout/action reachability, not a native visual review or large-library performance benchmark.
- Per-file results remain local to the page; disconnect clears old-server results. Directory errors before per-file iteration show a generic error. Successful saves are not durable history.
- Parent independent verification/review remains required before marking the agreed slice complete. No commits/pushes, backend/signing/entitlement/global/pub-cache changes.

## Safety and widget acceptance hardening
- `media_saver_io.dart`: default single-save replacement remains rename-based and unchanged. Only `replaceExisting: false` uses `/bin/link` on macOS or `/usr/bin/link` on Linux via `Process.run` (no shell/PATH resolution, no install/dependency/signing change). The OS hard-link operation refuses any existing destination atomically. Missing utility, Windows, unsupported filesystem or denied subprocess fails closed. Cleanup only deletes the private staging directory; never deletes or truncates the destination. External actors can still delete/mutate files themselves; this is not a defense against an attacker controlling the entire destination directory.
- Deterministic `beforePublish` test seam creates a competing destination after the old final existence check. RED observed `MediaSaveResult.saved` instead of exception; GREEN preserves competing bytes `[9]`. Existing batch loopback/collision/cancel and single-save tests also pass.
- Widget RED found stale old-server error snackbar and 266px narrow selected-layout overflow. Fixed current-operation guards for progress/error and whole-page scrolling. Pending saver is an injected fixture, not an actual OS picker; real adapter cancellation and loopback transfer coverage remain separate.
- Added `test/media_no_clobber_test.dart` and `test/features/library_save_page_test.dart` (8 widget tests). Changed `lib/core/data/media_saver_io.dart`, `lib/features/media/presentation/pages/media_page.dart`, this report.
- Final actual execution: `flutter analyze`: No issues found (2.5s); `flutter test`: `00:29 +308: All tests passed!`; `flutter build macos --debug`: built `build/macos/Build/Products/Debug/muse_app.app`; `flutter build web`: built `build/web`. Existing secure-storage SwiftPM and wasm dry-run warnings remain. No live Muse calls.
- Exact logs in `/Users/nhatngo/.hermes/cache/scratch/`: `library-hardening-race-red.log`, `library-hardening-widget-red.log`, `library-hardening-widget-green.log`, `library-hardening-analyze.log`, `library-hardening-tests.log`, `library-hardening-macos.log`, `library-hardening-web.log`.
- Remaining portability/UX limit: Windows batch writes fail safely rather than publishing; Linux utility path and hard-link support are runtime-checked by execution but not built/tested here. Current desktop availability copy is broader than actual safe publication support; no false portable-success guarantee is made here. Filesystems without hard links cannot batch-save. Parent review should decide whether a dedicated unsupported-platform message is required before release.
