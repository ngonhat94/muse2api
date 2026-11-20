"""Synthetic-only operational tooling acceptance. Run with run_backend_offline.py."""
import io
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import operations as ops
from protection import AccountCipher


class PreflightTests(unittest.TestCase):
    def test_offline_guard_rejects_unmocked_network(self):
        import socket
        with self.assertRaisesRegex(AssertionError, 'EXTERNAL IO FORBIDDEN'):
            socket.getaddrinfo('example.invalid', 443)
        with socket.socket() as conn:
            with self.assertRaisesRegex(AssertionError, 'EXTERNAL IO FORBIDDEN'):
                conn.connect(('127.0.0.1', 9))

    def test_preflight_is_read_only_and_does_not_inspect_accounts_by_default(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            secret = b'not-json-RAW-COOKIE'
            (root / 'accounts.json').write_bytes(secret)
            before = {p.name: p.read_bytes() for p in root.iterdir()}
            with patch.object(ops, 'read_file', side_effect=AssertionError('private read')):
                report = ops.preflight(root, min_free=1)
            self.assertEqual(before, {p.name: p.read_bytes() for p in root.iterdir()})
            self.assertNotIn('RAW-COOKIE', json.dumps(report))
            self.assertTrue(any(c['name'] == 'accounts' and c['status'] == 'warn' for c in report['checks']))
            self.assertIn(report['exit_code'], (0, 1, 2))


class BackupTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.data = self.root / 'data'
        self.data.mkdir(mode=0o700)
        values = {'accounts.json': AccountCipher().encode([{'id':'a', 'owner_id':'u', 'cookies':{'hatch_sess':'SYNTHETIC-COOKIE'}}]),
                  'users.json':[{'id':'u','key_hash':'synthetic'}], 'tasks.json':{'t':{'owner_id':'u'}},
                  'media-index.json':{'x.png':{'owner_id':'u'}}}
        for name, value in values.items():
            (self.data/name).write_text(json.dumps(value))
        (self.data/'media-index.json.ownership-migrated').write_text('1\n')
        (self.data/'.tenant-runtime.lock').touch(mode=0o600)
        (self.data/'media').mkdir(mode=0o700)
        (self.data/'media'/'x.png').write_bytes(b'synthetic image')
        self.archive = self.root/'backup.enc'

    def test_source_directory_replacement_cannot_switch_snapshot(self):
        real_lock = ops.runtime_lock
        from contextlib import contextmanager
        @contextmanager
        def swapped(directory):
            with real_lock(directory) as fd:
                self.data.rename(self.root/'original')
                self.data.mkdir(mode=0o700)
                for name in ops.REQUIRED:
                    (self.data/name).write_bytes((self.root/'original'/name).read_bytes())
                (self.data/'tasks.json').write_text('{"evil":{"owner_id":"admin"}}')
                yield fd
        with patch.object(ops, 'runtime_lock', swapped):
            ops.backup(self.data, self.archive, apply=True)
        _, files = ops._load(self.archive)
        self.assertEqual(json.loads(files['tasks.json']), {'t':{'owner_id':'u'}})

    def test_running_runtime_refuses_without_output(self):
        with ops.runtime_lock(self.data):
            with self.assertRaises((OSError, ValueError)):
                ops.backup(self.data, self.archive, apply=True)
        self.assertFalse(self.archive.exists())

    def test_wrong_missing_key_and_corruption_fail_closed(self):
        from cryptography.fernet import Fernet
        ops.backup(self.data, self.archive, apply=True)
        raw = self.archive.read_bytes()
        for env in ({'MUSE2API_COOKIE_KEY':Fernet.generate_key().decode()}, {'MUSE2API_COOKIE_KEY':''}):
            with patch.dict(os.environ, env):
                with self.assertRaises(ValueError):
                    ops.restore(self.archive, self.root/'new', apply=True)
        self.archive.write_bytes(raw[:-8] + b'corrupt!')
        with self.assertRaises(ValueError):
            ops.verify(self.archive)
        self.assertFalse((self.root/'new').exists())

    def test_source_links_and_missing_metadata_refused(self):
        target = self.data/'tasks.json'
        raw = target.read_bytes()
        for kind in ('symlink','hardlink','missing'):
            target.unlink()
            outside = self.root/'outside'
            outside.write_bytes(raw)
            if kind == 'symlink':
                target.symlink_to(outside)
            elif kind == 'hardlink':
                os.link(outside, target)
            with self.assertRaises((ValueError,OSError)):
                ops.backup(self.data, self.archive, apply=True)
            self.assertFalse(self.archive.exists())
            if target.is_symlink() or target.exists():
                target.unlink()
            outside.unlink()
            target.write_bytes(raw)

    def test_malicious_manifests_refused_without_extraction(self):
        import copy
        ops.backup(self.data, self.archive, include_media=True, apply=True)
        packet, _ = ops._load(self.archive)
        variants = []
        for path in ('../escape','/absolute','media/../escape','media/a/b.png','media/../../evil.png','media/a\\b.png'):
            p = copy.deepcopy(packet)
            p['files'][0]['path'] = path
            variants.append(p)
        p = copy.deepcopy(packet); p['files'].append(p['files'][0]); variants.append(p)
        p = copy.deepcopy(packet); p['files'][0]['size'] = ops.LIMIT+1; variants.append(p)
        p = copy.deepcopy(packet); p['files'][0]['sha256'] = '0'*64; variants.append(p)
        p = copy.deepcopy(packet); p['files'][0]['type'] = 'symlink'; variants.append(p)
        p = copy.deepcopy(packet); p['files'][0]['type'] = 'hardlink'; variants.append(p)
        p = copy.deepcopy(packet); p['schema'] = 2; variants.append(p)
        p = copy.deepcopy(packet); p['files'].pop(); variants.append(p)
        for p in variants:
            with self.subTest(manifest=p['schema']):
                self.archive.write_bytes(AccountCipher().cipher.encrypt(json.dumps(p).encode()))
                with self.assertRaises(ValueError):
                    ops.restore(self.archive, self.root/'new', apply=True)
                self.assertFalse((self.root/'new').exists())
        for raw in (b'PK\x03\x04zip-bomb', b'ustar tar-link', b'x' * 200):
            self.archive.write_bytes(raw)
            with self.assertRaises(ValueError): ops.verify(self.archive)

    def test_unknown_ownership_and_unindexed_media_refused(self):
        (self.data/'tasks.json').write_text('{"t":{"owner_id":"unknown"}}')
        with self.assertRaises(ValueError): ops.backup(self.data, self.archive, apply=True)
        (self.data/'tasks.json').write_text('{}')
        (self.data/'media'/'unknown.png').write_bytes(b'x')
        with self.assertRaises(ValueError): ops.backup(self.data, self.archive, include_media=True, apply=True)

    def test_permission_limits_and_cleanup_fail_closed(self):
        self.root.chmod(0o755)
        with self.assertRaises(ValueError): ops.backup(self.data, self.archive, apply=True)
        self.root.chmod(0o700)
        with patch.object(ops, 'LIMIT', 1):
            with self.assertRaises(ValueError): ops.backup(self.data, self.archive, apply=True)
        ops.backup(self.data, self.archive, apply=True)
        dest = self.root/'new'
        with patch.object(ops, '_rename_new', side_effect=OSError('injected')):
            with self.assertRaises(OSError): ops.restore(self.archive, dest, apply=True)
        self.assertFalse(dest.exists())
        self.assertEqual(list(self.root.glob('.restore-*')), [])

    def test_publication_race_does_not_overwrite_competitor(self):
        ops.backup(self.data, self.archive, apply=True)
        dest = self.root/'new'
        real = ops._rename_new
        def compete(parent, stage, target):
            dest.mkdir()
            (dest/'sentinel').write_bytes(b'competitor')
            real(parent, stage, target)
        with patch.object(ops, '_rename_new', compete):
            with self.assertRaises(OSError): ops.restore(self.archive, dest, apply=True)
        self.assertEqual((dest/'sentinel').read_bytes(), b'competitor')
        self.assertEqual(list(self.root.glob('.restore-*')), [])

    def test_preflight_key_disk_worker_migration_and_paths(self):
        report = ops.preflight(self.data, min_free=1, inspect_accounts=True)
        checks = {c['name']:c['status'] for c in report['checks']}
        self.assertEqual(checks['accounts'], 'pass')
        self.assertEqual(checks['key'], 'pass')
        self.assertNotIn('SYNTHETIC-COOKIE', json.dumps(report))
        (self.data/'accounts.json').write_text('[]')
        report = ops.preflight(self.data, min_free=10**30, inspect_accounts=True)
        checks = {c['name']:c['status'] for c in report['checks']}
        self.assertEqual(checks['accounts'], 'block')
        self.assertEqual(checks['disk'], 'block')
        with patch.dict(os.environ, {'MUSE2API_COOKIE_KEY':'invalid', 'WEB_CONCURRENCY':'2'}):
            report = ops.preflight(self.data, min_free=1)
            checks = {c['name']:c['status'] for c in report['checks']}
            self.assertEqual(checks['key'], 'block')
            self.assertEqual(checks['workers'], 'block')
            self.assertEqual(report['exit_code'], 2)
        link = self.root/'linked'; link.symlink_to(self.data)
        checks = {c['name']:c['status'] for c in ops.preflight(link)['checks']}
        self.assertEqual(checks['directory'], 'block')

    def test_external_key_inside_snapshot_source_is_never_bundled(self):
        key = os.environ['MUSE2API_COOKIE_KEY']
        (self.data/'users.json').write_text(key)
        with patch.dict(os.environ, {'MUSE2API_COOKIE_KEY':'', 'MUSE2API_COOKIE_KEY_FILE':str(self.data/'users.json')}):
            (self.data/'users.json').chmod(0o600)
            with self.assertRaises(ValueError):
                ops.backup(self.data, self.archive, apply=True)
        self.assertFalse(self.archive.exists())

    def test_key_file_symlink_parent_is_blocked(self):
        keys = self.root/'keys'; keys.mkdir(mode=0o700)
        key = keys/'secret'; key.write_text(os.environ['MUSE2API_COOKIE_KEY']); key.chmod(0o600)
        alias = self.root/'alias'; alias.symlink_to(keys)
        with patch.dict(os.environ, {'MUSE2API_COOKIE_KEY':'', 'MUSE2API_COOKIE_KEY_FILE':str(alias/'secret')}):
            checks = {c['name']:c['status'] for c in ops.preflight(self.data)['checks']}
        self.assertEqual(checks['key'], 'block')

    def test_missing_admin_config_blocks_and_no_dotenv_is_loaded(self):
        (self.data/'.env').write_text('MUSE2API_KEY=do-not-load')
        with patch.dict(os.environ, {'MUSE2API_KEY':''}):
            report = ops.preflight(self.data, min_free=1)
        checks = {c['name']:c['status'] for c in report['checks']}
        self.assertEqual(checks.get('admin_config'), 'block')
        self.assertNotIn('do-not-load', json.dumps(report))

    def test_deeply_nested_snapshot_has_safe_cli_failure(self):
        import contextlib
        raw = b'['*2000 + b'0' + b']'*2000
        self.archive.write_bytes(AccountCipher().cipher.encrypt(raw))
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = ops.main(['verify', str(self.archive), '--json'])
        self.assertEqual(code, 2)
        self.assertEqual(json.loads(out.getvalue())['status'], 'block')

    def test_cli_safe_output_and_preview(self):
        import contextlib
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = ops.main(['preflight', str(self.data), '--json', '--inspect-accounts', '--min-free-bytes','1'])
        self.assertEqual(code, 1)
        self.assertNotIn('SYNTHETIC-COOKIE', out.getvalue())
        self.assertEqual(json.loads(out.getvalue())['exit_code'], 1)
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.assertEqual(ops.main(['backup', str(self.data), str(self.archive), '--json']), 0)
        self.assertFalse(self.archive.exists())
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.assertEqual(ops.main(['verify', str(self.archive), '--json']), 2)
        self.assertNotIn(str(self.archive), out.getvalue())

    def test_encrypted_snapshot_preview_verify_restore_roundtrip(self):
        original = (self.data/'accounts.json').read_bytes()
        self.assertEqual(ops.backup(self.data, self.archive, include_media=True)['action'], 'preview')
        self.assertFalse(self.archive.exists())
        ops.backup(self.data, self.archive, include_media=True, apply=True)
        self.assertNotIn(b'SYNTHETIC', self.archive.read_bytes())
        self.assertEqual(self.archive.stat().st_mode & 0o777, 0o600)
        report = ops.verify(self.archive)
        self.assertEqual(report['files'], 6)
        dest = self.root/'restored'
        self.assertEqual(ops.restore(self.archive, dest)['action'], 'preview')
        self.assertFalse(dest.exists())
        ops.restore(self.archive, dest, apply=True)
        self.assertEqual((dest/'accounts.json').read_bytes(), original)
        self.assertEqual((dest/'media'/'x.png').read_bytes(), b'synthetic image')
        self.assertEqual(dest.stat().st_mode & 0o777, 0o700)
        with self.assertRaises((ValueError, FileExistsError)):
            ops.restore(self.archive, dest, apply=True)


if __name__ == '__main__':
    unittest.main()
