"""Non-root image + RO Unix socket volume + synthetic API persistence checks.

Every container uses network none and fresh labelled volumes. No live provider,
YouTube, browser session, production data or AI/TTS call is used.
"""
import json
import subprocess
import sys
import time
import uuid

LABEL='io.muse.pot-runtime-test'


def docker(*args,check=True):
    result=subprocess.run(['docker',*args],capture_output=True,text=True,timeout=120)
    if check and result.returncode:
        raise AssertionError('Synthetic Docker operation failed: '+result.stderr[-2000:])
    return result


def main(api_image,provider_image):
    tag='pot-runtime-'+uuid.uuid4().hex[:12]
    runtime,ipc=tag+'-data',tag+'-ipc'
    api=tag+'-api';containers=[];volumes=[]
    try:
        for volume in (runtime,ipc):
            docker('volume','create','--label',LABEL+'='+tag,volume);volumes.append(volume)
        init='''
import os,sys,tempfile
from pathlib import Path
from cryptography.fernet import Fernet
sys.path.insert(0,'/opt/muse-api')
from prepare_layout import create
with tempfile.TemporaryDirectory(prefix='new-layout-') as directory:
 root=Path(directory)/'review'
 create(root)
 assert (root/'runtime').stat().st_uid==10001 and (root/'ipc').stat().st_mode&0o777==0o700
 assert not (root/'runtime/.env').exists()
 try:create(root);raise AssertionError('Existing layout was modified')
 except ValueError:pass
for p in ('/runtime','/runtime/data','/runtime/profiles','/run/muse-pot'):
 path=Path(p);path.mkdir(exist_ok=True,parents=True);os.chown(path,10001,10001);path.chmod(0o700)
p=Path('/runtime/.env')
p.write_text('MUSE2API_KEY=synthetic-isolation-admin\\nMUSE2API_COOKIE_KEY='+Fernet.generate_key().decode()+'\\nMUSE2API_LEDGER_INITIALIZE=1\\n')
os.chown(p,10001,10001);p.chmod(0o600)
'''
        # Python source string intentionally contains actual newline literals.
        init=init.replace('\\\\n','\\n')
        docker('run','--rm','--network','none','--user','0:0','--mount','type=volume,source='+runtime+',target=/runtime',
               '--mount','type=volume,source='+ipc+',target=/run/muse-pot','--entrypoint','python3',api_image,'-c',init)
        docker('run','-d','--name',api,'--label',LABEL+'='+tag,'--network','none',
               '--read-only','--cap-drop=ALL','--security-opt=no-new-privileges','--memory=2g','--pids-limit=256',
               '--tmpfs','/tmp:rw,nosuid,nodev,size=268435456,mode=1777',
               '--mount','type=volume,source='+runtime+',target=/runtime',
               '--mount','type=volume,source='+ipc+',target=/run/muse-pot,readonly',api_image)
        containers.append(api)
        health="import urllib.request,json; assert json.load(urllib.request.urlopen('http://127.0.0.1:18610/healthz',timeout=2))['status']=='ok'"
        for _ in range(40):
            if docker('exec',api,'python3','-c',health,check=False).returncode==0:break
            time.sleep(.25)
        else:raise AssertionError('Non-root API startup failed (no logs emitted)')
        check='''
import json,os,urllib.request,urllib.error
from pathlib import Path
assert os.getuid()==10001 and os.getgid()==10001
assert os.environ['HOME']=='/runtime'
assert os.environ['MUSE2API_PROFILE_ROOT']=='/runtime/profiles'
def read(path,auth=False):
 req=urllib.request.Request('http://127.0.0.1:18610'+path,headers={'Authorization':'Bearer synthetic-isolation-admin'} if auth else {})
 return json.load(urllib.request.urlopen(req,timeout=5))
try:read('/v1/me');raise AssertionError('Missing auth accepted')
except urllib.error.HTTPError as e:assert e.code==401
assert read('/v1/me',True)['role']=='admin'
assert read('/v1/video-downloads/capability',True)['youtube']['anonymous_po_token']['configured'] is False
root=Path('/runtime/profiles');(root/'synthetic-sentinel').write_text('synthetic')
assert Path('/runtime/.env').stat().st_uid==10001
print('PASS: UID/GID10001 API startup/auth, copied synthetic runtime/profile writes, provider remains disabled')
'''
        print(docker('exec',api,'python3','-c',check).stdout.strip())
        browser=docker('exec',api,'chromium','--headless','--no-sandbox','--disable-gpu',
                       '--disable-background-networking','--disable-component-update',
                       '--disable-default-apps','--no-first-run','--disable-sync',
                       '--user-data-dir=/runtime/profiles/synthetic-chromium','--dump-dom','about:blank')
        assert '<html' in browser.stdout
        print('PASS: UID10001 Chromium renders about:blank in network-none synthetic profile')
        # A fake provider binds only a socket; it never imports the minting server.
        server=tag+'-socket'
        script='''
import os,socket,time
from pathlib import Path
assert os.getuid()==10001 and os.getgid()==10001
p=Path('/run/muse-pot/provider.sock')
os.umask(0o077)
s=socket.socket(socket.AF_UNIX);s.bind(str(p));p.chmod(0o600);s.listen(1)
assert p.stat().st_uid==10001 and (p.stat().st_mode&0o777)==0o600
c,_=s.accept();c.sendall(b'synthetic');c.close();time.sleep(2)
'''
        docker('run','-d','--name',server,'--label',LABEL+'='+tag,'--network','none','--read-only','--cap-drop=ALL',
               '--security-opt=no-new-privileges','--mount','type=volume,source='+ipc+',target=/run/muse-pot',
               '--entrypoint','python3',provider_image,'-c',script)
        containers.append(server)
        connect='''
import os,socket,struct,time
from pathlib import Path
p=Path('/run/muse-pot/provider.sock')
for _ in range(30):
 if p.exists():break
 time.sleep(.1)
assert p.stat().st_uid==10001 and p.stat().st_mode&0o777==0o600
s=socket.socket(socket.AF_UNIX);s.connect(str(p))
_,uid,_=struct.unpack('3i',s.getsockopt(socket.SOL_SOCKET,socket.SO_PEERCRED,12))
assert uid==10001 and s.recv(64)==b'synthetic';s.close()
try:Path('/run/muse-pot/must-not-write').write_text('x');raise AssertionError('API can write IPC directory')
except OSError:pass
print('PASS: API RO socket volume connects to fake UID10001 provider; no token generation')
'''
        print(docker('exec',api,'python3','-c',connect).stdout.strip())
        docker('restart',api)
        for _ in range(40):
            if docker('exec',api,'python3','-c',health,check=False).returncode==0:break
            time.sleep(.25)
        else:raise AssertionError('Non-root restart failed')
        docker('exec',api,'python3','-c',"from pathlib import Path; assert Path('/runtime/profiles/synthetic-sentinel').read_text()=='synthetic'")
        print('PASS: non-root runtime survives restart; original runtime volumes never mounted')
    finally:
        for name in reversed(containers):
            label=docker('inspect','--format','{{index .Config.Labels "'+LABEL+'"}}',name,check=False)
            if label.returncode==0 and label.stdout.strip()==tag:docker('rm','-f','-v',name,check=False)
        for name in reversed(volumes):
            label=docker('volume','inspect','--format','{{index .Labels "'+LABEL+'"}}',name,check=False)
            if label.returncode==0 and label.stdout.strip()==tag:docker('volume','rm',name,check=False)

if __name__=='__main__':main(sys.argv[1],sys.argv[2])
