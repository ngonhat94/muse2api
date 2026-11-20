"""Host release boundary tests without Docker or network."""
import fcntl
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('release', Path(__file__).resolve().parents[1] / 'deploy/instabox_release.py')
assert SPEC and SPEC.loader
release = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(release)

class ReleaseSafety(unittest.TestCase):
    def test_current_upload_cleaned_on_success_and_failure(self):
        for fail in (False, True):
            with tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                (root / 'uploads').mkdir()
                upload = root / 'uploads' / ('a' * 40 + '.tar.gz')
                other = root / 'uploads' / ('b' * 40 + '.tar.gz')
                upload.touch(); other.touch()
                with patch.object(release, '_rollout', side_effect=RuntimeError('synthetic') if fail else None):
                    if fail:
                        with self.assertRaises(RuntimeError):
                            release.release(root, 'test-service', 'a' * 40, upload, 18610, '')
                    else:
                        release.release(root, 'test-service', 'a' * 40, upload, 18610, '')
                self.assertFalse(upload.exists()); self.assertTrue(other.exists())

    def test_lock_prevents_parallel_mutation(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'uploads').mkdir()
            upload = root / 'uploads' / ('a' * 40 + '.tar.gz'); upload.touch()
            with (root / '.deploy.lock').open('a') as lock, patch.object(release, '_rollout') as rollout:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                with self.assertRaises(BlockingIOError):
                    release.release(root, 'test-service', 'a' * 40, upload, 18610, '')
                rollout.assert_not_called()
                self.assertTrue(upload.exists())

    def test_foreign_path_and_invalid_sha_rejected(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(release, '_rollout') as rollout:
            root = Path(directory); other = root / 'untouched'; other.touch()
            with self.assertRaises(ValueError):
                release.release(root, 'test-service', 'a' * 40, other, 18610, '')
            with self.assertRaises(ValueError):
                release.release(root, 'test-service', 'not-a-sha', other, 18610, '')
            rollout.assert_not_called(); self.assertTrue(other.exists())

if __name__ == '__main__':
    unittest.main()
