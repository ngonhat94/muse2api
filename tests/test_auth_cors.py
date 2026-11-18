"""Browser-visible auth failures through the complete ASGI middleware stack."""
import asyncio
import sys
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import httpx
import app


async def main():
    origin = 'https://ngonhat94.github.io'
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app.app), base_url='http://fixture') as client:
        preflight = await client.options('/v1/models', headers={
            'Origin': origin, 'Access-Control-Request-Method': 'GET',
            'Access-Control-Request-Headers': 'authorization',
        })
        assert preflight.status_code == 200
        assert preflight.headers.get('access-control-allow-origin') == '*'
        for path in ['/v1/models', '/v1/me']:
            for key in ['', 'synthetic-nonexistent']:
                response = await client.get(path, headers={'Origin': origin, 'Authorization': 'Bearer ' + key})
                assert response.status_code == 401
                assert response.headers.get('access-control-allow-origin') == '*', (path, response.headers)
                assert response.json() == {'detail': 'Invalid API key'}
        user, key = app.users.create('synthetic-cors')
        headers = {'Origin': origin, 'Authorization': 'Bearer ' + key}
        allowed = await client.get('/v1/me', headers=headers)
        assert allowed.status_code == 200
        assert allowed.headers.get('access-control-allow-origin') == '*'
        forbidden = await client.get('/admin/users', headers=headers)
        assert forbidden.status_code == 403
        assert forbidden.headers.get('access-control-allow-origin') == '*'
        with patch.object(app.REQUEST_LIMITER, 'admit', return_value=12):
            limited = await client.get('/v1/me', headers=headers)
            assert limited.status_code == 429
            assert limited.headers.get('access-control-allow-origin') == '*'
        # A formerly valid key rejected by auth must remain browser-readable too.
        app.users.revoke(user['id'])
        revoked = await client.get('/v1/me', headers=headers)
        assert revoked.status_code == 401
        assert revoked.headers.get('access-control-allow-origin') == '*'
        no_origin = await client.get('/v1/me', headers={'Authorization': 'Bearer synthetic-nonexistent'})
        assert no_origin.status_code == 401
        assert 'access-control-allow-origin' not in no_origin.headers


asyncio.run(main())
print('auth CORS: preflight, invalid/revoked key, forbidden and rate limit passed')
