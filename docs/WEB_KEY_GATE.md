# Web key gate

Muse Studio Web mounts only the API-key field and sign-in button before a connection is verified. The shared public server directory still chooses the server; no URL input or ordinary navigation is exposed at the gate. The exact fallback remains `https://18610-agq6gp235jkrlip6hyszdk5ctm.instabox.tech`.

`ConnectionBloc` restores remembered credentials and verifies `/v1/models` followed by `/v1/me`. Only a connected state with a verified principal mounts the feature session. Invalid credentials, malformed identity responses, server errors and unavailable verification remain at the gate. The form masks the key, disables submission while checking, and uses existing safe Vietnamese errors. It never pre-fills a remembered key into the ephemeral field.

Disconnect retains the remembered key (existing behavior), but replaces the Navigator and disposes the entire feature session, including prompt controllers, dialogs, and feature BLoCs. “Quên API key đã lưu” on the connected connection page also removes persisted credentials. On refresh, a retained key must pass verification again. No automatic retry occurs after disconnect on the current page.

Authenticated HTTP 401 responses from the current Muse session return web users to the gate. HTTP 403 is a permission failure, not automatic logout. The transport adapter captures the session callback when a client is created, and the callback checks the captured connection identity, origin and authorization; a late response from a disposed/replaced session cannot disconnect a new one. Revocation is observed on the next authenticated request, not via background polling. This UI gate does not replace backend authorization.

The default gate is web-only (`kIsWeb`). Desktop startup, local engine mode and existing role/capability checks remain unchanged. The `requireKey` constructor override exists for deterministic full-app VM widget coverage of the actual web boundary.

Verification uses synthetic transports and credentials only; no real Muse generation, browser cookies, or production changes are required. `test/web_key_gate_test.dart` covers narrow/wide user/admin login, no pre-verification feature mount or authenticated side effects, blank/invalid keys, pending identity verification, disabled duplicate submission, disconnect/401 cleanup, restored-key success/revocation/unavailable verification and late completion after disconnect. `test/session_client_test.dart` checks the authenticated-401-only transport notification rule.
