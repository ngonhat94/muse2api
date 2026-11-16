"""Standalone bootstrap subprocess regressions. Synthetic Docker only."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
DOCKER_STUB = '''#!/usr/bin/env python3
import json, os, pathlib, sys
args = sys.argv[1:]
with open(os.environ['BOOTSTRAP_TEST_LOG'], 'a') as out:
    out.write(json.dumps(args) + '\\n')
if args[:2] == ['ps', '-aq']:
    if os.environ.get('BOOTSTRAP_TEST_FAIL') == 'legacy-query': sys.exit(1)
    if os.environ.get('BOOTSTRAP_TEST_FAIL') != 'no-legacy': print('d'*64)
elif args[:2] == ['image', 'inspect']:
    print('sha256:' + 'b'*64)
elif '-c' in args:
    if os.environ.get('BOOTSTRAP_TEST_FAIL') == 'image': sys.exit(1)
else:
    source = sys.stdin.read()
    compile(source, '<bootstrap>', 'exec')
    if os.environ.get('BOOTSTRAP_TEST_FAIL') == 'bootstrap': sys.exit(1)
    base = pathlib.Path(os.environ['ROOT'])
    (base/'config/.env').write_text('synthetic-only\\n')
    for name in ('admin-authority.json', 'generation-ledger.json'):
        (base/'data'/name).write_text('{}')
        (base/'data'/(name+'.initialized')).write_text('{}')
'''


class BootstrapTests(unittest.TestCase):
    def invoke(self, fail='', prepare=None):
        with tempfile.TemporaryDirectory(prefix='bootstrap-test-', dir=os.environ.get('MUSE2API_TEST_TMP')) as tmp:
            tmp = Path(tmp).resolve()
            root = tmp/'isolated'
            stub = tmp/'docker'
            stub.write_text(DOCKER_STUB)
            stub.chmod(0o700)
            if prepare:
                prepare(root)
            env = dict(os.environ, ROOT=str(root), IMAGE='muse2api:bootstrap',
                       PATH=str(tmp)+os.pathsep+os.environ['PATH'],
                       BOOTSTRAP_TEST_LOG=str(tmp/'log'), BOOTSTRAP_TEST_FAIL=fail)
            result = subprocess.run(['bash', str(ROOT/'tools/bootstrap_vps.sh')],
                                    env=env, capture_output=True, text=True, timeout=20)
            snapshot = {str(p.relative_to(root)): p.read_bytes() for p in root.rglob('*') if p.is_file()} if root.exists() else {}
            log = (tmp/'log').read_text() if (tmp/'log').exists() else ''
            return result, snapshot, log

    def test_bootstrap_failure_never_approves_or_reports_success(self):
        result, files, log = self.invoke('bootstrap')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('BOOTSTRAP COMPLETE', result.stdout)
        self.assertNotIn('DEPLOY_READY', files)
        self.assertNotIn('LEGACY_CUTOVER_APPROVED', files)
        self.assertIn('BOOTSTRAP_IN_PROGRESS', files)

    def test_success_orders_probe_before_bootstrap_then_approval(self):
        import json
        result, files, log = self.invoke()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('BOOTSTRAP COMPLETE', result.stdout)
        self.assertEqual(files['DEPLOY_READY'], b'muse2api-storage-v1\n')
        self.assertEqual(files['LEGACY_CUTOVER_APPROVED'], ('d'*64+'\n').encode())
        calls = [json.loads(line) for line in log.splitlines()]
        self.assertEqual(calls[0][:2], ['ps', '-aq'])
        self.assertEqual(calls[1][:2], ['image', 'inspect'])
        self.assertIn('-c', calls[2])
        self.assertNotIn('-c', calls[3])
        self.assertEqual(calls[4][:2], ['ps', '-aq'])
        for call in calls[2:4]:
            self.assertEqual(call[call.index('--network')+1], 'none')
            self.assertIn('sha256:'+'b'*64, call)
        self.assertFalse(any(word in log for word in ('"stop"', '"rm", "muse2api"', '"start"')))

    def test_partial_state_is_never_overwritten(self):
        def prepare(root):
            (root/'config').mkdir(parents=True, mode=0o700)
            root.chmod(0o700)
            (root/'config/.env').write_text('retain-original')
        result, files, log = self.invoke(prepare=prepare)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(files, {'config/.env': b'retain-original'})
        self.assertEqual(log, '')

    def test_marker_only_state_is_rejected(self):
        def prepare(root):
            (root/'data').mkdir(parents=True, mode=0o700)
            root.chmod(0o700)
            (root/'data/generation-ledger.json.initialized').write_text('retain-marker')
        result, files, log = self.invoke(prepare=prepare)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(log, '')
        self.assertEqual(files['data/generation-ledger.json.initialized'], b'retain-marker')

    def test_symlink_and_public_directory_rejected(self):
        def public(root):
            root.mkdir(mode=0o755)
            root.chmod(0o755)
        def symlink(root):
            target = root.parent/'target'
            target.mkdir(mode=0o700)
            root.symlink_to(target, target_is_directory=True)
        for prepare in (public, symlink):
            with self.subTest(prepare=prepare.__name__):
                result, files, log = self.invoke(prepare=prepare)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(files, {})
                self.assertEqual(log, '')

    def test_existing_empty_directories_are_accepted(self):
        def prepare(root):
            root.mkdir(mode=0o700)
            for name in ('config', 'data', 'profiles', 'incoming'):
                (root/name).mkdir(mode=0o700)
        result, files, log = self.invoke(prepare=prepare)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('DEPLOY_READY', files)

    def test_image_probe_failure_leaves_no_keys(self):
        result, files, log = self.invoke('image')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(files, {})
        self.assertNotIn('BOOTSTRAP COMPLETE', result.stdout)

    def test_embedded_bootstrap_initializes_real_authority_and_encrypted_ledger(self):
        import ast
        import json
        import hashlib
        from unittest.mock import patch
        host = (ROOT/'tools/bootstrap_vps.sh').read_text().split("<<'BOOTSTRAP_HOST_PY'\n", 1)[1].rsplit('\nBOOTSTRAP_HOST_PY', 1)[0]
        tree = ast.parse(host)
        snippets = {node.targets[0].id: ast.literal_eval(node.value) for node in tree.body
                    if isinstance(node, ast.Assign) and isinstance(node.targets[0], ast.Name)
                    and node.targets[0].id in ('probe', 'bootstrap')}
        compile(host, '<host>', 'exec')
        for snippet in snippets.values():
            compile(snippet, '<embedded>', 'exec')
        self.assertIn("'app'", snippets['probe'])
        with tempfile.TemporaryDirectory() as tmp:
            base = Path(tmp)
            (base/'data').mkdir()
            with patch.dict(os.environ, {}, clear=True):
                exec(compile(snippets['bootstrap'].replace("Path('/bootstrap')", 'Path('+repr(tmp)+')'), '<bootstrap>', 'exec'), {})
            values = dict(line.split('=', 1) for line in (base/'.env').read_text().splitlines())
            authority = json.loads((base/'data/admin-authority.json').read_text())
            self.assertEqual(authority['key_hash'], hashlib.sha256(values['MUSE2API_KEY'].encode()).hexdigest())
            self.assertEqual(json.loads((base/'data/generation-ledger.json').read_text())['format'], 'muse2api-accounts-fernet-v1')

    def test_fresh_host_without_legacy_initializes_without_cutover_approval(self):
        self.assertTrue((ROOT/'tools/bootstrap_vps.sh').exists(), 'standalone bootstrap missing')
        result, files, log = self.invoke('no-legacy')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('BOOTSTRAP COMPLETE', result.stdout)
        self.assertIn('DEPLOY_READY', files)
        self.assertNotIn('LEGACY_CUTOVER_APPROVED', files)

    def test_legacy_lookup_failure_writes_nothing(self):
        result, files, log = self.invoke('legacy-query')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('BOOTSTRAP COMPLETE', result.stdout)
        self.assertEqual(files, {})
        self.assertNotIn('image', log)


if __name__ == '__main__':
    unittest.main()
