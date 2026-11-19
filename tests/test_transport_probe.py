import importlib.util
from pathlib import Path
import unittest


class TransportProbeTests(unittest.TestCase):
    def test_probe_is_bounded_and_cannot_invoke_deployment(self):
        source = Path('tools/deploy_transport_probe.py').read_text()
        spec = importlib.util.spec_from_file_location('probe', 'tools/deploy_transport_probe.py')
        assert spec is not None and spec.loader is not None
        probe = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(probe)
        commands = probe.commands('/data/home/muse2api-production', 'diagnostic-' + 'a' * 32)
        self.assertEqual(len(commands), 3)
        self.assertIn('mkdir', commands[0])
        self.assertIn('set -C; cat >', commands[1])
        self.assertIn('sha256', commands[2])
        for forbidden in ['docker ', 'compose ', 'unlink(', 'rmtree(', 'rm -', 'deploy_remote.py']:
            self.assertNotIn(forbidden, source)
        for root, attempt in [('/', 'diagnostic-' + 'a' * 32), ('/safe', '../escape'), ('/safe;bad', 'diagnostic-' + 'a' * 32)]:
            with self.assertRaises(ValueError):
                probe.commands(root, attempt)


if __name__ == '__main__':
    unittest.main()
