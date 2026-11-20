"""Desktop bootstrap/packaging contract, with no Muse calls or credentials."""
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('desktop_launcher', ROOT / 'desktop/launcher.py')
launcher = importlib.util.module_from_spec(spec)
spec.loader.exec_module(launcher)

class DesktopLauncherTests(unittest.TestCase):
    def test_bootstrap_isolates_data_and_overrides_inherited_server_key(self):
        with tempfile.TemporaryDirectory() as temporary, patch.dict(os.environ, {'MUSE2API_KEY': 'other-key', 'MUSE2API_HOME': '/other'}):
            old_mask = os.umask(0o077)
            try:
                data = Path(temporary) / 'engine'
                directory, key = launcher.bootstrap(json.dumps({'data_dir': str(data), 'api_key': 'fixture-' * 8}))
                self.assertEqual(directory, data)
                self.assertEqual(os.environ['MUSE2API_HOME'], str(data))
                self.assertEqual(os.environ['MUSE2API_KEY'], key)
                self.assertEqual(os.environ['MUSE2API_PROFILE_ROOT'], str(data / 'profiles'))
                self.assertEqual(os.environ['MUSE2API_HOST'], '127.0.0.1')
                self.assertEqual(os.environ['MUSE2API_DESKTOP'], '1')
                self.assertEqual(list(data.iterdir()), [])
                if os.name != 'nt':
                    self.assertEqual(data.stat().st_mode & 0o777, 0o700)
            finally:
                os.umask(old_mask)

    def test_invalid_bootstrap_rejected_without_writing(self):
        for value in [{}, {'api_key': 'x', 'data_dir': '/tmp/unused'}, {'api_key': 'x'*32, 'data_dir': 'relative'}]:
            with self.assertRaises((ValueError, KeyError)):
                launcher.bootstrap(json.dumps(value))

    def test_browser_resolves_from_bundle_and_rejects_escape_or_missing_binary(self):
        with tempfile.TemporaryDirectory() as temporary, patch.object(launcher.sys, '_MEIPASS', temporary, create=True):
            root = Path(temporary)
            executable = root / 'browser/chrome'
            executable.parent.mkdir(); executable.touch()
            (root/'browser.json').write_text(json.dumps({'executable': 'browser/chrome'}))
            self.assertEqual(launcher.browser_path(), executable)
            for value in ['../chrome', '/tmp/chrome', 'browser/missing']:
                (root/'browser.json').write_text(json.dumps({'executable': value}))
                with self.assertRaises((ValueError, FileNotFoundError)):
                    launcher.browser_path()

    @unittest.skipIf(os.name == 'nt', 'Unix advisory locking test')
    def test_same_data_directory_cannot_be_opened_by_two_engines(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            with launcher.instance_lock(directory):
                with self.assertRaises(OSError):
                    with launcher.instance_lock(directory):
                        self.fail('second lock acquired')
            with launcher.instance_lock(directory):
                pass

    def test_failed_startup_never_prints_input_or_exception_secrets(self):
        output = io.StringIO()
        with patch.object(launcher.sys, 'stdin', io.StringIO('bad-sensitive-fixture')), contextlib.redirect_stdout(output):
            self.assertEqual(launcher.main(), 1)
        self.assertEqual(json.loads(output.getvalue()), {'event': 'error', 'code': 'startup_failed'})
        self.assertNotIn('sensitive', output.getvalue())

    def test_startup_protocol_classifies_known_failures_without_exception_payloads(self):
        cases = [
            ('storage_denied', 'bootstrap', PermissionError('sensitive-fixture')),
            ('browser_missing', 'browser_path', FileNotFoundError('sensitive-fixture')),
            ('engine_in_use', 'instance_lock', launcher.EngineInUseError('sensitive-fixture')),
        ]
        for code, method, failure in cases:
            with self.subTest(code=code), contextlib.ExitStack() as stack:
                output = io.StringIO()
                stack.enter_context(patch.object(launcher.sys, 'stdin', io.StringIO('fixture')))
                stack.enter_context(patch.object(launcher, 'bootstrap', return_value=(Path('/fixture'), 'fixture-key')))
                stack.enter_context(patch.object(launcher, 'browser_path', return_value=Path('/fixture/browser')))
                stack.enter_context(patch.object(launcher, 'instance_lock', return_value=contextlib.nullcontext()))
                stack.enter_context(patch.object(launcher, method, side_effect=failure))
                stack.enter_context(contextlib.redirect_stdout(output))
                stack.enter_context(patch.dict(os.environ))
                self.assertEqual(launcher.main(), 1)
                self.assertEqual(json.loads(output.getvalue()), {'event': 'error', 'code': code})
                self.assertNotIn('sensitive-fixture', output.getvalue())

if __name__ == '__main__':
    unittest.main()
