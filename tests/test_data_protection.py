"""Synthetic encrypted account persistence; no startup, network or production data."""
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from config import Config
from store import Store


class EncryptionTests(unittest.TestCase):
    def test_accounts_require_key_and_never_persist_plaintext(self):
        with tempfile.TemporaryDirectory() as home:
            cfg = Config(base_dir=home)
            with patch.dict(os.environ, {}, clear=True):
                with self.assertRaisesRegex(ValueError, 'encryption key'):
                    Store(cfg)
            with patch.dict(os.environ, {'MUSE2API_COOKIE_KEY': 'A' * 43 + '='}):
                store = Store(cfg)
                store.add_account({'hatch_sess': 'synthetic-private-cookie'}, owner_id='A')
                disk = Path(cfg.accounts_file).read_text()
                self.assertNotIn('synthetic-private-cookie', disk)
                self.assertNotIn('hatch_sess', disk)
                self.assertEqual(Store(cfg).accounts[0]['cookies']['hatch_sess'], 'synthetic-private-cookie')
                self.assertEqual(Path(cfg.accounts_file).stat().st_mode & 0o777, 0o600)


    def test_tamper_wrong_key_and_corrupt_file_fail_closed(self):
        with tempfile.TemporaryDirectory() as home, patch.dict(os.environ, {'MUSE2API_COOKIE_KEY': 'A' * 43 + '='}):
            cfg = Config(base_dir=home)
            store = Store(cfg)
            store.add_account({'hatch_sess': 'private'})
            original = Path(cfg.accounts_file).read_bytes()
            with patch.dict(os.environ, {'MUSE2API_COOKIE_KEY': 'B' * 43 + '='}):
                with self.assertRaises(ValueError):
                    Store(cfg)
            Path(cfg.accounts_file).write_bytes(original.replace(b'gAAAA', b'xAAAA'))
            with self.assertRaises(ValueError):
                Store(cfg)
            Path(cfg.accounts_file).write_text('{')
            with self.assertRaises(ValueError):
                Store(cfg)

    def test_explicit_migration_is_atomic_and_idempotent(self):
        from protection import migrate_accounts
        with tempfile.TemporaryDirectory() as home, patch.dict(os.environ, {'MUSE2API_COOKIE_KEY': 'A' * 43 + '='}):
            cfg = Config(base_dir=home)
            Path(cfg.data_dir).mkdir()
            path = Path(cfg.accounts_file)
            path.write_text(json.dumps([{'id': 'legacy', 'cookies': {'hatch_sess': 'private'}}]))
            original = path.read_bytes()
            with self.assertRaises(ValueError):
                Store(cfg)
            with patch('os.replace', side_effect=OSError('synthetic failure')):
                with self.assertRaises(OSError):
                    migrate_accounts(str(path))
            self.assertEqual(path.read_bytes(), original)
            self.assertTrue(migrate_accounts(str(path)))
            encrypted = path.read_bytes()
            self.assertFalse(migrate_accounts(str(path)))
            self.assertEqual(path.read_bytes(), encrypted)
            self.assertEqual(Store(cfg).accounts[0]['cookies']['hatch_sess'], 'private')
            self.assertNotIn(b'private', encrypted)

    def test_public_accounts_do_not_echo_decrypted_upstream_notes(self):
        with tempfile.TemporaryDirectory() as home, patch.dict(os.environ, {'MUSE2API_COOKIE_KEY': 'A' * 43 + '='}):
            store = Store(Config(base_dir=home))
            a = store.add_account({'hatch_sess': 'synthetic-secret'}, owner_id='A')
            store.mark(a['id'], False, 'Cookie hatch_sess=synthetic-secret', owner_id='A')
            self.assertNotIn('synthetic-secret', json.dumps(store.list_accounts('A')))

    def test_key_file_permissions(self):
        with tempfile.TemporaryDirectory() as home, patch.dict(os.environ, {}, clear=True):
            key = Path(home) / 'key'
            key.write_text('A' * 43 + '=')
            os.chmod(key, 0o644)
            with patch.dict(os.environ, {'MUSE2API_COOKIE_KEY_FILE': str(key)}):
                with self.assertRaises(ValueError):
                    Store(Config(base_dir=home))
                os.chmod(key, 0o600)
                Store(Config(base_dir=home))


