"""Synthetic deployment contract; no Docker, SSH or application imports."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch
from contextlib import contextmanager
from types import SimpleNamespace


@contextmanager
def synthetic_deploy_path(module, root):
    """Map only this fixture's lexical path; retain all real filesystem checks.

    Local scratch ancestors may contain dots/spaces forbidden on a real VPS.
    Never patch the shared re module or bypass prepare/private validation.
    """
    real_fullmatch = module.re.fullmatch

    def fullmatch(pattern, value, *args, **kwargs):
        if pattern == r'/[A-Za-z0-9_/-]+' and value == str(root):
            value = '/synthetic/deploy'
        return real_fullmatch(pattern, value, *args, **kwargs)

    with patch.object(module, 're', SimpleNamespace(fullmatch=fullmatch)):
        yield

ROOT = Path(__file__).resolve().parents[1]


class DeployTests(unittest.TestCase):
    def load(self):
        path = ROOT / 'tools/deploy_remote.py'
        self.assertTrue(path.is_file(), 'safe remote deployment implementation missing')
        spec = importlib.util.spec_from_file_location('deploy_remote', path)
        assert spec is not None and spec.loader is not None
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    def test_fixture_mapping_preserves_production_path_and_private_checks(self):
        module = self.load()
        with tempfile.TemporaryDirectory(prefix='deploy.fixture ') as tmp:
            root = self.fixture(tmp)
            with self.assertRaisesRegex(ValueError, 'unsafe deploy path'):
                module.prepare(root)
            original_re = module.re
            with synthetic_deploy_path(module, root):
                module.prepare(root)
                with self.assertRaisesRegex(ValueError, 'unsafe deploy path'):
                    module.prepare(root / 'other.invalid')
                (root / 'config/.env').chmod(0o644)
                with self.assertRaisesRegex(ValueError, 'owner-only'):
                    module.prepare(root)
            self.assertIs(module.re, original_re)
            with self.assertRaisesRegex(ValueError, 'unsafe deploy path'):
                module.prepare(root)

    def test_unprepared_target_fails_before_docker(self):
        module = self.load()
        with tempfile.TemporaryDirectory() as tmp, patch.object(module.subprocess, 'run') as run:
            with self.assertRaises((ValueError, FileNotFoundError)):
                module.deploy(Path(tmp), 'a' * 40, 'sha256:' + 'b' * 64, '1.6.10')
            run.assert_not_called()

    def test_legacy_install_never_taken_over(self):
        module = self.load()
        with tempfile.TemporaryDirectory() as tmp:
            root = self.fixture(tmp)
            with synthetic_deploy_path(module, root), patch.object(module, 'run', return_value='legacy-container') as run:
                with self.assertRaisesRegex(ValueError, 'legacy'):
                    module.deploy(root, 'a'*40, 'sha256:'+'b'*64, '1.6.10')
                self.assertEqual(run.call_count, 1)

    def test_explicit_legacy_cutover_requires_matching_container_id(self):
        module = self.load()
        with tempfile.TemporaryDirectory() as tmp:
            root = self.fixture(tmp)
            marker = root / 'LEGACY_CUTOVER_APPROVED'
            marker.write_text('d'*64)
            marker.chmod(0o600)
            with patch.object(module, 'run', return_value='d'*64):
                self.assertEqual(module.legacy_guard(root), 'd'*64)
            with patch.object(module, 'run', return_value='e'*64):
                with self.assertRaises(ValueError):
                    module.legacy_guard(root)

    def test_transport_rejects_missing_pin_and_injection_without_commands(self):
        script = ROOT / 'tools/deploy_ssh.sh'
        self.assertTrue(script.is_file(), 'pinned transport missing')
        with tempfile.TemporaryDirectory() as tmp:
            env = dict(os.environ, VPS_DEPLOY_PATH='/tmp/unsafe;touch NO',
                       VPS_HOST='example.invalid', VPS_PORT='22', VPS_USER='user',
                       VPS_KNOWN_HOSTS='', VPS_SSH_KEY='', RUNNER_TEMP=tmp)
            result = subprocess.run(['bash', str(script), 'a'*40, 'sha256:'+'b'*64, '1.6.10'],
                                    env=env, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse((Path(tmp) / 'ssh').exists())

    def test_transport_pins_host_and_streams_only_fixed_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp).resolve()
            stub = tmp / 'ssh'
            stub.write_text('#!/bin/bash\nprintf "%s\\n" "$@" >> "$SSH_MOCK_LOG"\ncat >/dev/null\n')
            stub.chmod(0o700)
            env = dict(os.environ, VPS_DEPLOY_PATH='/data/home/muse2api-production',
                       VPS_HOST='example.invalid', VPS_PORT='22', VPS_USER='user',
                       VPS_KNOWN_HOSTS='synthetic', VPS_SSH_KEY='synthetic', RUNNER_TEMP=str(tmp),
                       SSH_MOCK_LOG=str(tmp / 'commands'), PATH=str(tmp)+os.pathsep+os.environ['PATH'])
            # A synthetic payload is streamed, not a Docker image or application.
            work = tmp / 'work'
            (work / 'tools').mkdir(parents=True)
            (work / 'deploy').mkdir()
            for name in ('tools/deploy_preflight.py', 'tools/deploy_remote.py',
                         'deploy/compose.production.yml', 'deploy-image.tar'):
                (work / name).write_text('synthetic')
            result = subprocess.run(['bash', str(ROOT/'tools/deploy_ssh.sh'), 'a'*40,
                                     'sha256:'+'b'*64, '1.6.10'], env=env, cwd=work,
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            log = (tmp / 'commands').read_text()
            self.assertEqual(log.count('StrictHostKeyChecking=yes'), 6)
            self.assertIn('GlobalKnownHostsFile=/dev/null', log)
            self.assertNotIn('StrictHostKeyChecking=no', log)
            self.assertNotIn('ssh-keyscan', log)
            self.assertIn('/incoming/'+'a'*40+'/image.tar', log)
            self.assertFalse(list(tmp.glob('muse-deploy-*')))

    def fixture(self, tmp):
        root = Path(tmp).resolve()
        root.chmod(0o700)
        for name in ('data', 'profiles', 'incoming', 'config', 'incoming/' + 'a'*40):
            (root / name).mkdir(mode=0o700)
        for name in ('data/generation-ledger.json', 'data/generation-ledger.json.initialized',
                     'data/admin-authority.json', 'data/admin-authority.json.initialized',
                     'incoming/' + 'a'*40 + '/compose.yml'):
            (root / name).write_text('{}')
            (root / name).chmod(0o600)
        for name, value in [('DEPLOY_READY', 'muse2api-storage-v1'),
                            ('config/.env', 'MUSE2API_KEY=synthetic\nMUSE2API_COOKIE_KEY=synthetic\nMUSE2API_PUBLIC_BASE=https://example.invalid')]:
            (root / name).write_text(value)
            (root / name).chmod(0o600)
        return root

    def exercise(self, fail_new=False, rollback=False, legacy=False):
        module = self.load()
        new_id, old_id = 'sha256:'+'b'*64, 'sha256:'+'c'*64
        calls = []
        active = [old_id]
        running = [True]
        with tempfile.TemporaryDirectory() as tmp:
            root = self.fixture(tmp)
            if legacy:
                (root / 'LEGACY_CUTOVER_APPROVED').write_text('d'*64)
                (root / 'LEGACY_CUTOVER_APPROVED').chmod(0o600)
            if rollback:
                (root / 'ROLLBACK_COMPATIBLE').write_text(module.CONTRACT)
                (root / 'ROLLBACK_COMPATIBLE').chmod(0o600)
            def fake(*args):
                calls.append(list(args))
                if args[1:3] == ('image', 'inspect'):
                    return json.dumps([{'Id': args[3], 'Config': {'Labels': {
                        'org.opencontainers.image.revision': 'a'*40,
                        'org.muse2api.storage-contract': module.CONTRACT}}}])
                if args[1] == 'ps':
                    return ('d'*64 if legacy else '') if args[-1] == 'name=^/muse2api$' else 'old-container'
                if args[1] == 'inspect' and args[2] == 'd'*64:
                    return json.dumps([{'State': {'Running': False}}])
                if args[1] == 'inspect':
                    return json.dumps([{'Image': active[0], 'State': {'Running': running[0]},
                        'Config': {'Labels': {'com.docker.compose.project': 'muse2api-production'}}}])
                if args[1] == 'exec' and fail_new and active[0] == new_id:
                    raise subprocess.CalledProcessError(1, ['synthetic'])
                return ''
            def compose(args, **kwargs):
                calls.append(list(args))
                if 'stop' in args:
                    running[0] = False
                if 'up' in args:
                    running[0] = True
                    active[0] = kwargs['env']['MUSE2API_DEPLOY_IMAGE']
                return subprocess.CompletedProcess(args, 0)
            with synthetic_deploy_path(module, root), patch.object(module, 'run', side_effect=fake), patch.object(module.subprocess, 'run', side_effect=compose), patch.object(module.time, 'sleep'):
                if fail_new:
                    with self.assertRaises(RuntimeError):
                        module.deploy(root, 'a'*40, new_id, '1.6.10')
                else:
                    module.deploy(root, 'a'*40, new_id, '1.6.10')
            self.assertEqual((root / 'data/generation-ledger.json').read_text(), '{}')
        return calls, active[0]

    def test_approved_cutover_stops_legacy_without_removing_anything(self):
        calls, _ = self.exercise(legacy=True)
        stop = next(i for i, c in enumerate(calls) if c[1:3] == ['stop', '--time'])
        start = next(i for i, c in enumerate(calls) if 'up' in c)
        self.assertLess(stop, start)
        self.assertTrue(any(c[1:3] == ['update', '--restart=no'] for c in calls))
        self.assertFalse(any('rm' in c or 'prune' in c or 'down' in c for c in calls))

    def test_production_mounts_rotation_and_network_contract(self):
        compose = (ROOT/'deploy/compose.production.yml').read_text()
        self.assertIn('127.0.0.1:18610:18610', compose)
        self.assertNotIn('19210:', compose)
        self.assertIn('target: /app/data', compose)
        self.assertIn('target: /app/runtime/data', compose)
        self.assertIn('target: /app/profiles', compose)
        self.assertIn('target: /app/runtime', compose)
        self.assertIn('MUSE2API_HOME: /app/runtime', compose)
        self.assertIn('MUSE2API_LEDGER_INITIALIZE: \'0\'', compose)
        self.assertIn('umask 077;', compose)
        self.assertIn('--workers 1', compose)
        self.assertEqual(compose.count('create_host_path: false'), 4)

    def test_immutable_image_stop_before_start_health_and_preserved_data(self):
        calls, active = self.exercise()
        stop = next(i for i, c in enumerate(calls) if 'stop' in c)
        up = next(i for i, c in enumerate(calls) if 'up' in c)
        self.assertLess(stop, up)
        self.assertEqual(active, 'sha256:'+'b'*64)
        self.assertTrue(any('exec' in c and 'version.json' in c[-1] for c in calls))

    def test_failed_health_has_bounded_retry_and_opt_in_image_only_rollback(self):
        calls, active = self.exercise(fail_new=True, rollback=True)
        self.assertEqual(active, 'sha256:'+'c'*64)
        self.assertEqual(sum('exec' in c for c in calls), 31)
        self.assertEqual(sum('up' in c for c in calls), 2)

    def test_failure_without_compatibility_approval_stays_stopped(self):
        calls, _ = self.exercise(fail_new=True)
        self.assertEqual(sum('up' in c for c in calls), 1)
        self.assertEqual(sum('stop' in c for c in calls), 2)


if __name__ == '__main__':
    unittest.main()
