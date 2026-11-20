# Web authentication errors

## Cause and fix

A nonexistent bearer key returns `401 {"detail":"Invalid API key"}` from
`TenantRateMiddleware`. CORS used to be registered before this middleware.
Starlette wraps the last registered middleware outermost, so the early 401
bypassed CORS. Browsers consequently hid its status/body and `http.Client`
reported a transport failure. `ConnectionRepositoryImpl.verify` mapped that
exception to the generic URL/network/CORS message.

Register the existing CORS policy after tenant/idempotency middleware so it also
covers their early responses. No allowed origins, methods, headers, credentials
policy or authentication rules have been broadened.

- HTTP 401: invalid/revoked key; ask the user to re-enter it or request a new key.
- HTTP 403: permission denied; ask an administrator to check access.
- ClientException: network/TLS/CORS remains a transport failure, never guessed 401.
- TimeoutException: server response timeout.
- Malformed response: server/protocol error, not network or authentication.

Messages never expose arbitrary response bodies or keys. The web gate remains
closed until both models and identity checks pass. Session rejection callbacks
are still session-bound; 403 does not log out a valid session and explicit logout
wins over a late login response.

## Verification

Read-only public-origin requests using only a synthetic nonexistent token found
401 responses without `Access-Control-Allow-Origin` on `/v1/models` and `/v1/me`.
Chromium cross-origin fetch reproduced `TypeError: Failed to fetch` for both.
No production keys, mutations or deployment were used.

`tests/test_auth_cors.py` exercises the complete local ASGI stack: preflight,
missing/invalid/revoked keys, successful identity, forbidden admin access,
rate-limit rejection, and requests without Origin. It failed on missing CORS
before the change and passes afterward. It is included in guarded backend CI.

`muse_app/test/connection_error_mapping_test.dart` exercises both verification
endpoints for 401, 403, transport failure, timeout and malformed JSON, and the
concurrent explicit-logout/late-401 race. Existing web-gate and logout tests
cover remembered-key restore, mobile/desktop layouts, session rejection and
shell teardown.

This change needs backend deployment **and** frontend publication after review.
Frontend alone cannot recover an HTTP status hidden by browser CORS enforcement.
The PR does not merge or deploy it.