class StorageTests(unittest.TestCase):
    def test_quota_failure_has_stable_status_and_is_not_retryable(self):
        from protection import StorageQuotaExceeded
        with tempfile.TemporaryDirectory() as home, patch.dict(os.environ, {'MUSE2API_COOKIE_KEY': 'A' * 43 + '='}):
            store = Store(Config(base_dir=home))
            store.storage_limits = lambda owner_id: {'bytes': 1, 'files': 1, 'retention_days': 30}
            with self.assertRaises(StorageQuotaExceeded):
                store.write_media('a.png', b'12', 'A')


    def test_engine_output_uses_captured_owner_writer(self):
        from engine import MuseEngine
        with tempfile.TemporaryDirectory() as home, patch.dict(os.environ, {'MUSE2API_COOKIE_KEY': 'A' * 43 + '='}):
            store = Store(Config(base_dir=home))
            engine = MuseEngine(store.cfg)
            engine.media_writer = store.write_media
            engine._ensure_local().media_owner = 'A'
            engine._persist_media('a.png', b'123')
            self.assertEqual(store.media_owner('a.png'), 'A')
            engine._ensure_local().media_owner = None
            with self.assertRaises(ValueError):
                engine._persist_media('b.png', b'123')


    def test_racing_writes_and_failure_cleanup(self):
        from concurrent.futures import ThreadPoolExecutor
        with tempfile.TemporaryDirectory() as home, patch.dict(os.environ, {'MUSE2API_COOKIE_KEY': 'A' * 43 + '='}):
            store = Store(Config(base_dir=home))
            store.storage_limits = lambda owner_id: {'bytes': 5, 'files': 1, 'retention_days': 30}
            def write(index):
                try:
                    store.write_media(str(index) + '.png', b'12345', 'A')
                    return True
                except ValueError:
                    return False
            with ThreadPoolExecutor(max_workers=8) as pool:
                self.assertEqual(sum(pool.map(write, range(8))), 1)
            self.assertEqual(store.storage_usage('A')['bytes'], 5)
            with patch('store._write', side_effect=OSError('synthetic failure')):
                with self.assertRaises(OSError):
                    store.write_media('failed.png', b'12', 'B')
            self.assertFalse((Path(store.cfg.media_dir) / 'failed.png').exists())
            self.assertIsNone(store.media_owner('failed.png'))
            name = store.list_media_names('A')[0]
            with self.assertRaises(ValueError):
                store.register_media(name, 'B')
            self.assertEqual(store.media_owner(name), 'A')

    def test_actual_writes_are_tenant_scoped_and_bounded(self):
        with tempfile.TemporaryDirectory() as home, patch.dict(os.environ, {'MUSE2API_COOKIE_KEY': 'A' * 43 + '='}):
            store = Store(Config(base_dir=home))
            store.storage_limits = lambda owner: {'bytes': 5, 'files': 1, 'retention_days': 30}
            store.write_media('a.png', b'12345', 'A')
            self.assertEqual(store.storage_usage('A')['bytes'], 5)
            with self.assertRaisesRegex(ValueError, 'storage quota'):
                store.write_media('next.png', b'1', 'A')
            self.assertFalse((Path(store.cfg.media_dir) / 'next.png').exists())
            store.write_media('b.png', b'12', 'B')
            with self.assertRaises(ValueError):
                store.write_media('a.png', b'x', 'B')
            self.assertEqual((Path(store.cfg.media_dir) / 'a.png').read_bytes(), b'12345')
            self.assertEqual(store.storage_usage('B')['files'], 1)
            self.assertEqual(Store(store.cfg).storage_usage('A')['bytes'], 5)


class RetentionTests(unittest.TestCase):
    def test_dry_run_never_crosses_owner_or_unknown_files(self):
        with tempfile.TemporaryDirectory() as home, patch.dict(os.environ, {'MUSE2API_COOKIE_KEY': 'A' * 43 + '='}):
            store = Store(Config(base_dir=home))
            store.write_media('a.png', b'a', 'A')
            store.write_media('b.png', b'b', 'B')
            store.media['a.png']['created_at'] = 1
            store.media['b.png']['created_at'] = 1
            (Path(store.cfg.media_dir) / 'unknown.png').write_bytes(b'?')
            result = store.retention('A', now=4000000)
            self.assertEqual(result['candidates'], ['a.png'])
            self.assertEqual(result['quarantined'], ['unknown.png'])
            self.assertTrue((Path(store.cfg.media_dir) / 'a.png').exists())
            store.retention('A', dry_run=False, now=4000000)
            self.assertFalse((Path(store.cfg.media_dir) / 'a.png').exists())
            self.assertTrue((Path(store.cfg.media_dir) / 'b.png').exists())
            self.assertTrue((Path(store.cfg.media_dir) / 'unknown.png').exists())


class LoggingTests(unittest.TestCase):
    def test_logs_and_debug_dump_do_not_emit_secrets(self):
        import logging
        import io
        import app
        stream = io.StringIO()
        handler = logging.StreamHandler(stream)
        app.log.addHandler(handler)
        try:
            app.log.warning('Cookie hatch_sess=synthetic-secret /v1/media/a.png?cap=private')
            self.assertNotIn('synthetic-secret', stream.getvalue())
            self.assertNotIn('cap=private', stream.getvalue())
        finally:
            app.log.removeHandler(handler)
        from uvicorn.logging import AccessFormatter
        access = logging.getLogger('uvicorn.access')
        access.setLevel(logging.INFO)
        formatted = io.StringIO()
        access_handler = logging.StreamHandler(formatted)
        access_handler.setFormatter(AccessFormatter('%(request_line)s'))
        access.addHandler(access_handler)
        try:
            # Suppression must precede AccessFormatter's positional unpacking.
            with patch('logging.Handler.handleError', side_effect=AssertionError('formatter crash')):
                access.info('%s - "%s %s HTTP/%s" %d', 'fixture', 'GET', '/v1/media/a.png?cap=private', '1.1', 200)
            self.assertNotIn('cap=private', formatted.getvalue())
        finally:
            access.removeHandler(access_handler)


