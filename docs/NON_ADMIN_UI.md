# Focused user interface

Remote sessions show server connection/configuration and diagnostics only when the verified principal has role `admin` **and** `global_settings: true`. User/key management independently requires role `admin` and `manage_users: true`. Missing identities, unknown roles, and capabilities without the admin role do not enable technical UI.

The desktop sidebar, mobile More sheet, selection callbacks, and technical page mounting use the same permission decision. Technical pages are unmounted when not selected. Diagnostics discard in-flight responses when the verified connection changes, including replacement sessions with the same URL/key. User sessions cannot initiate diagnostics refresh through the status Cubit.

Users retain chat, image/video creation, tasks, library, prompt tools, their own Muse account/cookie import and account operations, and explicit logout. Account/session/task feedback is retained. Desktop local-engine setup remains available when supported; a local engine is not a verified admin and does not enable remote diagnostics or user management. The web login gate remains key-only and clears feature state on disconnect/logout.

This is UI simplification, not concealment of the backend from browser network tools and not a replacement for backend tenant/authorization enforcement. No proxy, API changes, real account/cookie operations, production deployment, or merge are included.

## Verification

- Full Flutter test suite, including 10 focused permissions/session/responsive cases, client-config guards, admin status tests, existing logout and login error tests.
- Synthetic Playwright browser fixtures at 390px and 1280px: user technical navigation absent, admin navigation retained, own tools/logout present, no diagnostics requests on login. All backend requests intercepted; no Muse requests.
- Release JavaScript web build. Existing secure-storage dependency prevents the optional Wasm dry run; the release JS build succeeds.
- Analyzer with `--no-fatal-infos`; the installed Flutter 3.50 SDK reports existing informational deprecations/lints. New tests follow the existing Material import convention.
- `graphify update .` could not run: graphify is absent in both the local and remote environments. The pre-existing graph is not claimed fresh.
