"""Trusted namespace-local firewall guard. No provider code or HTTP listener.

Requires NET_ADMIN only in its own dedicated Docker network namespace.
Never run with host networking. Does not modify any host/Docker chain.
"""
import hashlib
import ipaddress
import json
import os
from pathlib import Path
import subprocess
import sys
import time

TABLE = 'muse_pot_guard'
CONFIG = Path('/etc/muse-pot/policy.json')
STATE = Path('/run/muse-pot-guard/state.json')
BLOCKED = (
    '0.0.0.0/8', '10.0.0.0/8', '100.64.0.0/10', '127.0.0.0/8',
    '169.254.0.0/16', '172.16.0.0/12', '192.0.0.0/24', '192.0.2.0/24',
    '192.168.0.0/16', '198.18.0.0/15', '198.51.100.0/24',
    '203.0.113.0/24', '224.0.0.0/4', '240.0.0.0/4', '168.63.129.16/32',
)


def policy(value):
    if not isinstance(value, dict) or set(value) != {'resolver_v4', 'deny_host_v4'}:
        raise ValueError('Invalid network policy fields')
    if not isinstance(value['resolver_v4'], str):
        raise ValueError('Resolver must be an IPv4 string')
    resolver = ipaddress.ip_address(value['resolver_v4'])
    if resolver.version != 4 or not resolver.is_global or resolver.is_multicast or resolver.is_reserved:
        raise ValueError('A reviewed public IPv4 resolver is required')
    hosts = value['deny_host_v4']
    if not isinstance(hosts, list) or not 1 <= len(hosts) <= 64:
        raise ValueError('Host/tenant deny networks are required')
    networks = []
    for item in hosts:
        if not isinstance(item, str):
            raise ValueError('Deny networks must be IPv4 strings')
        net = ipaddress.ip_network(item, strict=True)
        if net.version != 4 or net.prefixlen < 8:
            raise ValueError('Invalid IPv4 deny network')
        networks.append(net)
    if any(resolver in n for n in networks + [ipaddress.ip_network(n) for n in BLOCKED]):
        raise ValueError('Resolver overlaps a denied network')
    return dict(resolver_v4=str(resolver), deny_host_v4=sorted(set(map(str, networks))))


def rules(value, replace=False):
    value = policy(value)
    deny = ', '.join(BLOCKED)
    hosts = ', '.join(value['deny_host_v4'])
    resolver = value['resolver_v4']
    # A single nft batch replaces only this namespace-local table atomically.
    prefix = f'delete table inet {TABLE}\n' if replace else ''
    return prefix + f'''table inet {TABLE} {{
 set blocked_v4 {{ type ipv4_addr; flags interval; elements = {{ {deny} }}; }}
 set host_v4 {{ type ipv4_addr; flags interval; elements = {{ {hosts} }}; }}
 chain output {{
  type filter hook output priority -300; policy drop;
  meta nfproto ipv6 counter drop
  ip daddr @blocked_v4 counter drop
  ip daddr @host_v4 counter drop
  ip daddr {resolver} udp dport 53 counter accept
  ip daddr {resolver} tcp dport 53 counter accept
  meta nfproto ipv4 tcp dport 443 counter accept
  counter drop
 }}
 chain input {{
  type filter hook input priority -300; policy drop;
  meta nfproto ipv6 counter drop
  ct state established,related counter accept
  counter drop
 }}
}}\n'''


def nft(*args, source=None):
    return subprocess.run(['nft', *args], input=source, text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=5)


def fingerprint(value):
    def clean(data):
        if isinstance(data, list):
            return [clean(x) for x in data if not isinstance(x, dict) or 'metainfo' not in x]
        if isinstance(data, dict):
            return {k: clean(v) for k, v in data.items()
                    if k not in ('handle', 'counter', 'packets', 'bytes')}
        return data
    return hashlib.sha256(json.dumps(clean(value), sort_keys=True).encode()).hexdigest()


def current():
    result = nft('-j', 'list', 'table', 'inet', TABLE)
    if result.returncode:
        raise ValueError('Firewall table unavailable')
    return fingerprint(json.loads(result.stdout))


def digest(value):
    return hashlib.sha256(rules(value).encode()).hexdigest()


def ready():
    try:
        value = policy(json.loads(CONFIG.read_text()))
        state = json.loads(STATE.read_text())
        return (state['netns'] == os.stat('/proc/self/ns/net').st_ino
                and state['policy'] == digest(value) and state['rules'] == current())
    except (OSError, ValueError, TypeError, KeyError, subprocess.SubprocessError):
        return False


def install():
    value = policy(json.loads(CONFIG.read_text()))
    exists = nft('list', 'table', 'inet', TABLE).returncode == 0
    source = rules(value, replace=exists)
    # A valid identical reinstall need not briefly revoke readiness. Any failed
    # nft batch invalidates the proof; the table itself changes atomically.
    result = nft('-f', '-', source=source)
    if result.returncode:
        STATE.unlink(missing_ok=True)
        raise ValueError('Cannot install namespace policy')
    STATE.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    temporary = STATE.with_suffix('.new')
    fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, 'w') as handle:
        handle.write(json.dumps(dict(netns=os.stat('/proc/self/ns/net').st_ino,
                                    policy=digest(value), rules=current())))
    temporary.replace(STATE)
    if not ready():
        raise ValueError('Namespace policy verification failed')


def main():
    if sys.argv[1:] == ['--health']:
        raise SystemExit(0 if ready() else 1)
    try:
        install()
        while True:
            time.sleep(1)
            if not ready():
                STATE.unlink(missing_ok=True)
                raise ValueError('Policy changed: readiness revoked')
    except (OSError, ValueError, TypeError, subprocess.SubprocessError):
        # Never print configuration, subprocess stderr or credentials.
        raise SystemExit('Namespace firewall is not ready') from None


if __name__ == '__main__':
    main()
