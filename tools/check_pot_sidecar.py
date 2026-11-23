"""Offline sidecar package/real Unix IPC; replaces mint BEFORE any request."""
import importlib.util
import json
from pathlib import Path
import socket
import tempfile
import threading
import time
from unittest.mock import patch
import sys

sys.path.insert(0,'/opt/muse')
import pot_broker
from pot_broker import JobBroker
spec=importlib.util.spec_from_file_location('sidecar','/opt/muse/server.py')
sidecar=importlib.util.module_from_spec(spec);spec.loader.exec_module(sidecar)

# No generator process, HTTP, DNS or YouTube requests are allowed in this check.
def deny(*a,**k): raise AssertionError('External IO forbidden in offline sidecar check')
def fake_mint(conn,req):
    return dict(req,token='SYNTHETIC_TOKEN_ONLY_123456',expires_at=time.time()+60)
with tempfile.TemporaryDirectory() as root, \
     patch.object(sidecar,'mint',side_effect=fake_mint) as mint, \
     patch.object(sidecar.subprocess,'Popen',side_effect=deny), \
     patch('socket.getaddrinfo',side_effect=deny):
    path=root+'/provider.sock'
    import os
    with socket.socket(socket.AF_UNIX,socket.SOCK_STREAM) as listener:
        listener.bind(path);os.chmod(path,0o600);listener.listen(1)
        def serve():
            conn,_=listener.accept()
            assert sidecar.LIMIT.acquire(False)
            sidecar.handle(conn)
        thread=threading.Thread(target=serve);thread.start()
        broker=JobBroker('fixture1234',lambda:None,threading.Event())
        request=dict(client='mweb',context='gvs',video_id='fixture1234',binding='synthetic-visitor',binding_type='visitor_data')
        with patch.object(pot_broker,'SOCKET_PATH',path):
            assert broker.get(request)['token']=='SYNTHETIC_TOKEN_ONLY_123456'
            assert broker.get(request)['token']=='SYNTHETIC_TOKEN_ONLY_123456'
        assert mint.call_count==1
        broker.close();assert broker.response is None
        thread.join(3);assert not thread.is_alive()
        # Real IPC disconnect/revocation while the synthetic provider is waiting.
        finished=threading.Event()
        def waiting_mint(conn,req):
            import select
            assert select.select([conn],[],[],3)[0], 'broker did not close revoked provider connection'
            assert conn.recv(1)==b''
            finished.set()
            raise pot_broker.PotError()
        def serve_revocation():
            conn,_=listener.accept()
            assert sidecar.LIMIT.acquire(False)
            with patch.object(sidecar,'mint',side_effect=waiting_mint): sidecar.handle(conn)
        thread=threading.Thread(target=serve_revocation);thread.start()
        revoked=threading.Event()
        def check():
            if revoked.is_set(): raise PermissionError('synthetic revocation')
        broker=JobBroker('fixture1234',check,threading.Event())
        timer=threading.Timer(.2,revoked.set);timer.start()
        with patch.object(pot_broker,'SOCKET_PATH',path):
            try: broker.get(request)
            except (pot_broker.PotError,PermissionError,OSError): pass
            else: raise AssertionError('revocation returned a token')
        thread.join(3);timer.join()
        assert finished.is_set() and not thread.is_alive()
        assert broker.response is None
print('PASS: sidecar real Unix IPC/peer UID, synthetic job cache, no generator process/network')