class IntegrationTests(unittest.TestCase):
    def test_rate_limit_http_owner_and_revocation(self):
        import asyncio
        import app as module
        import sys
        sys.path.insert(0, str(Path(__file__).parent))
        from test_multitenant_security import Client
        from protection import RequestLimiter
        module.REQUEST_LIMITER = RequestLimiter()
        a, ak = module.users.create('A')
        b, bk = module.users.create('B')
        async def check():
            with patch.dict(os.environ, {'MUSE2API_REQUESTS_PER_MINUTE': '2'}):
                client = Client(module.app, ak)
                self.assertEqual((await client.request('GET', '/v1/me')).status_code, 200)
                self.assertEqual((await client.request('GET', '/v1/me')).status_code, 200)
                self.assertEqual((await client.request('GET', '/v1/me')).status_code, 429)
                self.assertEqual((await Client(module.app, bk).request('GET', '/v1/me')).status_code, 200)
                module.users.revoke(a['id'])
                self.assertEqual((await client.request('GET', '/v1/me')).status_code, 401)
        asyncio.run(check())

    def test_admin_limit_overrides_persist_and_user_cannot_patch(self):
        import asyncio
        import app as module
        import sys
        sys.path.insert(0, str(Path(__file__).parent))
        from test_multitenant_security import Client
        a, ak = module.users.create('limited')
        async def check():
            admin = Client(module.app, module.CFG.api_key)
            payload = {'storage_bytes': 10, 'storage_files': 2}
            response = await admin.request('PATCH', '/admin/users/' + a['id'] + '/limits', payload)
            self.assertEqual(response.status_code, 200)
            self.assertEqual(module.store.storage_limits(a['id'])['bytes'], 10)
            other = await Client(module.app, ak).request('PATCH', '/admin/users/' + a['id'] + '/limits', payload)
            self.assertEqual(other.status_code, 403)
        asyncio.run(check())

    def test_storage_full_rejects_generation_before_upstream(self):
        import asyncio
        import app as module
        import sys
        sys.path.insert(0, str(Path(__file__).parent))
        from test_multitenant_security import Client
        a, ak = module.users.create('full')
        module.users.set_limits(a['id'], {'storage_bytes': 1, 'storage_files': 1})
        module.store.write_media('full.png', b'1', a['id'])
        async def check():
            with patch.object(module, '_prepare_reference_images', side_effect=AssertionError('must not normalize')):
                response = await Client(module.app, ak).request('POST', '/v1/images/tasks', {'prompt': 'test'})
                self.assertEqual(response.status_code, 507)
        asyncio.run(check())

    def test_retention_api_is_admin_only_and_dry_by_default(self):
        import asyncio
        import app as module
        import sys
        sys.path.insert(0, str(Path(__file__).parent))
        from test_multitenant_security import Client
        a, ak = module.users.create('retention')
        module.store.write_media('expired.png', b'1', a['id'])
        module.store.media['expired.png']['created_at'] = 1
        async def check():
            path = '/admin/users/' + a['id'] + '/retention'
            user = await Client(module.app, ak).request('POST', path, {})
            self.assertEqual(user.status_code, 403)
            admin = Client(module.app, module.CFG.api_key)
            preview = await admin.request('POST', path, {})
            self.assertEqual(preview.status_code, 200)
            self.assertTrue(preview.json()['dry_run'])
            self.assertIn('expired.png', preview.json()['candidates'])
            self.assertEqual(module.store.media_owner('expired.png'), a['id'])
        asyncio.run(check())

    def test_storage_usage_route_is_owned(self):
        import asyncio
        import app as module
        import sys
        sys.path.insert(0, str(Path(__file__).parent))
        from test_multitenant_security import Client
        a, ak = module.users.create('storage A')
        b, bk = module.users.create('storage B')
        module.store.write_media('owned.png', b'123', a['id'])
        async def check():
            response = await Client(module.app, ak).request('GET', '/v1/storage')
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.json()['bytes'], 3)
            other = await Client(module.app, bk).request('GET', '/v1/storage')
            self.assertEqual(other.json()['bytes'], 0)
        asyncio.run(check())


class RateTests(unittest.TestCase):
    def test_owner_isolation_boundary_and_retry_after(self):
        from protection import RequestLimiter
        limiter = RequestLimiter()
        self.assertEqual(limiter.admit('A', 2, 60, now=0), 0)
        self.assertEqual(limiter.admit('A', 2, 60, now=1), 0)
        self.assertEqual(limiter.admit('A', 2, 60, now=2), 58)
        self.assertEqual(limiter.admit('B', 2, 60, now=2), 0)
        self.assertEqual(limiter.admit('A', 2, 60, now=60), 0)


if __name__ == '__main__':
    unittest.main()
