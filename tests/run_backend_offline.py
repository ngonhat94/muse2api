"""Run one backend script with synthetic HOME and forbidden external IO.

Usage: python tests/run_backend_offline.py tests/test_tenant_review_blockers.py
Session-health exercises real engine parsing against mocked requests/pages only.
"""
import os,sys,tempfile,socket,runpy,subprocess
from pathlib import Path
from unittest.mock import patch
from contextlib import ExitStack
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
with tempfile.TemporaryDirectory(dir=os.environ.get('MUSE2API_TEST_TMP', tempfile.gettempdir()),prefix='offline-blockers-') as home:
 os.environ.update(MUSE2API_LEDGER_INITIALIZE='1',MUSE2API_HOME=home,MUSE2API_PROFILE_ROOT=home+'/profile',MUSE2API_KEY='synthetic-admin',TMPDIR=home,MUSE2API_TEST_TMP=home,PYTHONDONTWRITEBYTECODE='1')
 def deny(*a,**k): raise AssertionError('EXTERNAL IO FORBIDDEN')
 with ExitStack() as stack:
  for name in ('connect','connect_ex','bind'): stack.enter_context(patch.object(socket.socket,name,deny))
  stack.enter_context(patch.object(socket,'getaddrinfo',deny))
  from cryptography.fernet import Fernet
  os.environ['MUSE2API_COOKIE_KEY'] = Fernet.generate_key().decode()
  os.environ.pop('MUSE2API_COOKIE_KEY_FILE', None)
  import engine
  target=sys.argv[1] if len(sys.argv)>1 else 'tests/test_tenant_review_blockers.py'
  methods = ('start','generate','chat_stream','renew_session_http','refresh','quota','ensure_page')
  if target.endswith(('test_session_health.py', 'test_account_proxy.py')):
   methods = ('start','generate','chat_stream','refresh','quota')
  for name in methods:
   stack.enter_context(patch.object(engine.MuseEngine,name,deny))
  import requests
  stack.enter_context(patch.object(requests.sessions.Session,'request',deny))
  real_popen = subprocess.Popen
  def guarded_popen(args, *a, **kw):
   if isinstance(args, list) and args and args[0] == sys.executable and target.endswith('test_tenant_review_blockers.py'):
    return real_popen(args, *a, **kw)
   if (target.endswith('test_deploy.py') and isinstance(args, list)
       and args[:2] == ['bash', str(ROOT/'tools/deploy_ssh.sh')]
       and kw.get('env', {}).get('VPS_KNOWN_HOSTS') == ''
       and kw.get('env', {}).get('VPS_DEPLOY_PATH') == '/tmp/unsafe;touch NO'):
    return real_popen(args, *a, **kw)
   if (target.endswith('test_deploy.py') and isinstance(args, list)
       and args[:2] == ['bash', str(ROOT/'tools/deploy_ssh.sh')]
       and kw.get('env', {}).get('VPS_HOST') == 'example.invalid'
       and kw.get('env', {}).get('VPS_KNOWN_HOSTS') in ('synthetic', '')
       and kw.get('env', {}).get('VPS_SSH_KEY') in ('synthetic', '')
       and kw.get('env', {}).get('VPS_DEPLOY_PATH') == '/data/home/muse2api-production'):
    mock = Path(kw['env']['PATH'].split(os.pathsep)[0]) / 'ssh'
    if mock.read_text() in (
        '#!/bin/bash\nprintf "%s\\n" "$@" >> "$SSH_MOCK_LOG"\ncat >/dev/null\n',
        '#!/bin/bash\nprintf "%s\\n" "$@" >> "$SSH_MOCK_LOG"\nif [[ ${SSH_MOCK_FAIL:-} == 1 ]]; then\n  for arg in "$@"; do\n    if [[ $arg == */config ]]; then cat "$arg" >&2; fi\n  done\n  exit 255\nfi\ncat >/dev/null\n'):
     return real_popen(args, *a, **kw)
   return deny()
  stack.enter_context(patch.object(subprocess,'Popen',guarded_popen))
  sys.argv=[target]+sys.argv[2:]
  runpy.run_path(str(ROOT/target),run_name='__main__')
