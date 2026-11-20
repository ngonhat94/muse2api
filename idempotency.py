"""Single-runtime durable async admission. Never evict a used/uncertain key.

TTL ends replay eligibility, not deduplication: expired keys conflict forever.
At capacity new keys fail closed. Explicit offline operator reconciliation is
required to reclaim capacity; silent eviction would allow duplicate upstream work.
"""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import stat
import tempfile
import threading
import time
import uuid

from protection import AccountCipher


class Conflict(ValueError):
    pass


class Capacity(ValueError):
    pass


class GenerationLedger:
    def __init__(self, path, capacity=10000, ttl=86400, initialize=False):
        if not 1 <= capacity <= 10000 or ttl < 1:
            raise ValueError('positive ledger capacity and TTL required')
        self.path = Path(path)
        self.marker = self.path.with_name(self.path.name + '.initialized')
        self.capacity, self.ttl = capacity, ttl
        self.per_owner = int(os.environ.get('MUSE2API_LEDGER_PER_OWNER', '1000'))
        if not 1 <= self.per_owner <= 10000:
            raise ValueError('per-owner ledger limit must be 1-10000')
        self.lock = threading.Lock()
        self.cipher = AccountCipher()
        self.poisoned = False
        try:
            fd = os.open(self.path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
        except FileNotFoundError:
            if self.marker.exists() or not initialize:
                raise ValueError('generation ledger missing; offline initialization/reconciliation required')
            self.entries = []
            # Marker first: crash during bootstrap requires reconciliation, not
            # automatic empty recreation. Both writes are durable before use.
            from tenant import _write
            _write(str(self.marker), {'schema': 1})
            self._persist([])
        else:
            with os.fdopen(fd, encoding='utf-8') as handle:
                if not stat.S_ISREG(os.fstat(handle.fileno()).st_mode):
                    raise ValueError('unsafe generation ledger')
                self.entries = self.cipher.decode(json.load(handle))
            if len(self.entries) > capacity:
                raise ValueError('generation ledger exceeds configured capacity')
            scopes = set()
            for entry in self.entries:
                if (set(entry) != {'scope', 'binding', 'owner', 'id', 'created_at', 'expires'}
                        or any(not isinstance(entry[field], str) or len(entry[field]) != 64
                               or any(c not in '0123456789abcdef' for c in entry[field])
                               for field in ('scope', 'binding', 'owner'))
                        or not isinstance(entry['id'], str)
                        or len(entry['id']) != 25 or not entry['id'].startswith('task_')
                        or any(c not in '0123456789abcdef' for c in entry['id'][5:])
                        or type(entry['created_at']) is not int
                        or type(entry['expires']) not in (int, float)
                        or not entry['created_at'] < entry['expires']
                        or entry['scope'] in scopes):
                    raise ValueError('invalid generation ledger; restore matching backup')
                scopes.add(entry['scope'])
            if not self.marker.is_file():
                raise ValueError('legacy ledger requires offline migration')

    def _persist(self, entries):
        fd, temporary = tempfile.mkstemp(prefix='.generation-ledger-', dir=self.path.parent)
        try:
            with os.fdopen(fd, 'w', encoding='utf-8') as handle:
                json.dump(self.cipher.encode(entries), handle)
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(temporary, self.path)
            directory = os.open(self.path.parent, os.O_RDONLY)
            try:
                os.fsync(directory)
            finally:
                os.close(directory)
        except BaseException:
            # Rename/fsync failure has an uncertain commit outcome. No more
            # admissions until restart reads the durable file.
            self.poisoned = True
            raise
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)

    def admit(self, owner, operation, key, payload, authority=1, now=None):
        if not isinstance(key, str) or not 1 <= len(key) <= 256 or any(ord(c) < 33 or ord(c) > 126 for c in key):
            raise ValueError('invalid Idempotency-Key')
        now = time.time() if now is None else now
        scope = hashlib.sha256(json.dumps([owner, operation, key], separators=(',', ':')).encode()).hexdigest()
        owner_digest = hashlib.sha256(owner.encode()).hexdigest()
        binding = hashlib.sha256(json.dumps([authority, payload], sort_keys=True, ensure_ascii=False, separators=(',', ':'), allow_nan=False).encode()).hexdigest()
        with self.lock:
            if not self.path.is_file() or not self.marker.is_file():
                self.poisoned = True
            if self.poisoned:
                raise Capacity('generation ledger unavailable')
            for entry in self.entries:
                if entry['scope'] == scope:
                    if entry['binding'] != binding or now >= entry['expires']:
                        raise Conflict('Idempotency-Key conflicts or replay window expired')
                    return dict(entry), False
            if len(self.entries) >= self.capacity:
                raise Capacity('generation ledger full; operator reconciliation required')
            if sum(e['owner'] == owner_digest for e in self.entries) >= self.per_owner:
                raise Capacity('owner generation ledger full; operator reconciliation required')
            entry = {'scope': scope, 'binding': binding, 'owner': owner_digest, 'id': 'task_' + uuid.uuid4().hex[:20],
                     'created_at': int(now), 'expires': now + self.ttl}
            entries = self.entries + [entry]
            self._persist(entries)
            self.entries = entries
            return dict(entry), True
