"""Synthetic token contracts. No network, provider execution or real token generation."""
import dataclasses
import importlib.util
import json
import os
from pathlib import Path
import socket
import struct
import tempfile
import threading
import time
import unittest
from unittest.mock import patch
from types import SimpleNamespace

from pot_broker import JobBroker,PotError,validate_request,validate_response,send_frame,recv_frame,serve_job,enabled
from web_download_worker import classify_error

VIDEO='fixture1234'
def request(**fields):
    return dict(client='mweb',context='gvs',video_id=VIDEO,binding='synthetic-visitor',binding_type='visitor_data',**fields)
def response(req=None, **fields):
    return dict(req or request(),token='SYNTHETIC_TOKEN_ONLY_123456',expires_at=time.time()+100,**fields)

class BrokerTest(unittest.TestCase):
    def test_parent_passes_only_job_ipc_fd_and_never_provider_config_to_worker(self):
        from web_downloads import run_download
        captured=[]
        class Process:
            pid=43210
            returncode=1
            def __init__(self,args,**kwargs):
                captured.append(kwargs)
                (Path(args[-1])/'progress.json').write_text(json.dumps(dict(stage='failed',error_code='unavailable')))
            def poll(self): return 1
        with tempfile.TemporaryDirectory() as directory, \
             patch.dict(os.environ,{'MUSE_YOUTUBE_POT_SOCKET':'/run/muse-pot/provider.sock'}), \
             patch('web_downloads.subprocess.Popen',Process), patch('web_downloads.os.killpg'), \
             patch('pot_broker.provider_exchange',side_effect=AssertionError('No token requests expected')):
            output,result=run_download('https://www.youtube.com/watch?v=fixture1234',720,Path(directory),lambda _:None,lambda:None,threading.Event())
            self.assertIsNone(output)
            self.assertEqual(result['stage'],'failed')
            options=captured[0]
            fd=options['pass_fds'][0]
            self.assertEqual(options['env']['MUSE_POT_FD'],str(fd))
            self.assertEqual(options['env']['MUSE_POT_VIDEO_ID'],VIDEO)
            self.assertNotIn('MUSE_YOUTUBE_POT_SOCKET',options['env'])
            with self.assertRaises(OSError):os.fstat(fd)
            self.assertNotIn('token',(Path(directory)/'request.json').read_text())

    def test_strict_scope_and_no_client_network_options(self):
        valid=request()
        self.assertEqual(validate_request(valid,VIDEO),valid)
        for key,value in [('client','web'),('context','player'),('video_id','other123456'),('binding_type','datasync_id'),('binding','http://evil.invalid/')]:
            with self.subTest(key=key),self.assertRaises(PotError):
                validate_request(dict(valid,**{key:value}),VIDEO)
        for field in ('proxy','url','headers','cookies','source_address','disable_tls_verification'):
            with self.assertRaises(PotError): validate_request(dict(valid,**{field:'synthetic'}),VIDEO)
        with self.assertRaises(PotError): validate_request(dict(valid,binding_type='video_id'),VIDEO)

    def test_response_shape_expiry_binding_and_size(self):
        valid=response()
        self.assertEqual(validate_response(valid,request())['token'],valid['token'])
        for field,value in [('token',''),('token','x'*17000),('token',{}),('expires_at',None),('expires_at',float('nan')),('expires_at',float('inf')),('expires_at',True),('expires_at',time.time()-1),('expires_at',time.time()+90000),('binding','other'),('context','player')]:
            with self.subTest(field=field),self.assertRaises(PotError):
                validate_response(dict(valid,**{field:value}),request())
        with self.assertRaises(PotError): validate_response(dict(valid,error='SYNTHETIC_RAW_ERROR'),request())

    def test_one_attempt_cache_is_job_local_and_expires_without_retry(self):
        calls=[]
        def exchange(req,*_): calls.append(req); return response(req)
        a=JobBroker(VIDEO,lambda:None,threading.Event(),exchange)
        b=JobBroker(VIDEO,lambda:None,threading.Event(),exchange)
        self.assertEqual(a.get(request()),a.get(request()))
        self.assertEqual(len(calls),1)
        b.get(request()); self.assertEqual(len(calls),2)
        with self.assertRaises(PotError): a.get(dict(request(),binding='other'))
        a.response['expires_at']=time.time()-1
        with self.assertRaises(PotError): a.get(request())
        self.assertEqual(len(calls),2)
        a.close();self.assertIsNone(a.response);self.assertIsNone(a.request)

    def test_failure_uncertainty_revocation_cancel_do_not_mint_again(self):
        calls=[]
        def exchange(*args): calls.append(1); raise TimeoutError('SYNTHETIC_RAW_ERROR')
        event=threading.Event()
        broker=JobBroker(VIDEO,lambda:None,event,exchange)
        with self.assertRaises(TimeoutError): broker.get(request())
        with self.assertRaises(PotError): broker.get(request())
        self.assertEqual(len(calls),1)
        event.set()
        with self.assertRaises(InterruptedError): broker.get(request())
        broker=JobBroker(VIDEO,lambda:(_ for _ in ()).throw(PermissionError()),threading.Event(),exchange)
        with self.assertRaises(PermissionError): broker.get(request())
        self.assertEqual(len(calls),1)

    def test_ipc_real_frames_safe_failure_and_disconnect_clear_memory(self):
        a,b=socket.socketpair()
        broker=JobBroker(VIDEO,lambda:None,threading.Event(),lambda req,*_:response(req))
        thread=threading.Thread(target=serve_job,args=(a,broker));thread.start()
        b.settimeout(2)
        send_frame(b,request());self.assertIn('token',recv_frame(b))
        send_frame(b,dict(request(),binding='other'))
        self.assertEqual(recv_frame(b),{'error':'youtube_po_request_rejected'})
        b.close();thread.join(3)
        self.assertFalse(thread.is_alive());self.assertIsNone(broker.response)
        a,b=socket.socketpair()
        try:
            b.sendall(struct.pack('!I',32769))
            with self.assertRaises(PotError): recv_frame(a)
        finally: a.close();b.close()

    def test_opt_in_and_safe_diagnostic_only(self):
        with patch.dict(os.environ,{},clear=True): self.assertFalse(enabled())
        with patch.dict(os.environ,{'MUSE_YOUTUBE_POT_SOCKET':'http://evil.invalid'}): self.assertFalse(enabled())
        for code in ('youtube_po_provider_failed','youtube_po_request_rejected','youtube_po_token_expired'):
            self.assertEqual(classify_error(PotError(code),True),('unavailable',code))
            self.assertEqual(classify_error(Exception('ERROR '+code),True),('unavailable',code))

    def test_actual_yt_dlp_adapter_uses_only_approved_guest_context(self):
        import yt_dlp
        from yt_dlp.extractor.youtube import YoutubeIE
        from yt_dlp.extractor.youtube.pot.provider import PoTokenRequest,PoTokenContext
        from pot_worker import install
        from web_download_worker import DiagnosticLogger
        a,b=socket.socketpair()
        broker=JobBroker(VIDEO,lambda:None,threading.Event(),lambda req,*_:response(req))
        thread=threading.Thread(target=serve_job,args=(a,broker));thread.start()
        with yt_dlp.YoutubeDL(dict(quiet=True,cachedir=False,logger=DiagnosticLogger(True),js_runtimes={},remote_components=set(),cookiefile=None,cookiesfrombrowser=None)) as ydl:
            conn=install(ydl,b.detach(),VIDEO)
            try:
                ie=ydl.get_info_extractor('Youtube')
                with patch.object(YoutubeIE,'_real_initialize',return_value=None): ie._real_initialize()
                req=PoTokenRequest(context=PoTokenContext.GVS,innertube_context={'client':{'clientName':'MWEB'}},internal_client_name='mweb',video_id=VIDEO,visitor_data='synthetic-visitor')
                self.assertEqual(ie._pot_director.get_po_token(req),'SYNTHETIC_TOKEN_ONLY_123456')
                for change in ({'is_authenticated':True},{'data_sync_id':'synthetic'},{'request_proxy':'http://evil.invalid'},{'request_verify_tls':False},{'context':PoTokenContext.PLAYER}):
                    with self.assertRaises(PotError): ie._pot_director.get_po_token(dataclasses.replace(req,**change))
            finally: conn.close()
        thread.join(3);self.assertFalse(thread.is_alive())

    def test_provider_child_disconnect_cancels_without_executing_runtime(self):
        spec=importlib.util.spec_from_file_location('provider_sidecar',Path(__file__).parents[1]/'deploy/pot-provider/server.py')
        server=importlib.util.module_from_spec(spec);spec.loader.exec_module(server)
        # Ready client socket simulates disconnect; no real token generator process.
        a,b=socket.socketpair();b.close()
        fake=SimpleNamespace(stdin=SimpleNamespace(write=lambda _:None,close=lambda:None),stdout=SimpleNamespace(close=lambda:None),pid=43210,poll=lambda:None,wait=lambda **_:0)
        try:
            with patch.object(server.subprocess,'Popen',return_value=fake),patch.object(server.select,'select',return_value=([a],[],[])),patch.object(server.os,'killpg') as kill:
                with self.assertRaises(PotError): server.mint(a,request())
                kill.assert_called_once()
        finally:a.close()

if __name__=='__main__': unittest.main()
