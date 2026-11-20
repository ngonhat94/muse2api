"""An upstream background update must never overwrite local source work."""
import unittest
from unittest.mock import patch
import app


class LocalUpdateSafetyTests(unittest.TestCase):
    def test_silent_upgrade_refuses_dirty_tree_before_destructive_updater(self):
        with patch.object(app, '_git') as git, patch.object(app, '_upgrade_from_github_sync', return_value={'ok': False}) as upgrade:
            git.return_value.returncode = 0
            git.return_value.stdout = ' M engine.py\n?? muse_app/\n'
            app._silent_upgrade_worker()
            upgrade.assert_not_called()
            git.assert_not_called()

    def test_silent_upgrade_refuses_unverifiable_worktree(self):
        with patch.object(app, '_git', side_effect=OSError('fixture')), patch.object(app, '_upgrade_from_github_sync', return_value={'ok': False}) as upgrade:
            app._silent_upgrade_worker()
            upgrade.assert_not_called()


if __name__ == '__main__':
    unittest.main()
