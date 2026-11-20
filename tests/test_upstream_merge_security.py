"""Tenant boundaries for upstream queue settings and video thumbnails."""
import asyncio
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import app
from fastapi import HTTPException


class MergeSecurityTests(unittest.TestCase):
    def test_tenant_cannot_change_global_queue_policy(self):
        with patch.object(app.QUEUE_POLICY, 'save') as save:
            with self.assertRaises(HTTPException) as caught:
                app.save_generation_queue(app.QueueSettings(), {'id': 'tenant', 'role': 'user'})
        self.assertEqual(caught.exception.status_code, 403)
        save.assert_not_called()

    def test_thumbnail_requires_media_capability_before_processing(self):
        with patch.object(app, 'video_thumbnail') as generate:
            with self.assertRaises(HTTPException):
                app.get_media_thumbnail('private.mp4')
        generate.assert_not_called()

    def test_tenant_task_timing_updates_its_own_task(self):
        from generation_timing import TaskTiming
        task = app.store.create_task('video', 'synthetic', owner_id='tenant')
        timing = TaskTiming(app.store, task['id'], owner_id='tenant')
        timing.acquired()
        timing.account('account', 1)
        self.assertEqual(app.store.get_task(task['id'], owner_id='tenant')['status'], 'processing')


if __name__ == '__main__':
    unittest.main(verbosity=2)
