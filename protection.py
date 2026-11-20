"""Authenticated account storage. Keys are provisioned externally, never generated here."""
from __future__ import annotations

import json
import os
import stat
from cryptography.fernet import Fernet, InvalidToken


class AccountCipher:
    def __init__(self):
        raw = os.environ.get('MUSE2API_COOKIE_KEY', '')
        path = os.environ.get('MUSE2API_COOKIE_KEY_FILE', '')
        if raw and path:
            raise ValueError('configure exactly one cookie encryption key source')
        if path:
            fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
            try:
                info = os.fstat(fd)
                if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077:
                    raise ValueError('cookie encryption key file must be owner-only')
                raw = os.read(fd, 4096).decode().strip()
            finally:
                os.close(fd)
        try:
            self.cipher = Fernet(raw.encode('ascii'))
        except (ValueError, UnicodeError):
            raise ValueError('valid externally provisioned cookie encryption key required') from None

    def encode(self, accounts):
        return {'format': 'muse2api-accounts-fernet-v1',
                'ciphertext': self.cipher.encrypt(json.dumps(accounts, ensure_ascii=False).encode()).decode()}

    def decode(self, value):
        if not isinstance(value, dict) or value.get('format') != 'muse2api-accounts-fernet-v1':
            raise ValueError('invalid encrypted account store; explicit migration required')
        try:
            accounts = json.loads(self.cipher.decrypt(value['ciphertext'].encode()))
            if not isinstance(accounts, list) or not all(isinstance(a, dict) for a in accounts):
                raise ValueError()
            return accounts
        except (InvalidToken, ValueError, TypeError, KeyError, AttributeError):
            raise ValueError('account store authentication failed; restore matching key and backup') from None


class StorageQuotaExceeded(ValueError):
    pass


class RequestLimiter:
    def __init__(self):
        import threading
        self.lock = threading.Lock()
        self.events = {}

    def admit(self, owner, limit, window, now=None):
        import time
        import math
        from collections import deque
        now = time.monotonic() if now is None else now
        if limit < 1 or window < 1:
            raise ValueError('rate limits must be positive')
        with self.lock:
            events = self.events.setdefault(owner, deque())
            while events and events[0] <= now - window:
                events.popleft()
            if len(events) >= limit:
                return max(1, math.ceil(events[0] + window - now))
            events.append(now)
            return 0


def migrate_accounts(path):
    """Explicit offline migration; operator must first back up data and key."""
    import fcntl
    import tempfile
    cipher = AccountCipher()
    directory = os.path.dirname(os.path.abspath(path))
    with open(os.path.join(directory, '.tenant-runtime.lock'), 'a+') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        with open(path, encoding='utf-8') as handle:
            value = json.load(handle)
        if isinstance(value, dict):
            cipher.decode(value)
            return False
        if not isinstance(value, list) or not all(isinstance(a, dict) and isinstance(a.get('cookies', {}), dict) for a in value):
            raise ValueError('invalid legacy account store')
        encrypted = cipher.encode(value)
        cipher.decode(encrypted)
        fd, temporary = tempfile.mkstemp(dir=directory)
        try:
            with os.fdopen(fd, 'w', encoding='utf-8') as handle:
                json.dump(encrypted, handle)
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(temporary, path)
            directory_fd = os.open(directory, os.O_RDONLY)
            try:
                os.fsync(directory_fd)
            finally:
                os.close(directory_fd)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)
        return True


def load_accounts(path, cipher):
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
        with os.fdopen(fd, 'r', encoding='utf-8') as handle:
            if not stat.S_ISREG(os.fstat(handle.fileno()).st_mode):
                raise ValueError('unsafe account store')
            value = json.load(handle)
    except FileNotFoundError:
        return []
    except (ValueError, OSError):
        raise ValueError('account store unreadable; restore backup') from None
    return cipher.decode(value)
