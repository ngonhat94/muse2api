"""Synthetic DOM snapshots only; no provider or browser requests."""
import asyncio
import json
from typing import Any
import unittest
from types import SimpleNamespace
from unittest.mock import Mock, patch

from engine import MuseEngine, MuseGenerationError
from video_projects import parse_planning_json


DRAFT = {'script': 'Synthetic story', 'scenes': [
    {'order': 0, 'narration': 'Story', 'prompt': 'Morning', 'duration': 10}]}
VALID = json.dumps(DRAFT)
# Minimal analogue of the reported malformed scenes object and unfinished prompt.
BROKEN = '{"script":"Synthetic story","scenes":{"order":0,"prompt":"Morning,'


class ChatSnapshotsTest(unittest.TestCase):
    def engine(self, texts) -> Any:
        engine: Any = object.__new__(MuseEngine)
        engine.cfg = SimpleNamespace(chat_timeout=30)
        engine.ensure_page = Mock()
        engine.reset_thread = Mock()
        engine._send = Mock()
        polls = [(0, '', False)] + [(1, text, True) for text in texts]
        polls += [(1, texts[-1], False)] * 3
        engine._poll_chat = Mock(side_effect=polls)
        self.addCleanup(patch.stopall)
        patch('engine.time.sleep').start()
        return engine

    def test_nonstream_replaces_malformed_prefix_with_corrected_snapshot(self):
        engine = self.engine([BROKEN, VALID])
        result = engine.chat({}, 'synthetic')
        self.assertEqual(result, VALID)
        self.assertEqual(parse_planning_json(result), DRAFT)
        self.assertEqual(engine._send.call_args.args, ('synthetic',))

    def test_append_only_deltas_preserve_true_repetition(self):
        engine = self.engine(['ha', 'haha', 'hahaha'])
        self.assertEqual(list(engine.chat_stream({}, 'synthetic')), ['ha', 'ha', 'ha'])

    def test_stream_revision_fails_instead_of_concatenating(self):
        engine = self.engine([BROKEN, VALID])
        stream = engine.chat_stream({}, 'synthetic')
        self.assertEqual(next(stream), BROKEN)
        with self.assertRaisesRegex(MuseGenerationError, 'revised text'):
            next(stream)

    def test_full_snapshot_replacements_and_shrink(self):
        for texts in ([BROKEN, VALID[:40], VALID], [VALID + 'trailing', VALID],
                      ['old bubble', VALID], ['x', 'xy', 'x', VALID]):
            with self.subTest(texts=texts):
                self.assertEqual(self.engine(texts).chat({}, 'synthetic'), VALID)

    def test_plain_and_fence_unchanged(self):
        for text in (VALID, '```json\n' + VALID + '\n```'):
            with self.subTest(text=text):
                result = self.engine([text[:5], text]).chat({}, 'synthetic')
                self.assertEqual(result, text)
                self.assertEqual(parse_planning_json(result), DRAFT)

    def test_same_snapshot_containing_corruption_is_not_repaired(self):
        for text in (BROKEN + VALID, VALID + VALID, VALID[:-3]):
            with self.subTest(text=text):
                result = self.engine([text]).chat({}, 'synthetic')
                self.assertEqual(result, text)
                with self.assertRaises(Exception):
                    parse_planning_json(result)

    def test_actual_nonstream_adapter_and_worker_keep_final_snapshot(self):
        import app
        from unittest.mock import MagicMock
        engine = self.engine([BROKEN, VALID])
        engine.start = Mock()
        engine.close_current_page = Mock()
        engine._ensure_local = Mock(return_value=SimpleNamespace())
        with patch.object(app, 'engine', engine), \
             patch.object(app, 'OutstandingJob', return_value=MagicMock()), \
             patch.object(app, 'ACCOUNT_POOL', MagicMock()), \
             patch.object(app, '_bind_account_proxy'), \
             patch.object(app, '_renew_and_persist', return_value=None), \
             patch.object(app, '_sync_cookies'), \
             patch.object(app.store, 'mark'), \
             patch.object(app.store, 'pick_account', return_value={'id': 'fixture', 'cookies': {}}):
            result = asyncio.run(app.chat_completions(
                app.ChatRequest(prompt='synthetic', stream=False),
                {'id': 'alice', 'role': 'user', 'key_version': 1}))
        self.assertEqual(result['choices'][0]['message']['content'], VALID)
        self.assertEqual(engine._send.call_count, 1)

    def test_final_only_worker_failure_does_not_retry_or_rotate(self):
        import app
        from unittest.mock import MagicMock
        engine = self.engine([VALID])
        engine.start = Mock()
        engine.close_current_page = Mock()
        engine.chat_stream = Mock(side_effect=MuseGenerationError('synthetic failure'))
        pool = MagicMock()
        with patch.object(app, 'engine', engine), \
             patch.object(app, 'ACCOUNT_POOL', pool), \
             patch.object(app, '_bind_account_proxy'), \
             patch.object(app, '_renew_and_persist', return_value=None), \
             patch.object(app.store, 'mark'):
            with self.assertRaisesRegex(MuseGenerationError, 'synthetic failure'):
                list(app.safe_chat_stream({}, 'synthetic', None, 2, 'fixture',
                     owner_id='alice', job=MagicMock(), final_only=True))
        self.assertEqual(engine.chat_stream.call_count, 1)
        self.assertEqual(pool.acquire.call_count, 1)
        self.assertFalse(pool.acquire.call_args.kwargs.get('rotate', False))

    def test_cancelled_final_only_never_emits_partial_snapshot(self):
        import threading
        stop = threading.Event()
        engine = self.engine([BROKEN])
        def poll():
            if engine._send.called:
                stop.set()
                return 1, BROKEN, True
            return 0, '', False
        engine._poll_chat.side_effect = poll
        self.assertEqual(list(engine.chat_stream({}, 'synthetic', stop_event=stop,
                                                final_only=True)), [])

    def test_unfinished_generation_is_not_a_success_or_retry(self):
        engine = self.engine([VALID])
        engine._poll_chat.side_effect = [(0, '', False)] + [(1, VALID, True)] * 82
        with self.assertRaisesRegex(MuseGenerationError, 'did not finish'):
            engine.chat({}, 'synthetic')
        self.assertEqual(engine._send.call_count, 1)


if __name__ == '__main__':
    unittest.main()
