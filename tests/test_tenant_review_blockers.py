"""Offline regressions for multi-tenant review blockers."""
import asyncio
import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from tenant import UserStore
from store import Store

class SharedUsers(unittest.TestCase):
    def test_revocation_is_fresh_across_instances_and_writes_preserve_users(self):
        with tempfile.TemporaryDirectory() as home:
            path = str(Path(home) / 'users.json')
            first, second = UserStore(path), UserStore(path)
            a, key = first.create('a')
            self.assertIsNotNone(second.authenticate(key))
            second.create('b')
            first.revoke(a['id'])
            self.assertIsNone(second.authenticate(key))
            self.assertEqual(len(first.list()), 2)

    def test_process_writes_and_revocations_are_shared(self):
        import subprocess
        with tempfile.TemporaryDirectory() as home:
            path = str(Path(home)/'users.json')
            store = UserStore(path)
            user, key = store.create('parent')
            script = 'from tenant import UserStore; import sys; s=UserStore(sys.argv[1]); s.create("child"); s.revoke(sys.argv[2])'
            result = subprocess.run([sys.executable, '-c', script, path, user['id']], cwd=ROOT, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIsNone(store.authenticate(key))
            self.assertEqual(len(store.list()), 2)

class Migration(unittest.TestCase):
    def test_restart_does_not_adopt_unknown_or_lost_index_media(self):
        with tempfile.TemporaryDirectory() as home:
            cfg = SimpleNamespace(accounts_file=home+'/accounts.json', tasks_file=home+'/tasks.json', media_index_file=home+'/media-index.json', media_dir=home+'/media')
            Path(cfg.media_dir).mkdir()
            (Path(cfg.media_dir)/'legacy.png').write_bytes(b'legacy')
            self.assertEqual(Store(cfg).media_owner('legacy.png'), 'admin')
            (Path(cfg.media_dir)/'unknown.png').write_bytes(b'new')
            self.assertIsNone(Store(cfg).media_owner('unknown.png'))
            Path(cfg.media_index_file).unlink()
            self.assertIsNone(Store(cfg).media_owner('legacy.png'))
            Path(cfg.media_index_file).write_text('{corrupt')
            self.assertIsNone(Store(cfg).media_owner('legacy.png'))
            Path(cfg.media_index_file).write_text(json.dumps({'legacy.png': {}}))
            self.assertIsNone(Store(cfg).media_owner('legacy.png'))

class RuntimeBlockers(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.home = tempfile.TemporaryDirectory()
        os.environ['MUSE2API_HOME'] = cls.home.name
        os.environ['MUSE2API_KEY'] = 'synthetic-admin'
        spec = importlib.util.spec_from_file_location('review_app', ROOT/'app.py')
        cls.module = importlib.util.module_from_spec(spec)
        sys.modules[spec.name] = cls.module
        spec.loader.exec_module(cls.module)

    def test_stream_early_disconnect_releases_pre_worker_reservation(self):
        m = self.module
        from unittest.mock import MagicMock
        from starlette.requests import ClientDisconnect
        user, key = m.users.create('early-stream')
        principal = m.users.authenticate(key)
        m.store.add_account({'hatch_sess': 'fixture'}, owner_id=user['id'])
        fake = MagicMock()
        async def check():
            for route, request, path, payload in (
                (m.chat_completions, m.ChatRequest(prompt='fixture', stream=True), '/v1/chat/completions', {'prompt':'fixture','stream':True}),
                (m.responses_api, m.ResponsesRequest(input='fixture', stream=True), '/v1/responses', {'input':'fixture','stream':True}),
            ):
                with self.subTest(route=path, disconnect='unstarted aclose'):
                    response = await route(request, principal)
                    await response.body_iterator.aclose()
                    self.assertFalse(any(j.owner_id == user['id'] for j in m.OutstandingJob._jobs))
                with self.subTest(route=path, disconnect='aclose'):
                    response = await route(request, principal)
                    await response.body_iterator.__anext__()
                    await response.body_iterator.aclose()
                    self.assertFalse(any(j.owner_id == user['id'] for j in m.OutstandingJob._jobs))
                with self.subTest(route=path, disconnect='ASGI first send'):
                    scope = {'type':'http','asgi':{'version':'3.0','spec_version':'2.4'},'http_version':'1.1','method':'POST','scheme':'http','path':path,'raw_path':path.encode(),'query_string':b'','root_path':'','headers':[(b'authorization',('Bearer '+key).encode()),(b'content-type',b'application/json')],'server':('fixture',80),'client':('fixture',1)}
                    async def receive(): return {'type':'http.request','body':json.dumps(payload).encode(),'more_body':False}
                    async def send(message):
                        if message['type'] == 'http.response.body': raise OSError('fixture disconnect')
                    try: await m.app(scope, receive, send)
                    except ClientDisconnect: pass
                    self.assertFalse(any(j.owner_id == user['id'] for j in m.OutstandingJob._jobs))
            fake.start.assert_not_called()
            fake.chat_stream.assert_not_called()
        try:
            with patch.object(m, 'engine', fake): asyncio.run(check())
        finally:
            for job in list(m.OutstandingJob._jobs): job.release()

    def test_maintenance_rechecks_authority_after_account_wait_all_aliases(self):
        m = self.module
        from contextlib import contextmanager
        from unittest.mock import MagicMock
        original = m._account_operation
        for action in ('revoke', 'disable', 'rotate'):
            for name in ('test_account_proxy','test_account','relogin_account','relogin','query_quota','query_any_quota','trigger_keepalive_single','trigger_keepalive_all'):
                with self.subTest(action=action, route=name):
                    user, key = m.users.create('maintenance')
                    principal = m.users.authenticate(key)
                    account = m.store.add_account({'hatch_sess':'fixture'}, owner_id=user['id'])
                    m.store.update_account(account['id'], owner_id=user['id'], proxy={'server':'http://proxy.invalid:8080'})
                    session = MagicMock()
                    session.__enter__.return_value = session
                    session.get.return_value.status_code = 200
                    session.get.return_value.json.return_value = {'ip':'203.0.113.7'}
                    fake = MagicMock()
                    fake.quota.return_value = {'found':True}
                    fake.renew_session_http.return_value = {'cookies':account['cookies'],'cookies_exp':{},'ok':True}
                    @contextmanager
                    def waited(*args, **kwargs):
                        with original(*args, **kwargs) as acc:
                            if action == 'disable': m.users.patch(user['id'], enabled=False)
                            elif action == 'revoke': m.users.revoke(user['id'])
                            else: m.users.rotate(user['id'])
                            yield acc
                    async def invoke():
                        fn = getattr(m, name)
                        if name == 'relogin': return await fn(principal)
                        if name in ('query_any_quota','trigger_keepalive_all'): return await fn(principal=principal)
                        result = fn(account['id'], principal=principal)
                        return await result if m.inspect.isawaitable(result) else result
                    with patch.object(m, 'engine', fake), patch.object(m, '_account_operation', waited), patch('requests.Session', return_value=session):
                        try: asyncio.run(invoke())
                        except (m.MuseAuthError, m.HTTPException): pass
                    session.get.assert_not_called()
                    for method in ('start','refresh','quota','renew_session_http'):
                        self.assertEqual(getattr(fake, method).call_count, 0, method)
                    self.assertFalse(any(j.owner_id == user['id'] for j in m.OutstandingJob._jobs))

    def test_proxy_rechecks_authority_before_each_outbound_operation(self):
        m = self.module
        from unittest.mock import MagicMock
        from contextlib import contextmanager
        for boundary in ('proxy_context', 'ipify'):
            for action in ('revoke', 'disable', 'rotate'):
                with self.subTest(boundary=boundary, action=action):
                    user, key = m.users.create('proxy-boundary')
                    principal = m.users.authenticate(key)
                    account = m.store.add_account({'hatch_sess':'fixture'}, owner_id=user['id'])
                    m.store.update_account(account['id'], owner_id=user['id'], proxy={'server':'http://proxy.invalid:8080'})
                    def invalidate():
                        if action == 'disable': m.users.patch(user['id'], enabled=False)
                        elif action == 'rotate': m.users.rotate(user['id'])
                        else: m.users.revoke(user['id'])
                    @contextmanager
                    def proxy_context(proxy):
                        if boundary == 'proxy_context': invalidate()
                        yield {}
                    session = MagicMock()
                    session.__enter__.return_value = session
                    response = SimpleNamespace(status_code=200, json=lambda: {'ip':'203.0.113.7'})
                    def get(*args, **kwargs):
                        if boundary == 'ipify': invalidate()
                        return response
                    session.get.side_effect = get
                    fake = MagicMock()
                    fake.renew_session_http.return_value = {'status':200}
                    with patch.object(m, 'engine', fake), patch.object(m, 'request_proxy_context', proxy_context), patch('requests.Session', return_value=session):
                        try: asyncio.run(m.test_account_proxy(account['id'], principal=principal))
                        except m.MuseAuthError: pass
                    self.assertEqual(session.get.call_count, 0 if boundary == 'proxy_context' else 1)
                    fake.renew_session_http.assert_not_called()
                    self.assertFalse(any(j.owner_id == user['id'] for j in m.OutstandingJob._jobs))

    def test_disconnect_retains_live_chat_worker_both_routes(self):
        m = self.module
        import threading
        from unittest.mock import MagicMock
        for name in ('chat_completions', 'responses_api'):
            with self.subTest(route=name):
                user, key = m.users.create('live-stream')
                principal = m.users.authenticate(key)
                m.store.add_account({'hatch_sess':'fixture'}, owner_id=user['id'])
                running, finish, exited = threading.Event(), threading.Event(), threading.Event()
                fake = MagicMock()
                def upstream(*args, **kwargs):
                    try:
                        running.set()
                        yield 'fixture'
                        self.assertTrue(finish.wait(5))
                    finally: exited.set()
                fake.chat_stream.side_effect = upstream
                async def invoke():
                    request = m.ChatRequest(prompt='fixture',stream=True) if name == 'chat_completions' else m.ResponsesRequest(input='fixture',stream=True)
                    response = await getattr(m, name)(request, principal)
                    for _ in range(4 if name == 'responses_api' else 2):
                        await response.body_iterator.__anext__()
                    self.assertTrue(running.is_set())
                    await response.body_iterator.aclose()
                    self.assertEqual(sum(j.owner_id == user['id'] for j in m.OutstandingJob._jobs), 1)
                    finish.set()
                    self.assertTrue(await asyncio.to_thread(exited.wait, 5))
                    for _ in range(100):
                        if not any(j.owner_id == user['id'] for j in m.OutstandingJob._jobs): break
                        await asyncio.sleep(.01)
                    self.assertFalse(any(j.owner_id == user['id'] for j in m.OutstandingJob._jobs))
                try:
                    with patch.object(m, 'engine', fake), patch.object(m, '_renew_and_persist', return_value=None), patch.object(m, '_pace_text', side_effect=lambda s: [s]):
                        asyncio.run(invoke())
                finally: finish.set()

    def test_maintenance_admission_bound_all_aliases_and_old_principals(self):
        m = self.module
        from unittest.mock import MagicMock
        user, key = m.users.create('bounded-maintenance')
        principal = m.users.authenticate(key)
        account = m.store.add_account({'hatch_sess':'fixture'}, owner_id=user['id'])
        async def invoke(name, principal):
            fn = getattr(m, name)
            if name == 'relogin': return await fn(principal)
            if name in ('query_any_quota','trigger_keepalive_all'): return await fn(principal=principal)
            return await fn(account['id'], principal=principal)
        routes = ('test_account_proxy','test_account','relogin_account','relogin','query_quota','query_any_quota','trigger_keepalive_single','trigger_keepalive_all')
        jobs = [m.OutstandingJob(user['id']) for _ in range(8)]
        fake = MagicMock()
        try:
            with patch.object(m, 'engine', fake):
                for name in routes:
                    with self.subTest(route=name), self.assertRaises(m.HTTPException) as caught:
                        asyncio.run(invoke(name, principal))
                    self.assertEqual(caught.exception.status_code, 429)
        finally:
            for job in jobs: job.release()
        m.users.rotate(user['id'])
        with patch.object(m, 'engine', fake):
            for name in routes:
                with self.subTest(stale_route=name), self.assertRaises(m.MuseAuthError):
                    asyncio.run(invoke(name, principal))
        fake.start.assert_not_called()
        fake.renew_session_http.assert_not_called()

    def test_maintenance_waiting_gen_lock_and_keepalive_lock_recheck(self):
        m = self.module
        from unittest.mock import MagicMock
        for name in ('test_account','relogin','query_quota','trigger_keepalive_all'):
            for action in ('disable','revoke','rotate'):
                with self.subTest(route=name, action=action):
                    user, key = m.users.create('waited-maintenance')
                    principal = m.users.authenticate(key)
                    account = m.store.add_account({'hatch_sess':'fixture'}, owner_id=user['id'])
                    def invalidate():
                        if action == 'disable': m.users.patch(user['id'], enabled=False)
                        elif action == 'rotate': m.users.rotate(user['id'])
                        else: m.users.revoke(user['id'])
                    class Lock:
                        def __enter__(self): invalidate(); return self
                        def __exit__(self, *args): pass
                        async def __aenter__(self): invalidate(); return self
                        async def __aexit__(self, *args): pass
                    async def invoke():
                        if name == 'trigger_keepalive_all': return await m.trigger_keepalive_all(principal=principal)
                        if name == 'relogin': return await m.relogin(principal)
                        return await getattr(m, name)(account['id'], principal)
                    fake = MagicMock()
                    with patch.object(m, 'engine', fake), patch.object(m, 'KEEPALIVE_LOCK' if name == 'trigger_keepalive_all' else 'GEN_LOCK', Lock()):
                        try: asyncio.run(invoke())
                        except (m.HTTPException,m.MuseAuthError): pass
                    fake.start.assert_not_called()
                    fake.renew_session_http.assert_not_called()

    def test_cancelled_maintenance_retains_reservation_until_worker_exit(self):
        m = self.module
        import threading
        from unittest.mock import MagicMock
        user, key = m.users.create('cancel-maintenance')
        principal = m.users.authenticate(key)
        account = m.store.add_account({'hatch_sess':'fixture'}, owner_id=user['id'])
        entered, finish = threading.Event(), threading.Event()
        fake = MagicMock()
        def quota(*args, **kwargs):
            entered.set()
            self.assertTrue(finish.wait(5))
            return {'found':True}
        fake.quota.side_effect = quota
        async def invoke():
            task = asyncio.create_task(m.query_quota(account['id'], principal))
            self.assertTrue(await asyncio.to_thread(entered.wait, 5))
            task.cancel()
            with self.assertRaises(asyncio.CancelledError): await task
            self.assertEqual(sum(j.owner_id == user['id'] for j in m.OutstandingJob._jobs), 1)
            finish.set()
            for _ in range(100):
                if not any(j.owner_id == user['id'] for j in m.OutstandingJob._jobs): break
                await asyncio.sleep(.01)
            self.assertFalse(any(j.owner_id == user['id'] for j in m.OutstandingJob._jobs))
        try:
            with patch.object(m, 'engine', fake): asyncio.run(invoke())
        finally: finish.set()

    def test_cancelled_proxy_retains_worker_reservation_at_each_wait(self):
        m = self.module
        import threading
        from contextlib import contextmanager
        from unittest.mock import MagicMock
        for boundary in ('account', 'ipify', 'renew'):
            with self.subTest(boundary=boundary):
                user, key = m.users.create('cancel-proxy')
                principal = m.users.authenticate(key)
                account = m.store.add_account({'hatch_sess':'fixture'}, owner_id=user['id'])
                m.store.update_account(account['id'], owner_id=user['id'], proxy={'server':'http://proxy.invalid:8080'})
                entered, finish = threading.Event(), threading.Event()
                def wait():
                    entered.set()
                    self.assertTrue(finish.wait(5))
                original = m._account_operation
                @contextmanager
                def operation(*args, **kwargs):
                    with original(*args, **kwargs) as acc:
                        if boundary == 'account': wait()
                        yield acc
                session = MagicMock()
                session.__enter__.return_value = session
                def get(*args, **kwargs):
                    if boundary == 'ipify': wait()
                    return SimpleNamespace(status_code=200, json=lambda: {'ip':'203.0.113.7'})
                session.get.side_effect = get
                fake = MagicMock()
                def renew(*args, **kwargs):
                    if boundary == 'renew': wait()
                    return {'status':200}
                fake.renew_session_http.side_effect = renew
                async def invoke():
                    self.assertTrue(m.inspect.iscoroutinefunction(m.test_account_proxy))
                    task = asyncio.create_task(m.test_account_proxy(account['id'], principal=principal))
                    self.assertTrue(await asyncio.to_thread(entered.wait, 5))
                    task.cancel()
                    with self.assertRaises(asyncio.CancelledError): await task
                    self.assertEqual(sum(j.owner_id == user['id'] for j in m.OutstandingJob._jobs), 1)
                    jobs = [m.OutstandingJob(user['id']) for _ in range(7)]
                    try:
                        with patch.object(asyncio, 'to_thread') as dispatch:
                            with self.assertRaises(m.HTTPException) as caught:
                                await m.test_account_proxy(account['id'], principal=principal)
                            self.assertEqual(caught.exception.status_code, 429)
                            dispatch.assert_not_called()
                    finally:
                        for job in jobs: job.release()
                    finish.set()
                    for _ in range(100):
                        if not any(j.owner_id == user['id'] for j in m.OutstandingJob._jobs): break
                        await asyncio.sleep(.01)
                    self.assertFalse(any(j.owner_id == user['id'] for j in m.OutstandingJob._jobs))
                    self.assertEqual(session.get.call_count, 1)
                    self.assertEqual(fake.renew_session_http.call_count, 1)
                try:
                    with patch.object(m, 'engine', fake), patch.object(m, '_account_operation', operation), patch('requests.Session', return_value=session):
                        asyncio.run(invoke())
                finally: finish.set()

    def test_global_relogin_admits_before_executor_dispatch(self):
        import inspect
        self.assertTrue(inspect.iscoroutinefunction(self.module.relogin),
                        'sync route dispatch queues before bounded admission')

    def test_cancel_delete_cannot_release_worker_admission(self):
        m = self.module
        targets = []
        class Deferred:
            def __init__(self, target, **kw): targets.append(target)
            def start(self): pass
        with patch.object(m.threading, 'Thread', Deferred):
            for i in range(8):
                response = m._queue_image(m.ImageRequest(prompt=str(i)), str(i), [])
                tid = json.loads(response.body)['id']
                m.store.cancel_task(tid)
                m.store.delete_task(tid)
            with self.assertRaises(m.HTTPException) as caught:
                m._queue_image(m.ImageRequest(prompt='overflow'), 'overflow', [])
            self.assertEqual(caught.exception.status_code, 429)
        with patch.object(m, '_run_generation_locked') as run:
            for target in targets: target()
            run.assert_not_called()

    def test_cancel_after_lock_acquisition_never_calls_upstream(self):
        m = self.module
        task = m.store.create_task('image', 'blocked')
        job = m.OutstandingJob('admin')
        job.task_id = task['id']
        class Lock:
            def acquire(self, **kw):
                m.store.cancel_task(task['id'])
                m.store.clear_tasks()
                return True
            def release(self): pass
        try:
            with patch.object(m, 'GEN_LOCK', Lock()), patch.object(m, '_run_generation_locked') as run:
                with self.assertRaises(m.MuseAuthError):
                    m._run_generation('test', 'image', 1, job=job)
                run.assert_not_called()
        finally:
            job.release()

    def test_sync_image_uses_same_outstanding_limit(self):
        m = self.module
        jobs = [m.OutstandingJob('admin') for _ in range(8)]
        try:
            with self.assertRaises(m.HTTPException):
                m._run_generation('test', 'image', 1)
        finally:
            for job in jobs: job.release()

    def test_global_outstanding_bound_is_independent_of_task_records(self):
        m = self.module
        jobs = []
        try:
            for index in range(8):
                user, _ = m.users.create('tenant-'+str(index))
                jobs.extend(m.OutstandingJob(user['id']) for _ in range(8))
            with self.assertRaises(m.HTTPException): m.OutstandingJob('admin')
        finally:
            for job in jobs: job.release()

    def test_worker_configuration_rejected(self):
        m = self.module
        with patch.dict(os.environ, WEB_CONCURRENCY='2'):
            with self.assertRaises(RuntimeError): m._acquire_runtime_lock()

    def test_runtime_lock_excludes_another_process(self):
        import subprocess
        m = self.module
        m._acquire_runtime_lock()
        script = 'import fcntl,sys; f=open(sys.argv[1],"a+"); fcntl.flock(f,fcntl.LOCK_EX|fcntl.LOCK_NB)'
        result = subprocess.run([sys.executable, '-c', script, str(Path(m.CFG.data_dir)/'.tenant-runtime.lock')], capture_output=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b'BlockingIOError', result.stderr)

    def test_queued_authority_expires_on_rotation_before_upstream(self):
        m = self.module
        user, key = m.users.create('queued')
        job = m.OutstandingJob(user['id'])
        m.users.rotate(user['id'])
        with patch.object(m, '_run_generation_locked') as run:
            with self.assertRaises(m.MuseAuthError):
                m._run_generation('test', 'image', 1, owner_id=user['id'], job=job)
            run.assert_not_called()
        job.release()

    def test_authenticated_old_version_cannot_gain_new_queued_authority(self):
        m = self.module
        user, key = m.users.create('old-request')
        principal = m.users.authenticate(key)
        m.users.rotate(user['id'])
        with patch.object(m, '_run_generation_locked') as run:
            with self.assertRaises(m.MuseAuthError):
                m._run_generation('test', 'image', 1, owner_id=user['id'], authority_version=principal['key_version'])
            run.assert_not_called()

    def test_sync_chat_uses_same_outstanding_limit(self):
        m = self.module
        jobs = [m.OutstandingJob('admin') for _ in range(8)]
        try:
            with self.assertRaises(m.HTTPException):
                list(m.safe_chat_stream({}, 'test', None, 1, None))
        finally:
            for job in jobs: job.release()

    def test_tenant_reference_cannot_opt_in_local_file(self):
        m = self.module
        path = Path(self.home.name)/'secret.png'
        path.write_bytes(b'\x89PNG\r\n\x1a\nfixture')
        with patch.object(m.CFG, 'ref_image_local_files', True):
            with self.assertRaises(m.HTTPException):
                m._prepare_reference_images([str(path)], owner_id='tenant')

    def test_video_cancel_clear_does_not_free_reservations(self):
        m = self.module
        targets = []
        class Deferred:
            def __init__(self, target, **kw): targets.append(target)
            def start(self): pass
        async def inline(function, *args, **kwargs): return function(*args, **kwargs)
        with patch.object(m.threading, 'Thread', Deferred), patch.object(m.asyncio, 'to_thread', inline):
            for i in range(8):
                result = asyncio.run(m.create_video(m.VideoRequest(prompt=str(i)), {'id':'admin', 'role':'admin'}))
                m.store.cancel_task(result['id'])
                m.store.clear_tasks()
            with self.assertRaises(m.HTTPException):
                m._queue_image(m.ImageRequest(prompt='overflow'), 'overflow', [])
        with patch.object(m, '_run_generation_locked') as run:
            for target in targets: target()
            run.assert_not_called()
        self.assertEqual(len(m.OutstandingJob._jobs), 0)

    def test_disabled_or_revoked_queued_authority_fails_closed(self):
        m = self.module
        for action in ('disable', 'revoke'):
            user, _ = m.users.create(action)
            job = m.OutstandingJob(user['id'])
            if action == 'disable': m.users.patch(user['id'], enabled=False)
            else: m.users.revoke(user['id'])
            with patch.object(m, '_run_generation_locked') as run:
                with self.assertRaises(m.MuseAuthError):
                    m._run_generation('test', 'image', 1, owner_id=user['id'], job=job)
                run.assert_not_called()
            job.release()

    def test_tenant_reference_cannot_opt_in_private_fetch(self):
        m = self.module
        import engine
        with patch.object(m.CFG, 'ref_image_private_fetch', True), patch.object(engine.urllib.request, 'urlopen') as fetch:
            with self.assertRaises(m.HTTPException):
                m._prepare_reference_images(['http://127.0.0.1/secret'], owner_id='tenant')
            fetch.assert_not_called()

    def test_updater_and_publication_are_disabled_without_side_effects(self):
        m = self.module
        with patch.object(m, '_git') as git, patch('requests.get') as fetch:
            fetch.return_value.status_code = 500
            with self.assertRaises(m.HTTPException) as caught: m._upgrade_from_github_sync()
            self.assertEqual(caught.exception.status_code, 409)
            with self.assertRaises(m.HTTPException): asyncio.run(m.admin_repo_push({}, {}))
            git.assert_not_called()
            fetch.assert_not_called()

if __name__ == '__main__':
    unittest.main()
