import asyncio
import json
import tempfile
import unittest
from pathlib import Path
from uuid import uuid4
from fastapi import HTTPException
from video_projects import ProjectService


class PlanningDiagnosticsTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(dir=Path(__file__).parent)
        self.addCleanup(self.tmp.cleanup)
        self.service = ProjectService(Path(self.tmp.name) / 'projects.json')

    def run_plan(self, value):
        s = self.service
        p = s.create('alice', {'title': 'Test', 'idea': 'Idea'})
        request = {'revision': p['revision'], 'request_id': str(uuid4())}
        calls = []
        async def adapter(snapshot):
            calls.append(snapshot['id'])
            if isinstance(value, Exception):
                raise value
            return value
        asyncio.run(s.plan('alice', p['id'], request, adapter))
        for thread in s.threads:
            thread.join(5)
            self.assertFalse(thread.is_alive())
        result = s.get('alice', p['id'])
        replay = asyncio.run(s.plan('alice', p['id'], request, adapter))
        self.assertEqual(result, replay)
        self.assertEqual(len(calls), 1)
        return result, request

    def test_real_adapter_typed_boundary_without_provider_calls(self):
        import os
        from unittest.mock import patch, AsyncMock
        from cryptography.fernet import Fernet
        from video_projects import PlanningFailure
        root = Path(self.tmp.name)
        with patch.dict(os.environ, {'MUSE2API_HOME': str(root), 'MUSE2API_PROFILE_ROOT': str(root/'profile'),
            'MUSE2API_COOKIE_KEY': Fernet.generate_key().decode(), 'MUSE2API_COOKIE_KEY_FILE': '',
            'MUSE2API_KEY': 'synthetic', 'MUSE2API_LEDGER_INITIALIZE': '1', 'MUSE2API_AUTO_UPDATE': '0'}):
            import app
        project = {'idea': 'Synthetic', 'aspect_ratio': '16:9'}
        with patch.object(app.store, 'pick_account', return_value=None):
            with self.assertRaises(PlanningFailure) as error:
                asyncio.run(app._project_planner(project, None))
            self.assertEqual(error.exception.code, 'no_account')
        self.assertFalse(app._PLANNING_DIAGNOSTICS.get())
        from fastapi.testclient import TestClient
        with self.assertLogs('video_projects', level='WARNING'):
            p, req = self.run_plan(HTTPException(502, 'SENTINEL_SECRET'))
        client = TestClient(app.app, headers={'Authorization': 'Bearer synthetic'})
        app.app.dependency_overrides[app.auth] = lambda: {'id': 'alice', 'role': 'user', 'key_version': 1}
        try:
            with patch.object(app, 'VIDEO_PROJECTS', self.service):
                response = client.get(f"/v1/video-projects/{p['id']}")
                self.assertEqual(response.status_code, 200)
                self.assertEqual(response.json()['planning']['error_code'], 'upstream_failed')
                response = client.get(f"/v1/video-projects/{p['id']}/requests/{req['request_id']}")
                self.assertEqual(response.status_code, 200)
                self.assertEqual(response.json()['error_stage'], 'adapter')
        finally:
            app.app.dependency_overrides.clear()
        for value in ({}, {'choices': []}, {'choices': [{'message': {'content': 4}}]}):
            with patch.object(app, 'chat_completions', AsyncMock(return_value=value)):
                with self.assertRaises(PlanningFailure) as error:
                    asyncio.run(app._project_planner(project, None))
                self.assertEqual(error.exception.stage, 'adapter_response')
        for exc, expected in ((app.MuseAuthError('SENTINEL_SECRET'), 'auth_failed'),
                              (app.MuseGenerationError('SENTINEL_SECRET'), 'upstream_failed')):
            with patch.object(app, 'chat_completions', AsyncMock(side_effect=exc)):
                with self.assertRaises(PlanningFailure) as error:
                    asyncio.run(app._project_planner(project, None))
                self.assertEqual(error.exception.code, expected)

    def test_categories_schema_bounds_and_adapter_shapes(self):
        from video_projects import PlanningFailure, planning_content
        cases = [
            (PlanningFailure('no_account'), 'no_account', 'adapter'),
            (HTTPException(401, 'SENTINEL_SECRET cookies'), 'auth_failed', 'adapter'),
            (HTTPException(403, 'SENTINEL_SECRET key'), 'auth_failed', 'adapter'),
            (HTTPException(502, 'SENTINEL_SECRET response'), 'upstream_failed', 'adapter'),
            (HTTPException(429, 'SENTINEL_SECRET quota'), 'upstream_failed', 'adapter'),
            (RuntimeError('SENTINEL_SECRET unknown'), 'unknown', 'adapter'),
            (None, 'upstream_failed', 'adapter_response'),
            ('x' * 64001, 'upstream_failed', 'adapter_response'),
            ('```json\n{}\n```', 'invalid_json', 'parse'),
        ]
        drafts = [None, [], {'script': 4, 'scenes': []},
                  {'script': 'Draft', 'scenes': [{'order': 0, 'narration': '', 'prompt': 'x', 'duration': '1'}]},
                  {'script': 'Draft', 'scenes': [{'order': 0, 'narration': '', 'prompt': 'x', 'duration': 1, 'approved': True}]},
                  {'script': 'Draft', 'scenes': [{'order': 0, 'narration': '', 'prompt': 'x', 'duration': 1, 'SENTINEL_SECRET': 'secret'}]},
                  {'script': 'Draft', 'scenes': [{'order': 0, 'narration': '', 'prompt': 'x', 'duration': 1}] * 2},
                  {'script': 'Draft', 'scenes': [{'order': i, 'narration': '', 'prompt': 'x', 'duration': 15} for i in range(9)]}]
        cases.extend((json.dumps(d), 'invalid_schema', 'schema') for d in drafts)
        for value, code, stage in cases:
            with self.subTest(code=code, stage=stage), self.assertLogs('video_projects', level='WARNING') as logs:
                p, req = self.run_plan(value)
                self.assertEqual(p['planning']['error_code'], code)
                self.assertEqual(p['planning']['error_stage'], stage)
                self.assertEqual(p['script'], '')
                self.assertNotIn('SENTINEL_SECRET', self.service.path.read_text() + str(logs.output))
                receipt = self.service.request_status('alice', p['id'], req['request_id'])
                self.assertEqual(receipt['error_code'], code)
                restarted = ProjectService(self.service.path)
                self.assertEqual(restarted.request_status('alice', p['id'], req['request_id'])['error_code'], code)
        for receipt in self.service.data['requests'].values():
            self.assertIsNotNone(receipt['state']['error_code'])
        for response in ({}, {'choices': []}, {'choices': [None]}, {'choices': [{'message': {'content': None}}]}):
            with self.subTest(response=response):
                try:
                    planning_content(response)
                except PlanningFailure as exc:
                    with self.assertLogs('video_projects', level='WARNING'):
                        p, _ = self.run_plan(exc)
                    self.assertEqual(p['planning']['error_stage'], 'adapter_response')
                else:
                    self.fail('Malformed adapter envelope accepted')

    def test_revision_conflict_preserves_human_edit(self):
        import threading
        s = self.service
        p = s.create('alice', {'title': 'Test', 'idea': 'Idea'})
        entered, gate = threading.Event(), threading.Event()
        async def adapter(snapshot):
            entered.set()
            gate.wait(5)
            return json.dumps({'script': 'Generated', 'scenes': [
                {'order': 0, 'narration': '', 'prompt': 'Sky', 'duration': 1}]})
        with self.assertLogs('video_projects', level='WARNING'):
            try:
                asyncio.run(s.plan('alice', p['id'], {'revision': p['revision'], 'request_id': str(uuid4())}, adapter))
                self.assertTrue(entered.wait(2))
                current = s.get('alice', p['id'])
                s.patch('alice', p['id'], {'revision': current['revision'], 'script': 'Human'})
            finally:
                gate.set()
                for thread in s.threads:
                    thread.join(5)
        current = s.get('alice', p['id'])
        self.assertEqual(current['script'], 'Human')
        self.assertEqual(current['planning']['error_code'], 'project_changed')
        self.assertEqual(current['planning']['error_stage'], 'apply')

    def test_success_has_no_failure_metadata(self):
        value = json.dumps({'script': 'Draft', 'scenes': [
            {'order': 0, 'narration': '', 'prompt': 'Sky', 'duration': 1}]})
        p, req = self.run_plan(value)
        self.assertEqual(p['planning']['status'], 'completed')
        self.assertIsNone(p['planning']['error_code'])
        self.assertIsNone(p['planning']['error_stage'])
        self.assertEqual(p['script'], 'Draft')
        self.assertFalse(p['script_approved'])

    def test_invalid_json_is_actionable_and_redacted_at_durable_boundary(self):
        with self.assertLogs('video_projects', level='WARNING') as logs:
            p, req = self.run_plan('SENTINEL_SECRET model response')
        planning = p['planning']
        self.assertEqual(planning['error_code'], 'invalid_json')
        self.assertEqual(planning['error_stage'], 'parse')
        self.assertEqual(planning['stage'], 'failed')
        self.assertIn('JSON', planning['error'])
        self.assertNotIn('SENTINEL_SECRET', self.service.path.read_text() + str(logs.output))
        receipt = self.service.request_status('alice', p['id'], req['request_id'])
        self.assertEqual(receipt['error_code'], 'invalid_json')
        self.assertEqual(receipt['error_stage'], 'parse')
        self.assertEqual(p['script'], '')
        event = json.loads(logs.records[0].getMessage())
        self.assertEqual(event['project_id'], p['id'])
        self.assertEqual(event['request_id'], req['request_id'])
        self.assertEqual(event['exception_class'], 'JSONDecodeError')
        with self.assertRaises(HTTPException) as denied:
            self.service.request_status('bob', p['id'], req['request_id'])
        self.assertEqual(denied.exception.status_code, 404)


if __name__ == '__main__':
    unittest.main()
