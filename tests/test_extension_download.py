"""Offline real ASGI ZIP/auth regression; synthetic credentials only."""
import asyncio
import io
import json
import os
from pathlib import Path
import sys
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / 'tests'))
from test_multitenant_security import Client

async def main():
    with tempfile.TemporaryDirectory(dir=os.environ.get('TMPDIR')) as home:
        os.environ['MUSE2API_HOME'] = home
        os.environ['MUSE2API_KEY'] = 'synthetic-admin-extension-test'
        os.environ['MUSE2API_LEDGER_INITIALIZE'] = '1'
        import app
        admin = Client(app.app, 'synthetic-admin-extension-test')
        created = await admin.request('POST', '/admin/users', {'label': 'Synthetic ZIP user'})
        assert created.status_code == 201
        user = Client(app.app, created.json()['api_key'])
        for client in (admin, user):
            result = await client.request('GET', '/admin/extension')
            assert result.status_code == 200
            with zipfile.ZipFile(io.BytesIO(result.body)) as archive:
                manifest = json.loads(archive.read('muse2api-extension/manifest.json'))
                assert manifest['version'] == '1.1.0'
                assert all(n.startswith('muse2api-extension/') and '..' not in n.split('/') for n in archive.namelist())
        for key in ('', 'synthetic-invalid'):
            assert (await Client(app.app, key).request('GET', '/admin/extension')).status_code == 401
        assert (await user.request('GET', '/admin/users')).status_code == 403
        print('PASS: admin/user authenticated ZIP 1.1.0; missing/invalid bearer 401; admin controls remain 403')

if __name__ == '__main__':
    asyncio.run(main())
