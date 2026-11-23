import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[1]
def load(name,file):
    spec=importlib.util.spec_from_file_location(name,ROOT/file)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    return module

guard=load('net_guard','deploy/pot-isolation/net_guard.py')
layout=load('prepare_layout','deploy/pot-isolation/prepare_layout.py')
sidecar=load('isolation_sidecar','deploy/pot-provider/server.py')
entrypoint=load('api_entrypoint','deploy/pot-isolation/api_entrypoint.py')

class IsolationTest(unittest.TestCase):
    def test_api_startup_requires_prepared_config_without_reading_credentials(self):
        import stat
        from types import SimpleNamespace
        def metadata(path):
            return SimpleNamespace(st_mode=(stat.S_IFREG|0o600) if path.name=='.env' else (stat.S_IFDIR|0o700),st_uid=10001,st_gid=10001,st_size=123)
        with patch.object(entrypoint.os,'getuid',return_value=10001),patch.object(entrypoint.os,'getgid',return_value=10001), \
             patch.object(Path,'lstat',metadata),patch.object(Path,'read_text',side_effect=AssertionError('No credential read')):
            entrypoint.check_runtime()
            sidecar.check_ipc_directory(Path('/run/muse-pot'))
            with patch.object(entrypoint.os,'getuid',return_value=0):
                with self.assertRaises(ValueError):entrypoint.check_runtime()
            def empty(path):
                result=metadata(path)
                if path.name=='.env':result.st_size=0
                return result
            with patch.object(Path,'lstat',empty):
                with self.assertRaises(ValueError):entrypoint.check_runtime()

    def test_socket_recreation_refuses_live_regular_and_symlink_paths(self):
        import socket
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'provider.sock'
            path.write_text('synthetic-existing')
            with self.assertRaises(ValueError):sidecar.prepare_socket(path)
            self.assertEqual(path.read_text(),'synthetic-existing');path.unlink()
            target=Path(directory)/'target';target.write_text('keep');path.symlink_to(target)
            with self.assertRaises(ValueError):sidecar.prepare_socket(path)
            self.assertEqual(target.read_text(),'keep');path.unlink()
            with socket.socket(socket.AF_UNIX) as server:
                # Bind is denied by the guarded runner; use metadata mocks here.
                import os,stat
                from types import SimpleNamespace
                meta=SimpleNamespace(st_mode=stat.S_IFSOCK|0o600,st_uid=os.getuid(),st_dev=1,st_ino=2)
                with patch.object(Path,'lstat',return_value=meta),patch.object(Path,'unlink') as unlink, \
                     patch.object(socket.socket,'connect',return_value=None):
                    with self.assertRaises(ValueError):sidecar.prepare_socket(path)
                    unlink.assert_not_called()
                with patch.object(Path,'lstat',return_value=meta),patch.object(Path,'unlink') as unlink, \
                     patch.object(socket.socket,'connect',side_effect=ConnectionRefusedError):
                    sidecar.prepare_socket(path);unlink.assert_called_once()

    def test_policy_rejects_missing_hosts_dns_bypasses_and_rule_injection(self):
        valid={'resolver_v4':'1.1.1.1','deny_host_v4':['172.16.0.0/30','172.17.0.0/16']}
        self.assertEqual(guard.policy(valid),valid)
        for value in ({},dict(valid,deny_host_v4=[]),dict(valid,resolver_v4='127.0.0.11'),dict(valid,resolver_v4='::1'),dict(valid,resolver_v4='169.254.169.254'),dict(valid,deny_host_v4=['1.1.1.1/32']),dict(valid,deny_host_v4=['0.0.0.0/0']),dict(valid,deny_host_v4=['1.2.3.4; flush ruleset']),dict(valid,extra='x')):
            with self.assertRaises((ValueError,TypeError)):guard.policy(value)
        text=guard.rules(valid,replace=True)
        self.assertTrue(text.startswith('delete table inet muse_pot_guard\n'))
        self.assertNotIn('flush ruleset',text)
        self.assertIn('meta nfproto ipv6 counter drop',text)
        self.assertIn('hook output priority 0',text)
        self.assertLess(text.index('ip daddr @host_v4'),text.index('tcp dport 443'))
        self.assertIn('policy drop',text)

    def test_health_bound_to_namespace_config_and_live_rules(self):
        value={'resolver_v4':'1.1.1.1','deny_host_v4':['172.16.0.0/30']}
        with tempfile.TemporaryDirectory() as directory:
            config=Path(directory)/'policy.json'; state=Path(directory)/'state.json'
            config.write_text(json.dumps(value))
            with patch.object(guard,'CONFIG',config),patch.object(guard,'STATE',state),patch.object(guard,'current',return_value='rules'):
                import os
                proof=dict(netns=os.stat('/proc/self/ns/net').st_ino,policy=guard.digest(value),rules='rules')
                state.write_text(json.dumps(proof));self.assertTrue(guard.ready())
                for field in ('netns','policy','rules'):
                    state.write_text(json.dumps(dict(proof,**{field:'wrong'})))
                    self.assertFalse(guard.ready())
                state.write_text(json.dumps(proof));config.write_text('{}');self.assertFalse(guard.ready())

    def test_layout_never_changes_existing_or_symlink_tree(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            sentinel=root/'existing';sentinel.mkdir();(sentinel/'keep').write_text('synthetic')
            with self.assertRaises(ValueError):layout.validate_root(sentinel)
            link=root/'link';link.symlink_to(sentinel)
            with self.assertRaises(ValueError):layout.validate_root(link/'new')
            self.assertEqual((sentinel/'keep').read_text(),'synthetic')
            with patch.object(layout.os,'getuid',return_value=10001):
                with self.assertRaises(ValueError):layout.create(root/'new')
            self.assertFalse((root/'new').exists())

    def test_compose_gate_capabilities_uid_and_no_activation(self):
        import yaml
        data=yaml.safe_load((ROOT/'deploy/pot-isolation/compose.yaml').read_text())
        service=data['services'];provider=service['pot-provider'];api=service['api'];net=service['net-guard']
        self.assertEqual(provider['user'],'10001:10001');self.assertEqual(api['user'],'10001:10001')
        self.assertEqual(provider['depends_on']['net-guard']['condition'],'service_healthy')
        self.assertEqual(provider['network_mode'],'service:net-guard')
        self.assertEqual(provider['cap_drop'],['ALL']);self.assertNotIn('cap_add',provider)
        self.assertEqual(net['cap_add'],['NET_ADMIN']);self.assertNotIn('ports',net);self.assertNotIn('ports',provider)
        for item in service.values():self.assertEqual(item['restart'],'no')
        for item in service.values():
            self.assertNotIn('privileged',item)
            self.assertNotEqual(item.get('network_mode'),'host')
            self.assertNotEqual(item.get('pid'),'host')
        self.assertEqual(api['environment']['MUSE_YOUTUBE_POT_SOCKET'],'${MUSE_POT_OPT_IN:-}')
        socket_mount=next(v for v in api['volumes'] if v['target']=='/run/muse-pot')
        self.assertTrue(socket_mount['read_only'])
        self.assertTrue(all(v['bind']['create_host_path'] is False for x in service.values() for v in x.get('volumes',[])))
        docker=(ROOT/'deploy/pot-provider/Dockerfile').read_text()
        self.assertIn('USER 10001:10001',docker)
        self.assertNotIn('--chown=1000:',docker)

if __name__=='__main__':unittest.main()
