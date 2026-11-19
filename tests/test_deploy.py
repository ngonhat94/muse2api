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

# Exact, offline-only SSH replacement: execute only upload mkdir/cat commands,
# mapping the fixed synthetic remote root into this test's private scratch.
UPLOAD_SSH_STUB = '''#!/usr/bin/env python3
import os, pathlib, subprocess, sys
command = sys.argv[-1]
root = pathlib.Path(os.environ['SSH_UPLOAD_ROOT'])
if command.startswith('python3 '):
    sys.stdin.buffer.read()
    if not command.startswith('python3 - ') and os.environ.get('SSH_REMOTE_FAIL'):
        print('Deployment failed: image-load: timed out after 180s; secret-config', file=sys.stderr)
        print('arbitrary-secret-stderr', file=sys.stderr)
        sys.exit(1)
    sys.exit(0)
command = command.replace('/data/home/muse2api-production', str(root))
if 'cat > ' in command and os.environ.get('SSH_RACE'):
    destination = pathlib.Path(command.split("'", 2)[1])
    if os.environ['SSH_RACE'] == 'symlink':
        destination.symlink_to(root / 'protected')
    else:
        destination.write_bytes(b'competing-partial')
if 'cat > ' in command and os.environ.get('SSH_PARTIAL') == '1':
    destination = command.split("'", 2)[1]
    pathlib.Path(destination).write_bytes(b'partial-upload')
    sys.stdin.buffer.read()
    sys.exit(23)
sys.exit(subprocess.run(['bash', '-c', command]).returncode)
'''



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

    def test_attempt_must_belong_to_exact_revision(self):
        module = self.load()
        with patch.object(module, 'prepare') as prepare:
            for attempt in ('../escape', 'b'*40 + '-' + 'c'*32, 'a'*40 + '-bad'):
                with self.subTest(attempt=attempt), self.assertRaisesRegex(ValueError, 'attempt'):
                    module.deploy(Path('/synthetic'), 'a'*40, 'sha256:'+'b'*64, '1.6.10', attempt)
            prepare.assert_not_called()

    def test_command_errors_are_stage_specific_and_never_expose_output(self):
        module = self.load()
        for failure in (subprocess.CalledProcessError(7, ['secret-command'], output='secret-config', stderr='secret-token'),
                        subprocess.TimeoutExpired(['secret-command'], 180, output='secret-config', stderr='secret-token'),
                        FileNotFoundError('secret-path')):
            with self.subTest(error=type(failure).__name__), patch.object(module.subprocess, 'run', side_effect=failure):
                with self.assertRaisesRegex(module.DeploymentError, 'image-load') as caught:
                    module.run('docker', 'load', stage='image-load')
                self.assertNotIn('secret', str(caught.exception))
                self.assertIn('disk space', str(caught.exception))

    def test_remote_lock_serializes_attempts_before_docker(self):
        import threading
        module = self.load()
        entered, release, second_entered = threading.Event(), threading.Event(), threading.Event()
        failures = []
        with tempfile.TemporaryDirectory() as tmp:
            root = self.fixture(tmp)
            def fake(*args, **kwargs):
                if threading.current_thread().name == 'first-deploy':
                    entered.set()
                    if not release.wait(5):
                        raise AssertionError('test did not release first deploy')
                else:
                    second_entered.set()
                raise ValueError('synthetic stop before Docker')
            def worker():
                try:
                    module.deploy(root, 'a'*40, 'sha256:'+'b'*64, '1.6.10')
                except ValueError as error:
                    if str(error) != 'synthetic stop before Docker':
                        failures.append(error)
                except Exception as error:
                    failures.append(error)
            first = threading.Thread(target=worker, name='first-deploy')
            second = threading.Thread(target=worker, name='second-deploy')
            with synthetic_deploy_path(module, root), patch.object(module, 'run', side_effect=fake):
                first.start()
                try:
                    self.assertTrue(entered.wait(5))
                    second.start()
                    self.assertFalse(second_entered.wait(0.1), 'second deployment bypassed remote lock')
                finally:
                    release.set()
                    first.join(5)
                    if second.ident:
                        second.join(5)
            self.assertFalse(first.is_alive() or second.is_alive())
            self.assertTrue(second_entered.is_set())
            self.assertEqual(failures, [])

    def test_lock_symlink_fails_without_touching_target(self):
        module = self.load()
        with tempfile.TemporaryDirectory() as tmp:
            root = self.fixture(tmp)
            target = root / 'preserved'
            target.write_text('do not touch')
            (root / '.deploy.lock').symlink_to(target)
            with synthetic_deploy_path(module, root), patch.object(module, 'run') as run:
                with self.assertRaises(OSError):
                    module.deploy(root, 'a'*40, 'sha256:'+'b'*64, '1.6.10')
                run.assert_not_called()
            self.assertEqual(target.read_text(), 'do not touch')

    def test_missing_or_symlink_archive_stops_before_image_load(self):
        module = self.load()
        for symlink in (False, True):
            with self.subTest(symlink=symlink), tempfile.TemporaryDirectory() as tmp:
                root = self.fixture(tmp)
                archive = root / 'incoming' / ('a'*40) / 'image.tar'
                archive.unlink()
                if symlink:
                    archive.symlink_to(root / 'data/generation-ledger.json')
                with synthetic_deploy_path(module, root), patch.object(module, 'run', return_value='') as run:
                    with self.assertRaises((ValueError, FileNotFoundError)):
                        module.deploy(root, 'a'*40, 'sha256:'+'b'*64, '1.6.10')
                    self.assertEqual(run.call_count, 1)  # legacy query only
                self.assertEqual((root / 'data/generation-ledger.json').read_text(), '{}')

    def test_image_load_failure_reports_stage_before_stopping_runtime(self):
        module = self.load()
        with tempfile.TemporaryDirectory() as tmp:
            root = self.fixture(tmp)
            def command(args, **kwargs):
                if args[1] == 'ps':
                    return subprocess.CompletedProcess(args, 0, stdout='')
                raise subprocess.CalledProcessError(1, args, stderr='secret-config')
            with synthetic_deploy_path(module, root), patch.object(module.subprocess, 'run', side_effect=command) as run:
                with self.assertRaisesRegex(module.DeploymentError, 'image-load') as caught:
                    module.deploy(root, 'a'*40, 'sha256:'+'b'*64, '1.6.10')
                self.assertNotIn('secret', str(caught.exception))
                self.assertEqual(run.call_count, 2)
                self.assertFalse(any('stop' in c.args[0] for c in run.call_args_list))

    def test_image_identity_mismatch_never_stops_runtime(self):
        module = self.load()
        for field in ('Id', 'revision', 'contract'):
            with self.subTest(field=field), tempfile.TemporaryDirectory() as tmp:
                root = self.fixture(tmp)
                image = {'Id': 'sha256:'+'b'*64, 'Config': {'Labels': {
                    'org.opencontainers.image.revision': 'a'*40,
                    'org.muse2api.storage-contract': module.CONTRACT}}}
                if field == 'Id':
                    image['Id'] = 'sha256:'+'c'*64
                else:
                    key = 'org.opencontainers.image.revision' if field == 'revision' else 'org.muse2api.storage-contract'
                    image['Config']['Labels'][key] = 'mismatch'
                with synthetic_deploy_path(module, root), patch.object(module, 'run', side_effect=['', '', json.dumps([image])]) as run:
                    with self.assertRaisesRegex(ValueError, 'identity/contract'):
                        module.deploy(root, 'a'*40, 'sha256:'+'b'*64, '1.6.10')
                    self.assertFalse(any('stop' in call.args for call in run.call_args_list))
                self.assertEqual((root / 'incoming' / ('a'*40) / 'image.tar').read_text(), '{}')

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

    def test_workflow_uses_exported_manifest_digest_for_remote_identity(self):
        workflow = (ROOT / '.github/workflows/ci.yml').read_text()
        self.assertIn("tarfile.open('deploy-image.tar', 'r')", workflow)
        self.assertIn("index = json.load(archive.extractfile('index.json'))", workflow)
        self.assertNotIn("image_id=$(docker image inspect --format '{{.Id}}'", workflow)
        self.assertLess(workflow.index('docker save --output deploy-image.tar'),
                        workflow.index("tarfile.open('deploy-image.tar', 'r')"))

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
                       VPS_HOST='example.invalid', VPS_PORT='22', VPS_USER='user', VPS_SSH_MODE='key',
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
            self.assertEqual(log.count('StrictHostKeyChecking=yes'), 2)
            self.assertIn('GlobalKnownHostsFile=/dev/null', log)
            self.assertNotIn('StrictHostKeyChecking=no', log)
            self.assertNotIn('ssh-keyscan', log)
            self.assertRegex(log, 'a'*40+'-[a-f0-9]{32}')
            self.assertFalse(list(tmp.glob('muse-deploy-*')))

    def token_transport(self, **changes):
        with tempfile.TemporaryDirectory() as directory:
            tmp = Path(directory).resolve()
            stub = tmp / 'ssh'
            stub.write_text('#!/bin/bash\nprintf "%s\\n" "$@" >> "$SSH_MOCK_LOG"\nif [[ ${SSH_MOCK_FAIL:-} == 1 ]]; then\n  for arg in "$@"; do\n    if [[ $arg == */config ]]; then cat "$arg" >&2; fi\n  done\n  exit 255\nfi\ncat >/dev/null\n')
            stub.chmod(0o700)
            env = dict(os.environ, VPS_DEPLOY_PATH='/data/home/muse2api-production',
                       VPS_HOST='example.invalid', VPS_PORT='2222',
                       VPS_USER='ibssh_abcdefghijklmnopqrstuvwxyz', VPS_SSH_MODE='instabox-token',
                       VPS_KNOWN_HOSTS='synthetic', VPS_SSH_KEY='', RUNNER_TEMP=str(tmp),
                       SSH_MOCK_LOG=str(tmp / 'commands'), PATH=str(tmp)+os.pathsep+os.environ['PATH'])
            env.update(changes)
            work = tmp / 'work'
            (work / 'tools').mkdir(parents=True)
            (work / 'deploy').mkdir()
            for name in ('tools/deploy_preflight.py', 'tools/deploy_remote.py',
                         'deploy/compose.production.yml', 'deploy-image.tar'):
                (work / name).write_text('synthetic')
            result = subprocess.run(['bash', str(ROOT/'tools/deploy_ssh.sh'), 'a'*40,
                                     'sha256:'+'b'*64, '1.6.10'], env=env, cwd=work,
                                    capture_output=True, text=True)
            log = (tmp / 'commands').read_text() if (tmp / 'commands').exists() else ''
            if env['VPS_USER']:
                self.assertNotIn(env['VPS_USER'], result.stdout + result.stderr)
            self.assertFalse(list(tmp.glob('muse-deploy-*')))
            return result, log

    def test_real_upload_retries_preserve_interrupted_and_existing_releases(self):
        # Receiver's filesystem/partial-stream regression lives in test_deploy_retention.
        # Transport sends one byte-framed session, never shell-created upload paths.
        result, log = self.token_transport()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('--receive', log)
        self.assertNotIn('cat >', log)
        self.assertNotIn('mkdir ', log)

    def test_repeated_transport_uses_distinct_no_clobber_attempts(self):
        first, log1 = self.token_transport()
        second, log2 = self.token_transport()
        self.assertEqual(first.returncode, 0, first.stderr)
        self.assertEqual(second.returncode, 0, second.stderr)
        mkdir1 = next(line for line in log1.splitlines() if '--receive' in line)
        mkdir2 = next(line for line in log2.splitlines() if '--receive' in line)
        self.assertNotEqual(mkdir1, mkdir2, 'reruns must not reuse immutable SHA directory')
        for log in (log1, log2):
            self.assertIn('--receive', log)
            self.assertNotIn('rm ', log)

    def test_token_mode_without_key_pins_gateway_and_never_offers_client_keys(self):
        result, log = self.token_transport()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(log.count('StrictHostKeyChecking=yes'), 2)
        self.assertEqual(log.count('GlobalKnownHostsFile=/dev/null'), 2)
        self.assertNotIn('StrictHostKeyChecking=no', log)
        self.assertNotIn('ssh-keyscan', log)
        self.assertIn('VPS_SSH_MODE: ${{ vars.VPS_SSH_MODE }}',
                      (ROOT / '.github/workflows/ci.yml').read_text())
        for option in ('BatchMode=yes', 'PubkeyAuthentication=no',
                       'PasswordAuthentication=no', 'KbdInteractiveAuthentication=no'):
            self.assertEqual(log.count(option), 2)
        self.assertNotIn('IdentitiesOnly', log)
        self.assertNotIn('\n-i\n', log)
        self.assertNotIn('ibssh_abcdefghijklmnopqrstuvwxyz', log)

    def test_ssh_failure_categories_never_publish_raw_stderr(self):
        # Exercise the real wrapper while replacing only the SSH executable.
        for message, category in (
            ('cat: /private/secret: Permission denied', 'permission-denied'),
            ('cat: /private/secret: No such file or directory', 'missing-path'),
            ('cat: write error: No space left on device', 'disk-full'),
            ('cat: write error: File too large', 'file-too-large'),
            ('sh: set: Illegal option -C', 'shell-option'),
            ('sh: cannot overwrite existing file /private/secret', 'target-exists'),
            ('ssh: Connection reset by peer secret-host', 'connection-reset'),
            ('opaque-private-secret', 'unclassified'),
        ):
            with self.subTest(category=category):
                # A fixture-local stub emits a controlled failure, never network IO.
                original = Path.write_text
                def write(path, text, *args, **kwargs):
                    if path.name == 'ssh':
                        text = '#!/bin/bash\nif [[ ${!#} == *"cat > "* ]]; then\n printf "%s\\n" "$SSH_TEST_ERROR" >&2\n exit 1\nfi\ncat >/dev/null\n'
                    return original(path, text, *args, **kwargs)
                with patch.object(Path, 'write_text', write):
                    result, _ = self.token_transport(SSH_TEST_ERROR=message)
                self.assertEqual(result.returncode, 1)
                self.assertIn('category=' + category, result.stderr)
                self.assertNotIn(message, result.stdout + result.stderr)
                self.assertNotIn('/private/', result.stdout + result.stderr)

    def test_token_mode_redacts_ssh_errors_and_preserves_failure_status(self):
        result, log = self.token_transport(SSH_MOCK_FAIL='1')
        self.assertEqual(result.returncode, 255)
        self.assertIn('[REDACTED]', result.stderr)
        self.assertEqual(log.count('StrictHostKeyChecking=yes'), 1)

    def test_token_mode_accepts_safe_non_guessed_contract_and_ignores_key(self):
        result, log = self.token_transport(VPS_USER='7Safe_Token.Contract-2', VPS_SSH_KEY='synthetic')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn('\n-i\n', log)
        self.assertNotIn('IdentitiesOnly', log)

    def test_default_key_mode_still_requires_key(self):
        result, log = self.token_transport(VPS_SSH_MODE='', VPS_USER='user')
        self.assertEqual(result.returncode, 2)
        self.assertIn('VPS_SSH_KEY', result.stderr)
        self.assertEqual(log, '')

    def test_unknown_mode_is_rejected_before_ssh(self):
        result, log = self.token_transport(VPS_SSH_MODE='typo', VPS_SSH_KEY='synthetic')
        self.assertEqual(result.returncode, 2)
        self.assertIn('VPS_SSH_MODE', result.stderr)
        self.assertEqual(log, '')

    def test_token_mode_rejects_unsafe_values_and_requires_pin(self):
        for token in ('', '-option', 'a@host', 'a b', 'a\nb', 'a;b', 'a$(id)', 'a/b', 'a'*257):
            with self.subTest(token=repr(token)):
                result, log = self.token_transport(VPS_USER=token)
                self.assertEqual(result.returncode, 2)
                self.assertEqual(log, '')
        result, log = self.token_transport(VPS_KNOWN_HOSTS='')
        self.assertEqual(result.returncode, 2)
        self.assertEqual(log, '')

    def fixture(self, tmp):
        root = Path(tmp).resolve()
        root.chmod(0o700)
        for name in ('data', 'profiles', 'incoming', 'config', 'incoming/' + 'a'*40):
            (root / name).mkdir(mode=0o700)
        for name in ('data/generation-ledger.json', 'data/generation-ledger.json.initialized',
                     'data/admin-authority.json', 'data/admin-authority.json.initialized',
                     'incoming/' + 'a'*40 + '/compose.yml',
                     'incoming/' + 'a'*40 + '/image.tar'):
            (root / name).write_text('{}')
            (root / name).chmod(0o600)
        for name, value in [('DEPLOY_READY', 'muse2api-storage-v1'),
                            ('config/.env', 'MUSE2API_KEY=synthetic\nMUSE2API_COOKIE_KEY=synthetic\nMUSE2API_PUBLIC_BASE=https://example.invalid')]:
            (root / name).write_text(value)
            (root / name).chmod(0o600)
        return root

    def exercise(self, fail_new=False, rollback=False, legacy=False, attempt=None):
        module = self.load()
        new_id, old_id = 'sha256:'+'b'*64, 'sha256:'+'c'*64
        calls = []
        active = [old_id]
        running = [True]
        with tempfile.TemporaryDirectory() as tmp:
            root = self.fixture(tmp)
            if attempt:
                (root / 'incoming' / ('a'*40)).rename(root / 'incoming' / attempt)
            if legacy:
                (root / 'LEGACY_CUTOVER_APPROVED').write_text('d'*64)
                (root / 'LEGACY_CUTOVER_APPROVED').chmod(0o600)
            if rollback:
                (root / 'ROLLBACK_COMPATIBLE').write_text(module.CONTRACT)
                (root / 'ROLLBACK_COMPATIBLE').chmod(0o600)
            def fake(*args, **kwargs):
                calls.append(list(args))
                if args[1:3] == ('image', 'ls'):
                    return old_id
                if args[1:3] == ('image', 'inspect'):
                    return json.dumps([{'Id': args[3], 'RepoTags': [], 'Config': {'Labels': {
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
                        module.deploy(root, 'a'*40, new_id, '1.6.10', attempt)
                else:
                    module.deploy(root, 'a'*40, new_id, '1.6.10', attempt)
            self.assertEqual((root / 'data/generation-ledger.json').read_text(), '{}')
        return calls, active[0]

    def test_approved_cutover_stops_legacy_without_removing_anything(self):
        calls, _ = self.exercise(legacy=True)
        stop = next(i for i, c in enumerate(calls) if c[1:3] == ['stop', '--time'])
        start = next(i for i, c in enumerate(calls) if 'up' in c)
        self.assertLess(stop, start)
        self.assertTrue(any(c[1:3] == ['update', '--restart=no'] for c in calls))
        self.assertFalse(any('prune' in c or 'down' in c or c[1:2] == ['rm'] for c in calls))

    def test_explicit_attempt_loads_only_its_archive(self):
        attempt = 'a'*40 + '-' + 'd'*32
        calls, _ = self.exercise(attempt=attempt)
        load = next(c for c in calls if 'load' in c)
        self.assertTrue(load[-1].endswith('/incoming/' + attempt + '/image.tar'))

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
        removal = next(i for i, c in enumerate(calls) if c[1:3] == ['image', 'rm'])
        health = max(i for i, c in enumerate(calls) if 'exec' in c)
        self.assertGreater(removal, health)

    def test_failed_health_has_bounded_retry_and_opt_in_image_only_rollback(self):
        calls, active = self.exercise(fail_new=True, rollback=True)
        self.assertEqual(active, 'sha256:'+'c'*64)
        self.assertEqual(sum('exec' in c for c in calls), 31)
        self.assertEqual(sum('up' in c for c in calls), 2)
        self.assertFalse(any(c[1:3] == ['image', 'rm'] for c in calls))

    def test_failure_without_compatibility_approval_stays_stopped(self):
        calls, _ = self.exercise(fail_new=True)
        self.assertEqual(sum('up' in c for c in calls), 1)
        self.assertEqual(sum('stop' in c for c in calls), 2)


if __name__ == '__main__':
    unittest.main()
