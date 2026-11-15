"""Bundled runtime validation and developer startup, without downloads/builds."""
import contextlib
import io
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import build_desktop as build
import run_desktop as runner

class DesktopBuildTests(unittest.TestCase):
    def test_setup_includes_security_modules(self):
        self.assertIn('tenant.py', build.ENGINE_SOURCES)
        self.assertIn('protection.py', build.ENGINE_SOURCES)

    def make_bundle(self, directory):
        executable = directory / ('muse_engine.exe' if os.name == 'nt' else 'muse_engine')
        executable.write_bytes(b'fixture'); executable.chmod(0o700)
        browser = directory / 'browser/chrome'
        browser.parent.mkdir(); browser.touch()
        (directory/'browser.json').write_text(json.dumps({'executable': 'browser/chrome'}))
        (directory/'engine-build.json').write_text(json.dumps({
            'source': build.source_fingerprint(), 'system': platform.system(), 'machine': platform.machine(),
        }))
        return executable, browser

    def test_bundle_rejects_missing_browser_stale_code_wrong_platform_and_escape(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            self.assertFalse(build.engine_bundle_ready(directory))
            _, browser = self.make_bundle(directory)
            self.assertTrue(build.engine_bundle_ready(directory))
            browser.unlink(); self.assertFalse(build.engine_bundle_ready(directory)); browser.touch()
            record = json.loads((directory/'engine-build.json').read_text())
            for field in ['source', 'system', 'machine']:
                (directory/'engine-build.json').write_text(json.dumps(dict(record, **{field: 'different'})))
                self.assertFalse(build.engine_bundle_ready(directory))
            (directory/'engine-build.json').write_text(json.dumps(record))
            (directory/'browser.json').write_text(json.dumps({'executable': '../outside'}))
            self.assertFalse(build.engine_bundle_ready(directory))

    def test_developer_run_prepares_before_starting_flutter_and_injects_exact_path(self):
        events = []
        with tempfile.TemporaryDirectory() as temporary, patch.object(runner, 'ROOT', Path(temporary)), \
             patch.object(runner, 'engine_bundle_ready', side_effect=[False, True]), \
             patch.object(runner, 'run', side_effect=lambda args: events.append(('prepare', args))), \
             patch.object(runner.subprocess, 'run', side_effect=lambda args, **kw: events.append(('flutter', args))), \
             contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(runner.main(['--flutter', '/fixture/flutter']), 0)
            self.assertEqual(len(events), 4)
            self.assertIn('--engine-only', events[2][1])
            self.assertEqual(events[-1][0], 'flutter')
            args = events[-1][1]
            self.assertEqual(args[0], '/fixture/flutter')
            self.assertTrue(any(str(arg).startswith('--dart-define=MUSE_ENGINE_PATH=') for arg in args))

    def test_failed_preparation_never_launches_flutter(self):
        with patch.object(runner, 'engine_bundle_ready', return_value=False), \
             patch.object(runner, 'run', side_effect=subprocess.CalledProcessError(1, ['fixture'])), \
             patch.object(runner.subprocess, 'run') as flutter, \
             contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(runner.main([]), 1)
            flutter.assert_not_called()

    def test_valid_existing_bundle_is_reused_without_package_install(self):
        with patch.object(runner, 'engine_bundle_ready', return_value=True), \
             patch.object(runner, 'run') as prepare, patch.object(runner.subprocess, 'run') as flutter, \
             contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(runner.main(['--prepare-only']), 0)
            prepare.assert_not_called(); flutter.assert_not_called()

if __name__ == '__main__':
    unittest.main()
