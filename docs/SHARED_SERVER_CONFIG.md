# Shared Muse server directory

Flutter remote login now asks only for an API key. The displayed server address is loaded without credentials from `GET /public/client-config` on the build-time bootstrap server. The default (and fallback if the directory is unavailable, old or malformed) is exactly:

`https://18610-agq6gp235jkrlip6hyszdk5ctm.instabox.tech`

An authenticated administrator with verified `role=admin` and `global_settings=true` can edit **Cấu hình server dùng chung** on the connection screen. Save posts `{"server_url":"https://…"}` to `/admin/client-config` on the pinned bootstrap server, then verifies via public readback. Regular users cannot edit it; backend authorization also rejects their requests. Only this public URL is returned, never keys or other configuration. HTTPS without credentials, query, fragment, /v1 suffix or ambiguous path segments is required. No server-side fetch of the configured destination occurs.

The backend atomically persists `data/client-config.json` under `MUSE2API_HOME` (existing Docker data volume). Keep this directory writable and persistent. Apply the backend release as well as the Flutter release to enable saving; older backends gracefully use the default address. This change does not deploy or modify any live runtime configuration.

## Changing destinations

Saving does not reconnect the current session or forward any key to the new destination. On a subsequent app opening, a remembered key is auto-used only if its saved server equals the directory URL. Otherwise the user sees the new URL and must explicitly enter their key and connect. Saved credentials are preserved, not erased. Existing local desktop engine mode is unchanged.

The bootstrap is a stable directory authority, not a chain of redirects: leave it reachable even when moving the Muse API. To administer it after changing destinations, select **Quản trị cấu hình tại server bootstrap** on the login screen (this only switches between two known destinations and clears entered keys), then explicitly log in with its admin key. The editor writes only while authenticated to that exact bootstrap. Updating a separate server cannot alter this directory.

If retiring the bootstrap itself, rebuild Flutter with `--dart-define=MUSE_BOOTSTRAP_URL=https://new-directory.example` and distribute the build. This cannot be solved by storing a URL only in the user's browser. Migrating accounts/keys to a new server and configuring its HTTPS/CORS remain operator responsibilities.

## Verification

Synthetic transports only: public bootstrap/fallback, admin+capability gating, exact POST/readback, no credentials on public requests, disabled redirects, duplicate/stale save handling, changed-server saved-key suppression, late bootstrap cancellation, and key-only login at mobile/desktop widths. Backend guarded regressions cover anonymous/user rejection, persistent readback, unsafe URL rejection and write failure. No live users, keys, Muse requests or production changes are involved.
