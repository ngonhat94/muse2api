"""Synthetic offline tests for every persisted-media result consumer."""
import base64
import os
import socket
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import app
from config import Config
from store import Store


class MediaBoundaryTests(unittest.TestCase):
    def test_runner_denies_unmocked_network(self):
        with self.assertRaisesRegex(AssertionError, 'EXTERNAL IO FORBIDDEN'):
            socket.getaddrinfo('offline.invalid', 443)

    def test_b64_ignores_result_path_and_reads_exact_owned_bytes(self):
        with tempfile.TemporaryDirectory() as home:
            store = Store(Config(base_dir=home))
            owned = b'\x00owned\xff\n'
            store.write_media('safe.png', owned, 'A')
            secret = Path(home) / 'secret'
            secret.write_bytes(b'outside secret')
            result = dict(filename='safe.png', kind='image', size=len(owned), path=str(secret))
            with patch.object(app, 'store', store), patch.object(app, 'media_url', return_value='/synthetic'):
                response = app._image_response(app.ImageRequest(prompt='synthetic', response_format='b64_json'), result, 'A')
            self.assertEqual(base64.b64decode(response['data'][0]['b64_json']), owned)
            self.assertNotIn('url', response['data'][0])

    def test_b64_rejects_parent_and_leaf_symlinks(self):
        for swap in ('parent', 'leaf'):
            with self.subTest(swap=swap), tempfile.TemporaryDirectory() as home:
                store = Store(Config(base_dir=home))
                store.write_media('safe.png', b'owned', 'A')
                media = Path(store.cfg.media_dir)
                outside = Path(home) / 'outside'
                outside.mkdir()
                (outside / 'safe.png').write_bytes(b'secret')
                if swap == 'parent':
                    media.rename(media.with_name('parked'))
                    media.symlink_to(outside, target_is_directory=True)
                else:
                    (media / 'safe.png').unlink()
                    (media / 'safe.png').symlink_to(outside / 'safe.png')
                result = dict(filename='safe.png', path=str(media / 'safe.png'), kind='image', size=5)
                with patch.object(app, 'store', store), patch.object(app, 'media_url', return_value='/synthetic'), self.assertRaises((OSError, ValueError)):
                    app._image_response(app.ImageRequest(prompt='synthetic', response_format='b64_json'), result, 'A')

    def test_deletion_parent_swap_at_unlink_never_deletes_outside(self):
        for endpoint in ('single', 'batch', 'store'):
            with self.subTest(endpoint=endpoint), tempfile.TemporaryDirectory() as home:
                store = Store(Config(base_dir=home))
                store.write_media('safe.png', b'owned', 'A')
                media = Path(store.cfg.media_dir)
                parked = media.with_name('parked')
                outside = Path(home) / 'outside'
                outside.mkdir()
                (outside / 'safe.png').write_bytes(b'outside')
                real_unlink = os.unlink
                swapped = False
                def swap_then_unlink(path, *args, **kwargs):
                    nonlocal swapped
                    if not swapped:
                        swapped = True
                        media.rename(parked)
                        media.symlink_to(outside, target_is_directory=True)
                    return real_unlink(path, *args, **kwargs)
                with patch.object(app, 'store', store), patch.object(app, 'CFG', store.cfg), \
                     patch('os.unlink', side_effect=swap_then_unlink), patch('os.remove', side_effect=swap_then_unlink):
                    if endpoint == 'single':
                        app.delete_single_media('safe.png', {'id': 'A'})
                    elif endpoint == 'batch':
                        self.assertEqual(app.delete_media({'names': ['safe.png']}, {'id': 'A'})['removed'], 1)
                    else:
                        self.assertTrue(store.delete_media('safe.png', 'A'))
                self.assertEqual((outside / 'safe.png').read_bytes(), b'outside')
                self.assertFalse((parked / 'safe.png').exists())
                self.assertIsNone(store.media_owner('safe.png'))

    def test_delete_rejects_unsafe_parent_and_leaf_preserving_index(self):
        for swap in ('parent', 'leaf'):
            with self.subTest(swap=swap), tempfile.TemporaryDirectory() as home:
                store = Store(Config(base_dir=home))
                store.write_media('safe.png', b'owned', 'A')
                media = Path(store.cfg.media_dir)
                outside = Path(home) / 'outside'
                outside.mkdir()
                (outside / 'safe.png').write_bytes(b'secret')
                if swap == 'parent':
                    media.rename(media.with_name('parked'))
                    media.symlink_to(outside, target_is_directory=True)
                else:
                    (media / 'safe.png').unlink()
                    (media / 'safe.png').symlink_to(outside / 'safe.png')
                with self.assertRaises((OSError, ValueError)):
                    store.delete_media('safe.png', 'A')
                self.assertEqual(store.media_owner('safe.png'), 'A')
                self.assertEqual((outside / 'safe.png').read_bytes(), b'secret')

    def test_delete_batch_partial_errors_and_owner_isolation(self):
        with tempfile.TemporaryDirectory() as home:
            store = Store(Config(base_dir=home))
            for name, owner in [('ok.png', 'A'), ('blocked.png', 'A'), ('other.png', 'B')]:
                store.write_media(name, name.encode(), owner)
            unlink = os.unlink
            def fail_one(name, *args, **kwargs):
                if name == 'blocked.png':
                    raise PermissionError('synthetic failure')
                return unlink(name, *args, **kwargs)
            with patch.object(app, 'store', store), patch.object(app, 'CFG', store.cfg), patch('os.unlink', side_effect=fail_one):
                response = app.delete_media({'names': ['ok.png', 'blocked.png', 'other.png', 'missing.png', '../bad']}, {'id': 'A'})
            self.assertEqual(response['removed'], 1)
            self.assertEqual(len(response['errors']), 2)
            self.assertIsNone(store.media_owner('ok.png'))
            self.assertEqual(store.media_owner('blocked.png'), 'A')
            self.assertEqual(store.media_owner('other.png'), 'B')
            self.assertEqual((Path(store.cfg.media_dir) / 'other.png').read_bytes(), b'other.png')
            self.assertFalse(store.delete_media('other.png', 'A'))

    def test_listing_does_not_follow_leaf_or_parent_symlinks(self):
        for swap in ('parent', 'leaf'):
            with self.subTest(swap=swap), tempfile.TemporaryDirectory() as home:
                store = Store(Config(base_dir=home))
                store.write_media('safe.png', b'owned', 'A')
                media = Path(store.cfg.media_dir)
                outside = Path(home) / 'outside'
                outside.mkdir()
                (outside / 'safe.png').write_bytes(b'secret metadata')
                if swap == 'parent':
                    media.rename(media.with_name('parked'))
                    media.symlink_to(outside, target_is_directory=True)
                else:
                    (media / 'safe.png').unlink()
                    (media / 'safe.png').symlink_to(outside / 'safe.png')
                with patch.object(app, 'store', store), patch.object(app, 'CFG', store.cfg), patch.object(app, 'media_url', return_value='/synthetic'):
                    self.assertEqual(app.admin_media({'id': 'A'}), {'media': [], 'count': 0})

    def test_cancelled_workers_ignore_untrusted_result_path(self):
        import asyncio
        from types import SimpleNamespace
        for kind in ('image', 'video'):
            with self.subTest(kind=kind), tempfile.TemporaryDirectory() as home:
                store = Store(Config(base_dir=home))
                store.write_media('safe.png', b'owned', 'admin')
                secret = Path(home) / 'secret'
                secret.write_bytes(b'outside')
                result = dict(filename='safe.png', kind=kind, size=5, path=str(secret))
                workers = []
                def thread(**kwargs):
                    return SimpleNamespace(start=lambda: workers.append(kwargs['target']))
                def generate(*args, **kwargs):
                    task = next(iter(store.tasks.values()))
                    store.cancel_task(task['id'])
                    return result, 'synthetic-account'
                job = SimpleNamespace(check=lambda: None, release=lambda: None, task_id=None)
                # Initialize asyncio's real executor before the thread capture.
                async def queue_video():
                    await asyncio.to_thread(lambda: None)
                    with patch.object(app.threading, 'Thread', side_effect=thread):
                        return await app.create_video.__wrapped__(app.VideoRequest(prompt='synthetic'), {'id': 'admin'})
                with patch.object(app, 'store', store), patch.object(app, 'CFG', store.cfg), \
                     patch.object(app, '_run_generation', side_effect=generate), \
                     patch.object(app, '_prepare_reference_images', return_value=[]), \
                     patch.object(app, 'OutstandingJob', return_value=job):
                    if kind == 'image':
                        with patch.object(app.threading, 'Thread', side_effect=thread):
                            app._queue_image(app.ImageRequest(prompt='synthetic'), 'synthetic', [])
                    else:
                        asyncio.run(queue_video())
                    self.assertEqual(len(workers), 1)
                    workers[0]()
                self.assertTrue(secret.exists(), 'untrusted result path was deleted')
                self.assertEqual(secret.read_bytes(), b'outside')
                self.assertFalse((Path(store.cfg.media_dir) / 'safe.png').exists())
                self.assertIsNone(store.media_owner('safe.png'))

    def test_public_task_does_not_refresh_unsafe_media_capability(self):
        with tempfile.TemporaryDirectory() as home:
            store = Store(Config(base_dir=home))
            store.write_media('safe.png', b'owned', 'A')
            leaf = Path(store.cfg.media_dir) / 'safe.png'
            secret = Path(home) / 'secret'
            secret.write_bytes(b'outside')
            leaf.unlink()
            leaf.symlink_to(secret)
            task = dict(kind='image', result=dict(filename='safe.png'))
            with patch.object(app, 'store', store), patch.object(app, 'CFG', store.cfg), patch.object(app, 'media_url', return_value='/new-cap') as url:
                app._public_task(task, 'A')
                url.assert_not_called()

    def test_legacy_adoption_rejects_media_symlinks(self):
        for swap in ('parent', 'leaf'):
            with self.subTest(swap=swap), tempfile.TemporaryDirectory() as home:
                cfg = Config(base_dir=home)
                cfg.ensure_dirs()
                media = Path(cfg.media_dir)
                outside = Path(home) / 'outside'
                outside.mkdir()
                (outside / 'safe.png').write_bytes(b'secret')
                if swap == 'parent':
                    media.rmdir()
                    media.symlink_to(outside, target_is_directory=True)
                    with self.assertRaises((OSError, ValueError)):
                        Store(cfg)
                else:
                    (media / 'safe.png').symlink_to(outside / 'safe.png')
                    self.assertIsNone(Store(cfg).media_owner('safe.png'))

    def test_b64_parent_and_leaf_swap_after_open_reads_original_descriptor(self):
        from contextlib import contextmanager
        for swap in ('parent', 'leaf'):
            with self.subTest(swap=swap), tempfile.TemporaryDirectory() as home:
                store = Store(Config(base_dir=home))
                store.write_media('safe.png', b'original\x00\xff', 'A')
                media = Path(store.cfg.media_dir)
                outside = Path(home) / 'outside'
                outside.mkdir()
                (outside / 'safe.png').write_bytes(b'secret')
                opener = store.open_media
                handles = []
                @contextmanager
                def swapped(name):
                    with opener(name) as handle:
                        handles.append(handle)
                        if swap == 'parent':
                            media.rename(media.with_name('parked'))
                            media.symlink_to(outside, target_is_directory=True)
                        else:
                            (media / name).unlink()
                            (media / name).symlink_to(outside / name)
                        yield handle
                with patch.object(app, 'store', store), patch.object(app, 'media_url', return_value='/synthetic'), patch.object(store, 'open_media', side_effect=swapped):
                    result = app._image_response(app.ImageRequest(prompt='synthetic', response_format='b64_json'), dict(filename='safe.png', kind='image', size=10), 'A')
                self.assertEqual(base64.b64decode(result['data'][0]['b64_json']), b'original\x00\xff')
                self.assertTrue(handles[0].closed)

    def test_normal_listing_single_delete_missing_and_foreign_owner(self):
        from fastapi import HTTPException
        with tempfile.TemporaryDirectory() as home:
            store = Store(Config(base_dir=home))
            store.write_media('a.png', b'A\x00', 'A')
            store.write_media('b.png', b'BBB', 'B')
            with patch.object(app, 'store', store), patch.object(app, 'media_url', return_value='/synthetic'):
                listed = app.admin_media({'id': 'A'})
                self.assertEqual(listed['count'], 1)
                self.assertEqual(listed['media'][0]['bytes'], 2)
                self.assertEqual(listed['media'][0]['name'], 'a.png')
                for name in ('b.png', 'missing.png'):
                    with self.assertRaises(HTTPException) as caught:
                        app.delete_single_media(name, {'id': 'A'})
                    self.assertEqual(caught.exception.status_code, 404)
                self.assertEqual(app.delete_single_media('a.png', {'id': 'A'}), {'status': 'ok', 'deleted': 'a.png'})
            self.assertEqual(store.storage_usage('A')['files'], 0)
            self.assertEqual(store.storage_usage('B')['bytes'], 3)

    def test_browser_fallback_result_size_never_reopens_media_path(self):
        import time
        from engine import MuseEngine
        with tempfile.TemporaryDirectory() as home:
            store = Store(Config(base_dir=home))
            engine = MuseEngine(store.cfg)
            engine.media_limits = store.storage_limits
            engine._ensure_local().media_owner = 'A'
            source = Path(home) / 'download.png'
            source.write_bytes(b'owned')
            def persist(name, data, owner):
                result = store.write_media(name, data, owner)
                media = Path(store.cfg.media_dir)
                media.rename(media.with_name('parked'))
                outside = Path(home) / 'outside'
                outside.mkdir()
                (outside / name).write_bytes(b'outside-different-size')
                media.symlink_to(outside, target_is_directory=True)
                return result
            engine.media_writer = persist
            with patch.object(engine, 'attachments', return_value=[]), patch.object(engine, '_agent_count', return_value=0), \
                 patch.object(engine, '_send', return_value='clicked'), patch.object(engine, '_wait_attachment', return_value={'src': 'synthetic'}), \
                 patch.object(engine, 'extract_bytes', return_value=(None, None, None)), patch.object(engine, '_download_fallback', return_value=str(source)):
                result = engine._generate_attached('test', 'image', time.monotonic() + 5, None, None, set())
            self.assertEqual(result['size'], 5)

    def test_leaf_swap_at_unlink_cannot_delete_symlink_target(self):
        with tempfile.TemporaryDirectory() as home:
            store = Store(Config(base_dir=home))
            store.write_media('safe.png', b'owned', 'A')
            leaf = Path(store.cfg.media_dir) / 'safe.png'
            secret = Path(home) / 'secret'
            secret.write_bytes(b'outside')
            unlink = os.unlink
            def swap(name, *args, **kwargs):
                unlink(leaf)
                leaf.symlink_to(secret)
                return unlink(name, *args, **kwargs)
            with patch('os.unlink', side_effect=swap):
                self.assertTrue(store.delete_media('safe.png', 'A'))
            self.assertEqual(secret.read_bytes(), b'outside')
            self.assertFalse(leaf.is_symlink())
            self.assertIsNone(store.media_owner('safe.png'))


if __name__ == '__main__':
    unittest.main()
