# Text-to-prompt / Magic Enhance verification

## Delivered

Native **Văn bản thành prompt** destination beside the existing image tool in desktop sidebar and mobile More. Available without a Muse connection. Dedicated domain repository, isolated HTTP adapter, cubit and native form preserve existing charcoal/peach theme. Explicit destination disclosure and submit; no automatic transmission, retries or persistence. Input, loading, safe errors, selectable result, explicit clipboard copy, clear; empty/whitespace validation and 4000 UTF-16-code-unit local safety cap. No service limit was found in the inspected component; the UI does not claim that cap is a service rule. Revision/closed guards ignore late results after editing, clearing or disposal. No backend, signing, dependency, global toolchain or desktop-automation changes; no commit.

## Real public contract inspection and request

Fetched https://imageprompt.org/image-prompt-generator with curl and read its public JS component `/_next/static/chunks/app/%5Blocale%5D/(marketing)/(tools)/image-prompt-generator/page-fa38e2c746fbc4e0.js`. Its magic-enhance function uses POST, Content-Type application/json, JSON `{userPrompt: _, page: "image-prompt-generator"}` and reads `r.prompt.trim()`. The site also has its own localStorage-based anonymous count; this app does not emulate identity/tracking or bypass service controls. Python urllib initially failed certificate verification; curl succeeded with normal TLS validation. No TLS checks disabled.

Exactly one benign cookie-free live POST was made using the user's nonprivate example:

```sh
curl --max-time 110 -X POST https://imageprompt.org/api/ai/prompts/magic-enhance \
  -H 'Content-Type: application/json' \
  --data '{"userPrompt":"chú chó màu đen tai cụp dễ thương","page":"image-prompt-generator"}'
```

Observed HTTP 200, JSON string `prompt` (Vietnamese expanded black-dog description) and `generatedAt: "2026-11-12T15:41:07.252Z"`. No cookie, authorization, browser-fingerprint headers or private material were sent. No second live generation, retry, Muse request or login was attempted. Automated tests use synthetic contract fixtures rather than claiming to reproduce live quality.

OPTIONS with Origin `http://localhost:53123`, request method POST and request headers content-type returned HTTP 204 **without Access-Control-Allow-Origin or Access-Control-Allow-Headers**. Thus that browser-origin JSON call is not supported by the observed CORS policy. UI/README disclose desktop/original-site fallback. No backend proxy or CORS bypass. A successful standard web build does not establish live web compatibility.

## TDD and automated coverage

Retained RED/GREEN logs show feature-missing repository, cubit, widget and navigation failures before implementation, followed by passing vertical slices. Response-validation RED exposed an actual raw FormatException containing the deliberately synthetic SECRET sentinel; the adapter now replaces it with safe text. Network timeout tests verify one request and client closure. Further guards were added test-first. Narrow-layout regression checks exercise existing behaviors after the corresponding green slices.

New tests cover exact URI/method/JSON and absent cookie/authorization, Unicode prompt parsing, HTTP 401/402/403/429/451/500, malformed JSON/map/type/blank prompt, timeout and network sanitization/closure, explicit submit, blank/length validation, duplicate suppression, stale edit/clear response, close guards and unknown error sanitization. Widget tests cover disclosure, manual send, loading, selectable result, clipboard, clear, inline validation, safe failure and 390px / 1.6 text without overflow. Shell tests verify disconnected desktop/mobile access. Existing image-tool tests remain passing.

## Final execution (after final production edits)

- `flutter analyze`: **No issues found**, exit 0.
- `flutter test --reporter expanded`: **255 passed**, exit 0.
- `flutter build macos --debug`: success, exit 0; `build/macos/Build/Products/Debug/muse_app.app` (main application entry point).
- `flutter build web`: standard JS success, exit 0; `build/web`.
- Existing flutter_secure_storage_macos SwiftPM adoption warning and secure-storage web Wasm-dry-run dart:html/js compatibility warnings remain; neither blocked the requested builds.

Evidence directory relative to muse_app: `build/text-prompt-evidence/`. Contains public `page.html`, `sources.txt`, `chunk-0.js` through `chunk-31.js`, `live-headers.txt`, `live-response.json`, `cors-headers.txt`, `cors-body.txt`; RED/GREEN files `red-repository.log`, `green-repository.log`, `red-response.log`, `green-response.log`, `red-network.log`, `green-network.log`, `red-state.log`, `green-state.log`, `red-guards.log`, `green-guards.log`, `red-widget.log`, `green-widget.log`, `red-navigation.log`, `green-navigation.log`; final `analyze.log`, `full-tests.log`, `macos-build.log`, `web-build.log`. Build output is disposable and ignored; this report preserves measured outcomes.

## Limits

The live request verifies the public service contract through curl, not end-to-end HTTP from Flutter desktop. No manual desktop/window capture, CuaDriver/computer_use, desktop-automation installation or OS interaction was used. No screenshot or manual visual/device claim: visual rendering was not manually inspected; layout is verified by widget execution at narrow/large-text and desktop/mobile shell sizes. Clipboard is verified by the platform-channel test, not OS clipboard inspection. Established PRODUCT/DESIGN and pinned brief substituted for a new design interview in this focused subagent; native Flutter guidance applied, not Taste's website hero/marketing workflows. Parent should independently review and verify before claiming completion.
