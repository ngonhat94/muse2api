"""Disposable Docker/kernel tests: synthetic endpoints only, internal network.

Does not run provider server/mint code, contact YouTube, or mount production state.
All resources have unique fixture names and an ownership label.
"""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import uuid

ROOT=Path(__file__).resolve().parents[1]
LABEL='io.muse.pot-isolation-test'


def docker(*args,check=True,source=None):
    return subprocess.run(['docker',*args],input=source,capture_output=True,text=True,check=check,timeout=120)


def wait_health(name):
    for _ in range(30):
        result=docker('inspect','--format','{{.State.Health.Status}}',name)
        if result.stdout.strip()=='healthy': return
        time.sleep(.3)
    raise AssertionError('Synthetic firewall guard did not become healthy')


def main(guard_image):
    tag='pot-test-'+uuid.uuid4().hex[:12]
    network,guard,fixture=tag+'-net',tag+'-guard',tag+'-fixture'
    created=[]
    # Real-public-looking addresses confined to a Docker INTERNAL network. Never
    # route a test to external DNS/services; attach only these fixture containers.
    subnet='93.184.216.240/29'
    resolver='93.184.216.243'
    with tempfile.TemporaryDirectory(prefix='pot-isolation-') as folder:
        root=Path(folder)
        config=root/'policy.json'
        config.write_text(json.dumps(dict(resolver_v4=resolver,deny_host_v4=['93.184.216.241/32','93.184.216.244/32'])))
        # Non-secret synthetic addresses; guard drops DAC_OVERRIDE and is not the
        # devbox UID that owns this fixture file.
        config.chmod(0o644)
        try:
            docker('network','create','--internal','--subnet',subnet,'--label',LABEL+'='+tag,network)
            fixture_code='''
import socket,threading,time
for port in (53,80,443):
 def serve(port):
  with socket.socket() as s:
   s.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1);s.bind(('0.0.0.0',port));s.listen()
   while True:
    c,_=s.accept();c.sendall(b'synthetic');c.close()
 threading.Thread(target=serve,args=(port,),daemon=True).start()
s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);s.bind(('0.0.0.0',53))
while True:
 data,peer=s.recvfrom(1024);s.sendto(b'synthetic-dns',peer)
'''
            docker('run','-d','--name',fixture,'--label',LABEL+'='+tag,'--network',network,'--ip',resolver,
                   '--cap-drop=ALL','--cap-add=NET_ADMIN','--read-only','--entrypoint','python3',guard_image,'-c',fixture_code)
            created.append(fixture)
            docker('exec',fixture,'ip','addr','add','93.184.216.244/32','dev','eth0')
            docker('exec',fixture,'ip','addr','add','169.254.169.254/32','dev','eth0')
            docker('run','-d','--name',guard,'--label',LABEL+'='+tag,'--network',network,'--ip','93.184.216.242',
                   '--read-only','--cap-drop=ALL','--cap-add=NET_ADMIN','--security-opt=no-new-privileges',
                   '--mount','type=bind,source='+str(config)+',target=/etc/muse-pot/policy.json,readonly',
                   '--tmpfs','/run/muse-pot-guard:rw,noexec,nosuid,nodev,size=1048576,mode=0700',guard_image)
            created.append(guard)
            wait_health(guard)
            docker('exec',guard,'ip','route','add','169.254.169.254/32','via',resolver)
            probe='''
import socket
allowed=socket.create_connection(('93.184.216.243',443),timeout=2)
assert allowed.recv(64)==b'synthetic';allowed.close()
allowed=socket.create_connection(('93.184.216.243',53),timeout=2);allowed.close()
s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);s.settimeout(2)
s.sendto(b'synthetic',('93.184.216.243',53));assert s.recv(64)==b'synthetic-dns';s.close()
for host,port in [('93.184.216.243',80),('93.184.216.244',443),('169.254.169.254',443),('127.0.0.1',443)]:
 try:
  socket.create_connection((host,port),timeout=.3).close()
 except OSError: pass
 else: raise AssertionError('Blocked destination was reachable')
try:
 s=socket.socket(socket.AF_INET6);s.settimeout(.3);s.connect(('::1',443));raise AssertionError('IPv6 permitted')
except OSError: pass
finally:s.close()
print('PASS: kernel policy allows synthetic TCP443/DNS, blocks alternate port/host/metadata/loopback/IPv6')
'''
            # Run as provider UID with ALL capabilities dropped in guard namespace.
            print(docker('run','--rm','--network','container:'+guard,'--user','10001:10001',
                         '--cap-drop=ALL','--read-only','--security-opt=no-new-privileges',
                         '--entrypoint','python3',guard_image,'-c',probe).stdout.strip())
            table=json.loads(docker('exec',guard,'nft','-j','list','table','inet','muse_pot_guard').stdout)
            output=[x['rule'] for x in table['nftables'] if 'rule' in x and x['rule']['chain']=='output']
            counters=[sum(e.get('counter',{}).get('packets',0) for e in rule['expr']) for rule in output]
            assert counters[1]>0 and counters[2]>0 and counters[-1]>0,counters
            # Filtering after namespace DNAT prevents public TCP443 being
            # translated to the synthetic metadata listener on the fixture.
            nat='''table ip synthetic_dnat {
 chain out { type nat hook output priority -100; policy accept;
 ip daddr 93.184.216.243 tcp dport 443 dnat to 169.254.169.254:443
 }
}\n'''
            docker('exec','-i',guard,'nft','-f','-',source=nat)
            denied='''import socket
try:socket.create_connection(('93.184.216.243',443),timeout=.3);raise AssertionError('DNAT bypass')
except OSError:pass
'''
            docker('run','--rm','--network','container:'+guard,'--user','10001:10001','--cap-drop=ALL',
                   '--entrypoint','python3',guard_image,'-c',denied)
            after=json.loads(docker('exec',guard,'nft','-j','list','table','inet','muse_pot_guard').stdout)
            after_rules=[x['rule'] for x in after['nftables'] if 'rule' in x and x['rule']['chain']=='output']
            hits=sum(e.get('counter',{}).get('packets',0) for e in after_rules[1]['expr'])
            assert hits>counters[1], 'Post-DNAT private destination did not hit deny rule'
            docker('exec',guard,'nft','delete','table','ip','synthetic_dnat')
            print('PASS: post-DNAT private destination remains blocked by kernel policy')
            # Same policy reinstall is atomic and readiness remains valid.
            docker('exec',guard,'python3','-c','import net_guard; net_guard.install(); assert net_guard.ready()')
            # Simulate privileged policy loss: health must revoke even if marker remains.
            docker('exec',guard,'nft','delete','table','inet','muse_pot_guard')
            assert docker('exec',guard,'python3','/opt/muse-guard/net_guard.py','--health',check=False).returncode!=0
            # Recreate a fresh namespace: readiness is earned by installing the
            # policy again, not by carrying a marker across container restarts.
            docker('rm','-f',guard);created.remove(guard)
            docker('run','-d','--name',guard,'--label',LABEL+'='+tag,'--network',network,'--ip','93.184.216.242',
                   '--read-only','--cap-drop=ALL','--cap-add=NET_ADMIN','--security-opt=no-new-privileges',
                   '--mount','type=bind,source='+str(config)+',target=/etc/muse-pot/policy.json,readonly',
                   '--tmpfs','/run/muse-pot-guard:rw,noexec,nosuid,nodev,size=1048576,mode=0700',guard_image)
            created.append(guard)
            wait_health(guard)
            assert docker('exec',guard,'python3','/opt/muse-guard/net_guard.py','--health').returncode==0
            print('PASS: recreated namespace installs and verifies a fresh policy before readiness')
            # No NET_ADMIN on a fresh guard means provider dependency is blocked.
            docker('rm','-f',guard);created.remove(guard)
            docker('run','-d','--name',guard,'--label',LABEL+'='+tag,'--network','none','--read-only',
                   '--cap-drop=ALL','--security-opt=no-new-privileges',
                   '--mount','type=bind,source='+str(config)+',target=/etc/muse-pot/policy.json,readonly',
                   '--tmpfs','/run/muse-pot-guard:rw,size=1048576,mode=0700',guard_image)
            created.append(guard)
            time.sleep(.5)
            assert docker('exec',guard,'python3','/opt/muse-guard/net_guard.py','--health',check=False).returncode!=0
            print('PASS: policy reinstall; readiness revoked on rule loss; no NET_ADMIN fails closed')
            # Real Compose dependency test, with a fake provider command and no
            # capability to install the guard policy. It must never start.
            compose=root/'gate.json'
            project=tag+'-gate'
            compose.write_text(json.dumps({'services':{
                'guard':{'image':guard_image,'network_mode':'none','read_only':True,
                         'cap_drop':['ALL'],'volumes':[str(config)+':/etc/muse-pot/policy.json:ro'],
                         'tmpfs':['/run/muse-pot-guard:rw,mode=0700']},
                'fake-provider':{'image':guard_image,'network_mode':'service:guard',
                                 'depends_on':{'guard':{'condition':'service_healthy'}},
                                 'entrypoint':['python3','-c','print("unexpected start")']}}}))
            prefix=['compose','-p',project,'-f',str(compose)]
            try:
                assert docker(*prefix,'up','--detach',check=False).returncode!=0
                ident=docker(*prefix,'ps','--all','--quiet','fake-provider',check=False).stdout.strip()
                if ident:
                    assert docker('inspect','--format','{{.State.Running}}',ident).stdout.strip()=='false'
            finally:
                docker(*prefix,'down','--volumes','--remove-orphans',check=False)
            print('PASS: Compose refuses to start a fake provider when firewall health fails')
        finally:
            for name in reversed(created):
                owned=docker('inspect','--format','{{index .Config.Labels "'+LABEL+'"}}',name,check=False)
                if owned.returncode==0 and owned.stdout.strip()==tag:docker('rm','-f',name,check=False)
            owned=docker('network','inspect','--format','{{index .Labels "'+LABEL+'"}}',network,check=False)
            if owned.returncode==0 and owned.stdout.strip()==tag:docker('network','rm',network,check=False)

if __name__=='__main__':main(sys.argv[1])
