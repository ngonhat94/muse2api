"""Offline filesystem and Docker-boundary retention regressions."""
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('remote', ROOT / 'tools/deploy_remote.py')
assert spec is not None and spec.loader is not None
remote = importlib.util.module_from_spec(spec)
spec.loader.exec_module(remote)
ATTEMPT = 'a'*40 + '-' + 'b'*32


class RetentionTests(unittest.TestCase):
    def test_owned_upload_cleanup_removes_only_fixed_artifacts(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'incoming').mkdir(mode=0o700)
            release = root / 'incoming' / ATTEMPT
            release.mkdir(mode=0o700)
            for name in ('.retention-owner', '.lease', 'image.tar', 'compose.yml', 'deploy_remote.py'):
                (release / name).write_text(remote.CONTRACT if name == '.retention-owner' else '')
                (release / name).chmod(0o600)
            remote.cleanup_upload(root, ATTEMPT)
            self.assertFalse(release.exists())


    def test_session_failure_cleans_partial_upload(self):
        import io
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); (root / 'incoming').mkdir(mode=0o700)
            with patch.object(remote, 'prepare'), patch.object(remote, 'legacy_guard'), patch.object(remote, 'disk_preflight'), patch.object(remote.sys, 'stdin', type('Input', (), {'buffer': io.BytesIO(b'partial')})()):
                with self.assertRaisesRegex(ValueError, 'incomplete'):
                    remote.receive(root, 'a'*40, 'sha256:'+'b'*64, '1.6.10', [20, 0, 0], ATTEMPT)
            self.assertEqual(list((root / 'incoming').iterdir()), [])

    def test_receive_success_and_deploy_failure_both_clean_owned_files(self):
        import io
        for failed in (False, True):
            with self.subTest(failed=failed), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp); (root / 'incoming').mkdir(mode=0o700)
                preserved = root / 'incoming' / ('c'*40); preserved.mkdir()
                (preserved / 'image.tar').write_bytes(b'old-unmarked')
                def deploy(*args):
                    self.assertEqual((root / 'incoming' / ATTEMPT / 'image.tar').read_bytes(), b'archive')
                    if failed: raise remote.DeploymentError('synthetic failed health')
                with patch.object(remote, 'prepare'), patch.object(remote, 'legacy_guard'), patch.object(remote, 'disk_preflight'), patch.object(remote, 'deploy', side_effect=deploy), patch.object(remote.sys, 'stdin', type('Input', (), {'buffer': io.BytesIO(b'archivecomposesource')})()):
                    if failed:
                        with self.assertRaises(remote.DeploymentError):
                            remote.receive(root, 'a'*40, 'sha256:'+'b'*64, '1.6.10', [7, 7, 6], ATTEMPT)
                    else:
                        remote.receive(root, 'a'*40, 'sha256:'+'b'*64, '1.6.10', [7, 7, 6], ATTEMPT)
                self.assertFalse((root / 'incoming' / ATTEMPT).exists())
                self.assertEqual((preserved / 'image.tar').read_bytes(), b'old-unmarked')

    def test_disk_preflight_checks_separate_and_shared_filesystems(self):
        from types import SimpleNamespace
        with patch.object(remote, 'run', return_value='/docker'), patch.object(remote.os, 'statvfs', return_value=SimpleNamespace(f_bavail=1, f_frsize=1)), patch.object(remote.os, 'stat', return_value=SimpleNamespace(st_dev=1)):
            with self.assertRaisesRegex(remote.DeploymentError, 'required.*available'):
                remote.disk_preflight(Path('/data'), 100)

    def test_prune_only_owned_unused_images_and_never_force(self):
        ids = ['sha256:' + c*64 for c in 'bcdef']
        labels = {'org.muse2api.storage-contract': remote.CONTRACT,
                  'org.opencontainers.image.revision': 'a'*40}
        removed = []
        def run(*args, **kwargs):
            if args[1:3] == ('image', 'ls'):
                return '\n'.join(ids)
            if args[1:3] == ('image', 'inspect'):
                i = args[3]
                return json.dumps([{'Id': i, 'RepoTags': ['muse2api-ci:check'] if i != ids[4] else ['other:latest'],
                                    'Config': {'Labels': labels}}])
            if args[1] == 'ps':
                return 'container'
            if args[1] == 'inspect':
                return json.dumps([{'Image': ids[1]}])
            if args[1:3] == ('image', 'rm'):
                removed.append(args[3]); return ''
            raise AssertionError(args)
        with patch.object(remote, 'run', side_effect=run):
            remote.prune_images({ids[0]})
        self.assertEqual(removed, ids[2:4])

    def test_cleanup_refuses_unknown_symlink_recent_and_locked(self):
        import fcntl
        for case in ('unknown', 'symlink', 'recent', 'locked', 'traversal', 'old'):
            with self.subTest(case=case), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp); (root / 'incoming').mkdir(mode=0o700)
                release = root / 'incoming' / ATTEMPT; release.mkdir(mode=0o700)
                for name in ('.retention-owner', '.lease', 'image.tar'):
                    p = release / name; p.write_text(remote.CONTRACT if name == '.retention-owner' else ''); p.chmod(0o600)
                if case == 'unknown': (release / 'data').mkdir()
                if case == 'symlink':
                    (release / 'image.tar').unlink(); (release / 'image.tar').symlink_to(root / 'preserve')
                if case in ('old', 'locked'): os.utime(release / '.lease', (1, 1))
                with (release / '.lease').open() as lease:
                    if case == 'locked': fcntl.flock(lease, fcntl.LOCK_EX)
                    result = remote.cleanup_upload(root, '../escape' if case == 'traversal' else ATTEMPT, stale=True)
                self.assertEqual(result, case == 'old')
                self.assertEqual(release.exists(), case != 'old')

if __name__ == '__main__':
    unittest.main()
