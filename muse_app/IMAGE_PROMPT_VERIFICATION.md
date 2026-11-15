# Image prompt verification

## Delivered

Native charcoal/peach Flutter screen **Ảnh thành prompt**, sidebar and mobile More destination, disconnected from Muse. System picker and desktop_drop target, one image, decoded-byte validation and 10 MiB cap, local preview, explicit third-party-send disclosure, loading/error/prompt/copy/replace/clear. No retries, cookies, credentials, persistence or backend/proxy changes. Generation revision guards reject stale results after replacement, clear and disposal.

## Real contract

Inspected public imageprompt.org image-to-prompt page and JS chunk `3298-0a6ff4512d5f78bd.js`. Site sends `Content-Type: application/json`, JSON `{base64Url, imageModelId, language}` and accepts a string `prompt`. One cookie-free synthetic PNG 32×32 peach-square call returned HTTP 200 with a real English description and generatedAt. No private image or provided tracking cookie was used.

OPTIONS preflight for Origin `http://localhost:53123` returned 204 without Access-Control-Allow-Origin/Headers. Browser-origin uploads are therefore not supported by that observed CORS policy; UI and README disclose desktop/original-site fallback. No proxy workaround introduced.

## Executed after final production edits

- `flutter analyze`: No issues found.
- `flutter test --reporter expanded`: **246 passed**.
- `flutter build macos --debug`: success, `build/macos/Build/Products/Debug/muse_app.app`.
- `flutter build web`: success, `build/web`.
- Existing flutter_secure_storage_macos SwiftPM warning remains. Web Wasm dry run warns about existing flutter_secure_storage_web dart:html/js dependencies; standard JS build succeeds.

Test-first execution observed missing-feature failures before repository, validator, state and widget implementation; stale replacement regression was observed failing with actual `stale` then fixed. Repository tests cover request isolation, response shape, all observed HTTP errors, timeout/client closing and safe network errors. Validator covers real PNG, signature-only corruption, empty/unsupported and actual-byte cap. State/widget tests cover local selection/drop, explicit upload, duplicate prevention, failure, stale response, clear/dispose, copy, picker cancellation and narrow 390px/1.6 text; shell tests cover desktop/mobile disconnected access.

## Render evidence and limitations

Ran `flutter run -d macos -t tool/image_prompt_preview.dart`, a credential-free native visual harness with a synthetic picker (no automatic upload). computer_use could not capture a window (0×0), so captured the actual macOS Flutter render through its VM inspector screenshot extension instead. Image: `/Users/nhatngo/.hermes/cache/scratch/image-prompt-native.png`. Visually inspected: readable heading/upload/action/disclosure; no clipping; empty-state disabled action matches expectation. This is not an OS-window screenshot or proof of native system-picker/drop interaction. Native picker/OS drag and end-to-end HTTP within Flutter remain unverified manually; test callbacks exercise drop adapter and picker through injected files. Do not claim those as device tests.

Raw contract/build/test evidence is retained under `/Users/nhatngo/.hermes/cache/scratch/`: `imageprompt-response.txt`, `imageprompt-response-headers.txt`, `imageprompt-cors-headers.txt`, `image-prompt-full-tests.log`, `image-prompt-macos-build.log`, `image-prompt-web-build.log`. Scratch may be pruned; this report preserves measured results.

No backend, signing, global toolchain or installed-package source edits; no commit. Desktop engine work left untouched. Added desktop_drop (existing file_selector handles selection but not external OS file drop), its lockfile and generated native registration. Main app builds were rerun after the preview harness run so shipped debug artifact uses lib/main.dart.

Impeccable context used established DESIGN/PRODUCT and pinned brief instead of a new design interview; subagent has no interview/agent delegation tool, so local UI review substituted. Pre-existing `.impeccable/design.json` schema drift reported, not modified. Parent must independently verify/review before using the user-requested completion phrase.
