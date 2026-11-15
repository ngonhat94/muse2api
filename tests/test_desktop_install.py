"""Installer safety/rollback/lease tests; no downloads or real engine builds."""
import contextlib
import importlib.util
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('desktop_install', ROOT / 'desktop/install.py')
setup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(setup)

class DesktopInstallTests(unittest.TestCase):
    def setUp(self):
        setup._cancelled.clear()
        setup._child = None

    def test_only_whitelisted_sources_are_copied(self):
        with tempfile.TemporaryDirectory() as source, tempfile.TemporaryDirectory() as target:
            source = Path(source); target = Path(target)
            for name in setup.SOURCES:
                p = source / name; p.parent.mkdir(parents=True, exist_ok=True); p.write_text('source fixture')
            (source/'.env').write_text('sensitive-fixture')
            (source/'data').mkdir(); (source/'data/accounts.json').write_text('sensitive-fixture')
            with patch.object(setup, 'ROOT', source): setup.copy_sources(target)
            self.assertEqual({str(p.relative_to(target)) for p in target.rglob('*') if p.is_file()}, set(setup.SOURCES))
            self.assertFalse((target/'.env').exists()); self.assertFalse((target/'data').exists())

    def test_success_publishes_new_runtime_and_removes_previous(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); staged = root/'staged'; current = root/'current'
            staged.mkdir(); current.mkdir()
            (staged/'engine').write_text('new'); (current/'engine').write_text('old')
            setup.publish_runtime(staged, current)
            self.assertEqual((current/'engine').read_text(), 'new')
            self.assertFalse((root/'previous').exists())

    def test_failed_publish_restores_previous_runtime(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary); staged = root/'staged'; current = root/'current'
            staged.mkdir(); current.mkdir(); (current/'engine').write_text('old')
            rename = Path.rename
            def fail_publish(path, target):
                if path == staged: raise OSError('fixture failure')
                return rename(path, target)
            with patch.object(Path, 'rename', fail_publish), self.assertRaises(OSError):
                setup.publish_runtime(staged, current)
            self.assertEqual((current/'engine').read_text(), 'old')

    def test_cancel_before_publish_leaves_existing_runtime_untouched(self):
        with tempfile.TemporaryDirectory() as temporary:
            current = Path(temporary)/'current'; current.mkdir(); (current/'engine').write_text('old')
            def step(command, stage, **kwargs):
                if stage == 'verifying': setup._cancelled.set()
            with patch.object(setup, 'run_step', side_effect=step), contextlib.redirect_stdout(io.StringIO()):
                with self.assertRaises(setup.SetupError) as caught: setup.install(current)
            self.assertEqual(caught.exception.code, 'cancelled')
            self.assertEqual((current/'engine').read_text(), 'old')

    def test_cancelled_setup_does_not_spawn_another_child(self):
        setup._cancelled.set()
        with patch.object(setup.subprocess, 'Popen') as spawn, self.assertRaises(setup.SetupError):
            setup.run_step(['fixture'], 'browser')
        spawn.assert_not_called()

    @unittest.skipIf(setup.os.name == 'nt', 'Unix process-group assertion')
    def test_cancel_terminates_the_download_build_process_group(self):
        child = Mock(pid=54321); child.poll.return_value = None
        with patch.object(setup.os, 'killpg') as kill:
            setup.terminate_child(child)
        kill.assert_called_once_with(54321, setup.signal.SIGKILL)

    def test_only_one_setup_uses_a_destination_at_a_time(self):
        with tempfile.TemporaryDirectory() as temporary:
            with setup.setup_lock(Path(temporary)):
                with self.assertRaises(setup.SetupError) as caught:
                    with setup.setup_lock(Path(temporary)): pass
                self.assertEqual(caught.exception.code, 'install_busy')

if __name__ == '__main__':
    unittest.main()
