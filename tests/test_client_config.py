"""Synthetic API/store regressions; run via run_backend_offline.py."""
import os
import tempfile
from unittest.mock import patch
from fastapi.testclient import TestClient
import app
from client_config import ClientConfigStore, DEFAULT_SERVER_URL, validate_server_url

with tempfile.TemporaryDirectory() as home:
    store = ClientConfigStore(os.path.join(home, 'config.json'))
    with patch.object(app, 'client_config', store):
        client = TestClient(app.app)
        assert client.get('/public/client-config').json() == {'server_url': DEFAULT_SERVER_URL}
        assert client.get('/public/client-config').headers['cache-control'] == 'no-store'
        body = {'server_url': 'https://new.example/muse'}
        assert client.post('/admin/client-config', json=body).status_code == 401
        _, user_key = app.users.create('synthetic-config-test')
        client.headers['Authorization'] = 'Bearer ' + user_key
        assert client.post('/admin/client-config', json=body).status_code == 403
        client.headers['Authorization'] = 'Bearer synthetic-admin'
        assert client.post('/admin/client-config', json=body).json() == body
        assert ClientConfigStore(store.path).read() == body
        assert client.get('/public/client-config').json() == body
        for value in ['http://example.com', 'https://u:p@example.com', 'https://example.com?key=x', 'https://example.com#x', 'https://example.com/v1', 'https://example.com/../x', 'https://example.com/%2e%2e', 'https://example.com\\@evil.com', 'https://example.com:0']:
            assert client.post('/admin/client-config', json={'server_url': value}).status_code == 400, value
            assert store.read() == body
        assert client.post('/admin/client-config', json={**body, 'api_key': 'synthetic'}).status_code == 422
        with patch('client_config._write', side_effect=OSError()):
            assert client.post('/admin/client-config', json=body).status_code == 503
        app.app.dependency_overrides.clear()
print('client config: API/storage/security regressions passed')
