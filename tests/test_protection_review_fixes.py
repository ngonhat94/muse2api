"""Offline regression tests for independent protection review."""
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from config import Config
from store import Store


class ProtectionReviewTests(unittest.TestCase):
    def test_dangling_account_symlink_is_not_new_store(self):
        with tempfile.TemporaryDirectory() as home:
            cfg = Config(base_dir=home)
            Path(cfg.data_dir).mkdir(parents=True)
            Path(cfg.accounts_file).symlink_to(Path(home) / 'missing')
            with self.assertRaisesRegex(ValueError, 'account store'):
                Store(cfg)

    def test_parent_symlink_cannot_escape_write_or_retention(self):
        for operation in ('write', 'retention'):
            with self.subTest(operation=operation), tempfile.TemporaryDirectory() as home:
                cfg = Config(base_dir=home)
                store = Store(cfg)
                store.write_media('old.png', b'owned', 'A')
                store.media['old.png']['created_at'] = 1
                media = Path(cfg.media_dir)
                parked = media.with_name('parked')
                media.rename(parked)
                outside = Path(home) / 'outside'
                outside.mkdir()
                (outside / 'old.png').write_bytes(b'outside')
                media.symlink_to(outside, target_is_directory=True)
                with self.assertRaises((ValueError, OSError)):
                    if operation == 'write':
                        store.write_media('new.png', b'escape', 'A')
                    else:
                        store.retention('A', dry_run=False, now=4000000)
                self.assertFalse((outside / 'new.png').exists())
                self.assertEqual((outside / 'old.png').read_bytes(), b'outside')

    def test_capability_media_rejects_leaf_swap_and_streams_open_inode(self):
        import asyncio
        import app
        from starlette.exceptions import HTTPException
        with tempfile.TemporaryDirectory() as home:
            local_store = Store(Config(base_dir=home))
            local_store.write_media('safe.png', b'original', 'A')
            leaf = Path(local_store.cfg.media_dir) / 'safe.png'
            outside = Path(home) / 'secret'
            outside.write_bytes(b'private')
            with patch.object(app, 'store', local_store), patch.object(app, '_verify_media_capability'):
                leaf.unlink()
                leaf.symlink_to(outside)
                with self.assertRaises(HTTPException):
                    app.get_media('safe.png', 'synthetic-valid-cap')
                leaf.unlink()
                leaf.write_bytes(b'original')
                response = app.get_media('safe.png', 'synthetic-valid-cap')
                leaf.unlink()
                leaf.symlink_to(outside)
                async def consume():
                    return b''.join([chunk async for chunk in response.body_iterator])
                self.assertEqual(asyncio.run(consume()), b'original')

    def test_browser_fallback_uses_owner_limit_above_and_below_default(self):
        import time
        from engine import MuseEngine
        from protection import StorageQuotaExceeded
        for owner_limit, size in ((8, 6), (2, 3)):
            with self.subTest(owner_limit=owner_limit), tempfile.TemporaryDirectory() as home:
                store = Store(Config(base_dir=home))
                store.limit_provider = lambda owner: {'storage_bytes': owner_limit}
                engine = MuseEngine(store.cfg)
                engine.media_writer = store.write_media
                engine.media_limits = store.storage_limits
                engine._ensure_local().media_owner = 'A'
                source = Path(home) / 'download.png'
                source.write_bytes(b'x' * size)
                with patch.dict(os.environ, {'MUSE2API_STORAGE_BYTES': '4'}), \
                     patch.object(engine, 'attachments', return_value=[]), \
                     patch.object(engine, '_agent_count', return_value=0), \
                     patch.object(engine, '_send', return_value='clicked'), \
                     patch.object(engine, '_wait_attachment', return_value={'src': 'synthetic'}), \
                     patch.object(engine, 'extract_bytes', return_value=(None, None, None)), \
                     patch.object(engine, '_download_fallback', return_value=str(source)):
                    if size > owner_limit:
                        with self.assertRaises(StorageQuotaExceeded):
                            engine._generate_attached('test', 'image', time.monotonic() + 5, None, None, set())
                    else:
                        result = engine._generate_attached('test', 'image', time.monotonic() + 5, None, None, set())
                        self.assertEqual(result['size'], size)
                self.assertFalse(source.exists())

    def test_import_refuses_busy_runtime_before_store_initialization(self):
        import fcntl
        import importlib.util
        import sys
        import config
        with tempfile.TemporaryDirectory() as home:
            cfg = Config(base_dir=home)
            cfg.ensure_dirs()
            with open(Path(cfg.data_dir) / '.tenant-runtime.lock', 'a+') as lock:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                spec = importlib.util.spec_from_file_location('busy_review_app', Path(__file__).resolve().parents[1] / 'app.py')
                module = importlib.util.module_from_spec(spec)
                with patch.object(config, 'CFG', cfg), patch('store.Store') as constructor:
                    sys.modules[spec.name] = module
                    try:
                        with self.assertRaisesRegex(RuntimeError, 'runtime'):
                            spec.loader.exec_module(module)
                        constructor.assert_not_called()
                    finally:
                        sys.modules.pop(spec.name, None)

    def test_state_and_marker_fsync_directory_after_publication(self):
        import stat
        import store as module
        with tempfile.TemporaryDirectory() as home:
            cfg = Config(base_dir=home)
            events = []
            real_fsync, real_replace = os.fsync, os.replace
            def sync(fd):
                events.append('directory' if stat.S_ISDIR(os.fstat(fd).st_mode) else 'file')
                return real_fsync(fd)
            def replace(*args, **kwargs):
                events.append('replace')
                return real_replace(*args, **kwargs)
            with patch('os.fsync', side_effect=sync), patch('os.replace', side_effect=replace):
                Store(cfg)
            self.assertIn('directory', events)
            events.clear()
            with patch('os.fsync', side_effect=sync), patch('os.replace', side_effect=replace):
                module._write(str(Path(home) / 'state.json'), {'value': 1})
            self.assertEqual(events, ['file', 'replace', 'directory'])

    def test_migration_crash_after_marker_does_not_adopt_on_restart(self):
        import store as module
        with tempfile.TemporaryDirectory() as home:
            cfg = Config(base_dir=home)
            cfg.ensure_dirs()
            (Path(cfg.media_dir) / 'legacy.png').write_bytes(b'legacy')
            with patch.object(module, '_write', side_effect=OSError('crash before index publish')):
                with self.assertRaises(OSError):
                    Store(cfg)
            restarted = Store(cfg)
            self.assertIsNone(restarted.media_owner('legacy.png'))
            with self.assertRaises(ValueError):
                restarted.storage_usage('admin')

    def test_directory_sync_failure_reports_uncertain_publication_without_rewrite(self):
        import stat
        import store as module
        with tempfile.TemporaryDirectory() as home:
            path = Path(home) / 'state.json'
            module._write(str(path), {'old': True})
            real_sync = os.fsync
            def sync(fd):
                if stat.S_ISDIR(os.fstat(fd).st_mode):
                    raise OSError('synthetic directory sync failure')
                return real_sync(fd)
            with patch('os.fsync', side_effect=sync):
                with self.assertRaises(OSError):
                    module._write(str(path), {'new': True})
            self.assertEqual(module._read(str(path), None), {'new': True})
            self.assertEqual(sorted(p.name for p in Path(home).iterdir()), ['state.json'])

    def test_implicit_admin_override_explicitly_rejected(self):
        import app
        from fastapi import HTTPException
        with self.assertRaises(HTTPException) as caught:
            app.set_user_limits('admin', app.TenantLimits(storage_bytes=10), {'id': 'admin', 'role': 'admin'})
        self.assertEqual(caught.exception.status_code, 400)
        self.assertIn('environment', caught.exception.detail)

    def test_fallback_quota_http_507_does_not_retry_second_account(self):
        import asyncio
        import app
        import sys
        import time
        from types import SimpleNamespace
        sys.path.insert(0, str(Path(__file__).parent))
        from test_multitenant_security import Client
        user, key = app.users.create('fallback-single-attempt')
        app.users.set_limits(user['id'], {'storage_bytes': 2})
        accounts = [app.store.add_account({'hatch_sess': 'synthetic'}, owner_id=user['id']) for _ in range(2)]
        with tempfile.TemporaryDirectory() as home:
            source = Path(home) / 'fallback.png'
            source.write_bytes(b'123')
            local = SimpleNamespace(media_owner=user['id'])
            def generate(*args, **kwargs):
                return app.engine._generate_attached('test', 'image', time.monotonic() + 5, None, None, set())
            async def request():
                return await Client(app.app, key).request('POST', '/v1/images/generations', {'prompt': 'synthetic'})
            with patch.object(app.ACCOUNT_POOL, 'acquire', side_effect=accounts) as acquire, \
                 patch.object(app.ACCOUNT_POOL, 'release'), \
                 patch.object(app, '_renew_and_persist', return_value=None), \
                 patch.object(app, '_bind_account_proxy'), patch.object(app, '_clear_account_proxy'), \
                 patch.object(app.engine, '_ensure_local', return_value=local), \
                 patch.object(app.engine, 'start'), patch.object(app.engine, 'close_current_page'), \
                 patch.object(app.engine, 'generate', side_effect=generate) as generation, \
                 patch.object(app.engine, 'attachments', return_value=[]), \
                 patch.object(app.engine, '_agent_count', return_value=0), \
                 patch.object(app.engine, '_send', return_value='clicked'), \
                 patch.object(app.engine, '_wait_attachment', return_value={'src': 'synthetic'}), \
                 patch.object(app.engine, 'extract_bytes', return_value=(None, None, None)), \
                 patch.object(app.engine, '_download_fallback', return_value=str(source)):
                response = asyncio.run(request())
                self.assertEqual(response.status_code, 507)
                self.assertEqual(acquire.call_count, 1)
                self.assertEqual(generation.call_count, 1)

    def test_parent_swap_after_accounting_keeps_write_inside_open_directory(self):
        with tempfile.TemporaryDirectory() as home:
            store = Store(Config(base_dir=home))
            media = Path(store.cfg.media_dir)
            media.mkdir(parents=True)
            parked = media.with_name('parked')
            outside = Path(home) / 'outside'
            outside.mkdir()
            usage = store.storage_usage
            def swapped(owner):
                result = usage(owner)
                media.rename(parked)
                media.symlink_to(outside, target_is_directory=True)
                return result
            with patch.object(store, 'storage_usage', side_effect=swapped):
                store.write_media('safe.png', b'owned', 'A')
            self.assertEqual((parked / 'safe.png').read_bytes(), b'owned')
            self.assertFalse((outside / 'safe.png').exists())

    def test_retention_parent_swap_at_unlink_keeps_outside_untouched(self):
        with tempfile.TemporaryDirectory() as home:
            store = Store(Config(base_dir=home))
            store.write_media('old.png', b'owned', 'A')
            store.media['old.png']['created_at'] = 1
            media = Path(store.cfg.media_dir)
            parked = media.with_name('parked')
            outside = Path(home) / 'outside'
            outside.mkdir()
            (outside / 'old.png').write_bytes(b'outside')
            unlink = os.unlink
            swapped = False
            def swap(path, *args, **kwargs):
                nonlocal swapped
                if path == 'old.png' and not swapped:
                    swapped = True
                    media.rename(parked)
                    media.symlink_to(outside, target_is_directory=True)
                return unlink(path, *args, **kwargs)
            with patch('os.unlink', side_effect=swap):
                store.retention('A', dry_run=False, now=4000000)
            self.assertFalse((parked / 'old.png').exists())
            self.assertEqual((outside / 'old.png').read_bytes(), b'outside')

    def test_user_limit_publication_syncs_parent_directory(self):
        import stat
        from tenant import UserStore
        with tempfile.TemporaryDirectory() as home:
            user_store = UserStore(str(Path(home) / 'users.json'))
            user, _ = user_store.create('synthetic')
            synced = []
            real_sync = os.fsync
            def sync(fd):
                synced.append(stat.S_ISDIR(os.fstat(fd).st_mode))
                return real_sync(fd)
            with patch('os.fsync', side_effect=sync):
                user_store.set_limits(user['id'], {'storage_bytes': 10})
            self.assertIn(True, synced)

    def test_key_file_symlink_and_wrong_uid_remain_rejected(self):
        from protection import AccountCipher
        from types import SimpleNamespace
        with tempfile.TemporaryDirectory() as home:
            key = Path(home) / 'key'
            key.write_text('A' * 43 + '=')
            key.chmod(0o600)
            link = Path(home) / 'link'
            link.symlink_to(key)
            with patch.dict(os.environ, {'MUSE2API_COOKIE_KEY': '', 'MUSE2API_COOKIE_KEY_FILE': str(link)}):
                with self.assertRaises(OSError):
                    AccountCipher()
            info = key.stat()
            wrong_owner = SimpleNamespace(st_mode=info.st_mode, st_uid=os.getuid() + 1)
            with patch.dict(os.environ, {'MUSE2API_COOKIE_KEY': '', 'MUSE2API_COOKIE_KEY_FILE': str(key)}), patch('os.fstat', return_value=wrong_owner):
                with self.assertRaises(ValueError):
                    AccountCipher()

if __name__ == '__main__':
    unittest.main()
