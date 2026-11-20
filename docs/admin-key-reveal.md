# Administrator API-key viewing

New user keys and rotated keys can be viewed again by an authenticated administrator in Flutter's **Người dùng & API key** page: choose **Xem key** on the intended user, then **Sao chép API key** or **Ẩn key**. Viewing never rotates a key. Rotation/revocation retain their explicit confirmation.

## Security and operations

- `POST /admin/users/{id}/key/reveal` uses the existing backend `admin_auth` dependency. Tenant keys cannot reveal either their own or another tenant's key. The Flutter repository also requires both administrator role and `manage_users` capability.
- List/create/patch responses never include ciphertext or hashes; list responses never include plaintext keys. Creation/rotation return plaintext only as their existing explicit operation response, now marked `Cache-Control: no-store`. Reveal responses also carry `no-store` and `Pragma: no-cache`.
- `users.json` stores the SHA-256 authentication hash and an authenticated Fernet ciphertext, never the plaintext key. The encrypted payload is domain-separated from cookie storage and bound to the user ID and authentication digest, preventing ciphertext substitution between users or key rotations. Revocation removes ciphertext.
- Encryption reuses the already-required stable server `MUSE2API_COOKIE_KEY` / `MUSE2API_COOKIE_KEY_FILE` provisioning from `protection.AccountCipher`. Do not generate a new key at each restart. Prefer the existing owner-only (0600), regular, non-symlink key-file option. Key creation fails closed if encryption cannot be configured.
- **Back up that encryption key separately and securely alongside consistent account/user-data backups.** Losing/changing it makes existing encrypted keys and cookies unreadable. Restore matching key and data; do not expect hashes to recover plaintext. Coordinated re-encryption is required before replacing this server encryption key; this change does not implement a master-key migration tool.
- Historical hash-only keys cannot be recovered. They still authenticate normally, but the UI shows viewing unavailable and instructs the administrator to rotate. Rotation invalidates the prior key and enables future viewing. Never rotate automatically as a reveal fallback.
- Plaintext is held only in transient UI state, one revealed row at a time. Hide, refresh, mutation, disconnect/server replacement, page disposal and app backgrounding remove visible revealed state; stale reveal responses are discarded. This is not cryptographic memory zeroization in Dart.
- Copy is intentional and uses the OS clipboard. The clipboard may outlive the screen and be available to other applications. Clear it after use; the app does not silently overwrite the user's clipboard. No plaintext secret is persisted in preferences, logs or list caches by this feature.

## Verification

Synthetic storage tests cover restart persistence, no plaintext/list leakage, legacy fallback, rotation/revocation, missing key and ciphertext/row/key mismatch. Offline ASGI isolation tests cover administrator reveal, unauthenticated/self/other-tenant denial, no-store headers and legacy/revocation behavior. Flutter tests cover explicit reveal/hide/copy, authorization, escaped paths, sanitized failures and stale-result disposal. These do not contact Muse or production.
