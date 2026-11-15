"""Durable administrator authority epoch. Never adopt a mismatched startup key."""
import hashlib
import json
import secrets
import threading
from pathlib import Path

from tenant import _write


class AdminAuthority:
    def __init__(self, path, key):
        self.path = str(path)
        self.lock = threading.RLock()
        marker = Path(str(path) + '.initialized')
        if not Path(path).exists():
            if marker.exists():
                raise ValueError('Admin authority missing; restore matching backup')
            _write(str(marker), {'schema': 1})
            _write(self.path, {'version': 1, 'key_hash': self._digest(key)})
        elif not marker.is_file():
            raise ValueError('Admin authority marker missing; offline reconciliation required')
        if self.version(key) is None:
            raise ValueError('Admin authority key mismatch; offline reconciliation required')

    @staticmethod
    def _digest(key):
        return hashlib.sha256(key.encode()).hexdigest()

    def version(self, key):
        with self.lock:
            with open(self.path, encoding='utf-8') as handle:
                state = json.load(handle)
            if (set(state) != {'version', 'key_hash'} or type(state['version']) is not int
                    or state['version'] < 1 or not isinstance(state['key_hash'], str)
                    or len(state['key_hash']) != 64):
                raise ValueError('Invalid administrator authority state')
            return state['version'] if secrets.compare_digest(state['key_hash'], self._digest(key)) else None

    def rotate(self, old, new, persist):
        with self.lock:
            version = self.version(old)
            if version is None:
                raise ValueError('Stale administrator authority')
            # Commit authority first: any later failure disables the old key and
            # outstanding workers, rather than silently retaining old authority.
            _write(self.path, {'version': version + 1, 'key_hash': self._digest(new)})
            persist(new)
            return version + 1
