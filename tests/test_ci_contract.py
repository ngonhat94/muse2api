"""Release boundary checks; no network or real deployment."""
from pathlib import Path
import ast
import unittest

ROOT = Path(__file__).resolve().parents[1]

class CIContract(unittest.TestCase):
    def test_image_includes_all_root_runtime_modules(self):
        dockerfile = (ROOT / 'Dockerfile').read_text()
        copies = [line for line in dockerfile.splitlines() if line.startswith('COPY ')]
        names = set(' '.join(copies).split())
        self.assertTrue('*.py' in names or all(p.name in names for p in ROOT.glob('*.py')),
                        'Docker image omits custom runtime modules')

    def test_deploy_entrypoint_exists(self):
        self.assertTrue((ROOT / 'deploy/instabox_release.py').is_file(), 'missing transactional deploy')

    def test_workflow_gates_production_and_uses_instabox(self):
        import yaml
        workflow = yaml.safe_load((ROOT / '.github/workflows/backend.yml').read_text())
        jobs = workflow['jobs']
        self.assertEqual(set(jobs), {'test', 'build', 'deploy'})
        for job in jobs.values():
            self.assertEqual(job['runs-on'], 'ubuntu-latest')
        deploy = jobs['deploy']
        self.assertEqual(deploy['if'], "github.event_name == 'push' && github.ref == 'refs/heads/master'")
        self.assertEqual(deploy['environment'], 'production')
        self.assertEqual(set(deploy['needs']), {'test', 'build'})
        self.assertFalse(deploy['concurrency']['cancel-in-progress'])
        self.assertEqual(deploy['env']['INSTABOX_API_KEY'], '${{ secrets.INSTABOX_API_KEY }}')
        triggers = workflow.get('on', workflow.get(True))  # YAML 1.1 treats on as boolean
        self.assertEqual(set(triggers), {'push', 'pull_request'})
        self.assertEqual(triggers['push']['branches'], ['master'])
        self.assertEqual(triggers['pull_request']['branches'], ['master'])

if __name__ == '__main__':
    unittest.main()
