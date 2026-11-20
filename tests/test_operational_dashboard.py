"""Offline synthetic owner-isolated operational snapshots."""
import asyncio
import json
import unittest
from unittest.mock import patch
import app
from tests.test_multitenant_security import Client


class DashboardTests(unittest.TestCase):
    def test_own_snapshot_is_safe_and_counts_all_owned_tasks(self):
        a, key = app.users.create('synthetic A')
        b, _ = app.users.create('synthetic B')
        for owner, state in [(a['id'], 'queued'), (a['id'], 'processing'), (a['id'], 'failed'), (b['id'], 'queued')]:
            task = app.store.create_task('image', 'PRIVATE prompt cap=SECRET', owner_id=owner)
            app.store.update_task(task['id'], owner_id=owner, status=state, error='PRIVATE cookie')
        app.store.write_media('a.png', b'abc', a['id'])
        response = asyncio.run(Client(app.app, key).request('GET', '/v1/operations'))
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertEqual(data['tasks'], {'queued': 1, 'running': 1, 'failed': 1, 'completed': 0, 'cancelled': 0, 'unknown': 0})
        self.assertEqual(data['storage']['bytes'], 3)
        self.assertIsNone(data['wait_estimate_seconds'])
        self.assertGreaterEqual(data['oldest_queued_seconds'], 0)
        for private in ('PRIVATE', 'SECRET', b['id'], 'a.png', 'prompt', 'cookie', 'cap=', 'path'):
            self.assertNotIn(private, json.dumps(data))
        self.assertNotIn('disk', data)
        self.assertEqual(asyncio.run(Client(app.app, key).request('GET', '/admin/operations')).status_code, 403)
        self.assertEqual(asyncio.run(Client(app.app, 'invalid').request('GET', '/v1/operations')).status_code, 401)

    def test_admin_aggregate_has_only_safe_disk_and_owner_metrics(self):
        response = asyncio.run(Client(app.app, app.CFG.api_key).request('GET', '/admin/operations'))
        self.assertEqual(response.status_code, 200)
        data = response.json()
        self.assertIn('disk', data)
        self.assertGreater(data['disk']['available_bytes'], 0)
        self.assertIsNone(data['disk']['temporary_bytes'])
        self.assertEqual(data['disk']['scope'], 'data_filesystem')
        self.assertIn('admin', [row['owner_id'] for row in data['users']])
        self.assertNotIn(app.CFG.data_dir, json.dumps(data))
        with patch.object(app.store, 'storage_usage', side_effect=ValueError('PRIVATE')):
            unavailable = app._operational_snapshot('admin')
        self.assertIsNone(unavailable['storage'])
        self.assertNotIn('PRIVATE', json.dumps(unavailable))

    def test_revoked_key_cannot_read_prior_owner_snapshot(self):
        user, key = app.users.create('revocation fixture')
        client = Client(app.app, key)
        self.assertEqual(asyncio.run(client.request('GET', '/v1/operations')).status_code, 200)
        app.users.revoke(user['id'])
        self.assertEqual(asyncio.run(client.request('GET', '/v1/operations')).status_code, 401)
        task = app.store.create_task('video', 'private', owner_id=user['id'])
        app.store.update_task(task['id'], owner_id=user['id'], status='unexpected-future-state')
        self.assertEqual(app._operational_snapshot(user['id'])['tasks']['unknown'], 1)


if __name__ == '__main__':
    unittest.main()
