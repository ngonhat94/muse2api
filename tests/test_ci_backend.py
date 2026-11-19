"""Portable CI orchestration: no product imports, network or browser."""
import ast
import importlib.util
import py_compile
import shlex
import shutil
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]


class CiBackendTests(unittest.TestCase):
    def load(self):
        path = ROOT / 'tools/ci_backend.py'
        self.assertTrue(path.is_file(), 'portable CI runner is missing')
        spec = importlib.util.spec_from_file_location('ci_backend', path)
        assert spec is not None and spec.loader is not None
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    def test_every_python_test_is_selected_or_explicitly_excluded(self):
        runner = self.load()
        selected = {name for name, _ in runner.CASES}
        excluded = set(runner.EXCLUDED)
        self.assertFalse(selected & excluded)
        self.assertEqual(selected | excluded, {p.name for p in (ROOT/'tests').glob('test_*.py')})
        self.assertIn('test_idempotency_acceptance.py', selected)
        self.assertIn('test_socks_proxy.py', excluded)

    def test_ci_builds_only_server_after_synthetic_gates(self):
        workflow = (ROOT / '.github/workflows/ci.yml').read_text()
        self.assertIn('  push:', workflow)
        self.assertIn('  pull_request:', workflow)
        self.assertIn('  workflow_dispatch:', workflow)
        jobs = [line.strip().removesuffix(':') for line in workflow.split('jobs:\n', 1)[1].splitlines()
                if line.startswith('  ') and not line.startswith('   ') and line.endswith(':')]
        self.assertEqual(jobs, ['transport-diagnostic', 'backend'])
        self.assertIn("github.event_name == 'workflow_dispatch' && github.ref == 'refs/heads/fix/deploy-upload-shell'", workflow)
        diagnostic = workflow.split('  transport-diagnostic:', 1)[1].split('  backend:', 1)[0]
        self.assertNotIn('deploy_ssh.sh', diagnostic)
        self.assertNotIn('docker ', diagnostic)
        self.assertIn('tools/deploy_transport_probe.py', diagnostic)
        self.assertIn("github.event_name == 'push' && github.ref == 'refs/heads/main'", workflow)
        self.assertIn('cancel-in-progress: false', workflow)
        self.assertIn('bash tools/deploy_ssh.sh', workflow)
        self.assertIn('VPS_KNOWN_HOSTS: ${{ secrets.VPS_KNOWN_HOSTS }}', workflow)
        self.assertIn('python tools/ci_backend.py', workflow)
        self.assertIn('tests/test_*.cjs tests/test_*.mjs', workflow)
        build = 'docker build --pull --tag muse2api-ci:check --file Dockerfile .'
        self.assertIn(build, workflow)
        self.assertGreater(workflow.index(build), workflow.index('node "$test"'))
        for forbidden in ('flutter', 'muse_app', 'docker push', 'docker run', 'upload-artifact'):
            self.assertNotIn(forbidden, workflow.lower())

    def test_docker_server_sources_compile_and_cover_local_imports(self):
        # Reproduce literal Docker COPY inputs without a daemon or importing app:
        # importing it could touch runtime state. AST validates transitive modules.
        copied = set()
        with tempfile.TemporaryDirectory() as scratch:
            target = Path(scratch)
            for line in (ROOT / 'Dockerfile').read_text().splitlines():
                if not line.startswith('COPY '):
                    continue
                *sources, destination = shlex.split(line)[1:]
                if any(s.endswith('.py') for s in sources):
                    self.assertEqual(destination, './')
                for source in sources:
                    original = ROOT / source
                    self.assertTrue(original.exists(), source)
                    if original.is_file() and destination in ('.', './'):
                        shutil.copy2(original, target / original.name)
                        copied.add(original.name)
            modules = {p.stem: p for p in ROOT.glob('*.py')}
            self.assertIn('app.py', copied)
            self.assertIn('operations.py', copied)  # CLI runtime dependency, too.
            for source in sorted(copied):
                if not source.endswith('.py'):
                    continue
                py_compile.compile(str(target / source), cfile=str(target / (source + 'c')), doraise=True)
                tree = ast.parse((target / source).read_text())
                for node in ast.walk(tree):
                    names = ([alias.name.split('.')[0] for alias in node.names] if isinstance(node, ast.Import)
                             else [node.module.split('.')[0]] if isinstance(node, ast.ImportFrom) and node.module else [])
                    for name in set(names) & modules.keys():
                        self.assertIn(name + '.py', copied, f'{source} requires {name}')
        ignore = (ROOT / '.dockerignore').read_text().splitlines()
        self.assertEqual(ignore[0], '**')
        self.assertFalse(any(line.startswith('!muse_app') or line.startswith('!data') or line.startswith('!.env')
                             for line in ignore))
        for source in copied:
            self.assertIn('!' + source, ignore)

    def test_runner_uses_portable_scratch_and_propagates_failure(self):
        runner = self.load()
        with tempfile.TemporaryDirectory() as scratch, patch.dict(os.environ, {'RUNNER_TEMP': scratch}), \
             patch.object(runner.subprocess, 'run', side_effect=subprocess.CalledProcessError(2, ['fixture'])) as run:
            with self.assertRaises(subprocess.CalledProcessError):
                runner.main()
            args, kwargs = run.call_args
            self.assertEqual(args[0][:2], [sys.executable, str(ROOT/'tests/run_backend_offline.py')])
            self.assertEqual(kwargs['env']['MUSE2API_TEST_TMP'], str(Path(scratch).resolve()))
            self.assertTrue(kwargs['check'])
            self.assertEqual(kwargs['timeout'], 120)


if __name__ == '__main__':
    unittest.main()
