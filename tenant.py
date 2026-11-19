"""Tenant principals and hashed API-key persistence."""
from __future__ import annotations

import hashlib
import hmac
import json
import os
import secrets
import tempfile
import threading
import time


_LOCK = threading.RLock()


def shared_transaction(method):
    """Serialize fresh read/modify/write across instances and worker processes."""
    from functools import wraps
    @wraps(method)
    def wrapped(self, *args, **kwargs):
        import fcntl
        with _LOCK:
            if self._depth:
                return method(self, *args, **kwargs)
            os.makedirs(os.path.dirname(self.path), exist_ok=True)
            with open(self.path + ".lock", "a+") as lock:
                fcntl.flock(lock, fcntl.LOCK_EX)
                try:
                    try:
                        with open(self.path, encoding="utf-8") as handle:
                            loaded = json.load(handle)
                        if not isinstance(loaded, list):
                            raise ValueError("invalid user store")
                        self.users = loaded
                    except FileNotFoundError:
                        self.users = []
                    self._depth += 1
                    try:
                        return method(self, *args, **kwargs)
                    finally:
                        self._depth -= 1
                finally:
                    fcntl.flock(lock, fcntl.LOCK_UN)
    return wrapped



def _write(path: str, value) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    fd, temporary = tempfile.mkstemp(dir=os.path.dirname(path))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(value, handle, ensure_ascii=False, indent=1)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
        directory = os.open(os.path.dirname(path), os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def _hash_key(raw: str) -> str:
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()


class UserStore:
    def __init__(self, path: str):
        self.path = os.path.abspath(path)
        self._depth = 0
        try:
            with open(path, encoding="utf-8") as handle:
                loaded = json.load(handle)
        except (OSError, ValueError, TypeError):
            loaded = []
        self.users: list[dict] = loaded if isinstance(loaded, list) else []

    @staticmethod
    def public(user: dict) -> dict:
        result = {key: value for key, value in user.items()
                  if key not in ("key_hash", "key_ciphertext")}
        # Presence, not authorization: disabled and legacy hash-only keys exist.
        result['key_active'] = bool(user.get('key_hash'))
        result['key_revealable'] = bool(user.get('key_hash') and user.get('key_ciphertext'))
        return result

    @staticmethod
    def _seal(user: dict, raw: str) -> str:
        # Reuse the externally provisioned, owner-protected server key. Domain
        # separation and record binding prevent cookie/token or row substitution.
        from protection import AccountCipher
        payload = json.dumps(['muse2api-user-key-v1', user['id'],
                              user['key_hash'], raw]).encode()
        return AccountCipher().cipher.encrypt(payload).decode()

    @shared_transaction
    def reveal(self, user_id: str) -> str | None:
        from protection import AccountCipher
        from cryptography.fernet import InvalidToken
        user = self.get(user_id)
        if not user or not user.get('key_hash') or not user.get('key_ciphertext'):
            return None
        try:
            value = json.loads(AccountCipher().cipher.decrypt(user['key_ciphertext'].encode()))
            domain, owner, digest, raw = value
            if (domain != 'muse2api-user-key-v1' or owner != user_id
                    or digest != user['key_hash']
                    or not hmac.compare_digest(_hash_key(raw), user['key_hash'])):
                raise ValueError()
            return raw
        except (InvalidToken, ValueError, TypeError, KeyError, AttributeError):
            raise ValueError('API key unavailable; restore matching server key and backup') from None


    @shared_transaction
    def list(self) -> list[dict]:
        return [self.public(user) for user in self.users]

    @shared_transaction
    def get(self, user_id: str) -> dict | None:
        return next((user for user in self.users if user.get("id") == user_id), None)

    @shared_transaction
    def create(self, label: str) -> tuple[dict, str]:
        clean = label.strip()
        if not clean or len(clean) > 100:
            raise ValueError("label must contain 1-100 characters")
        raw = "m2u_" + secrets.token_urlsafe(32)
        now = int(time.time())
        user = {
            "id": "usr_" + secrets.token_hex(8),
            "label": clean,
            "role": "user",
            "enabled": True,
            "key_hash": _hash_key(raw),
            "key_version": 1,
            "created_at": now,
            "updated_at": now,
        }
        user['key_ciphertext'] = self._seal(user, raw)
        with _LOCK:
            self.users.append(user)
            _write(self.path, self.users)
        return self.public(user), raw

    @shared_transaction
    def authenticate(self, raw: str) -> dict | None:
        digest = _hash_key(raw)
        for user in self.users:
            stored = user.get("key_hash")
            if user.get("enabled", True) and stored and hmac.compare_digest(stored, digest):
                return self.public(user)
        return None

    @shared_transaction
    def patch(self, user_id: str, *, label=None, enabled=None) -> dict | None:
        with _LOCK:
            user = self.get(user_id)
            if not user:
                return None
            if label is not None:
                clean = str(label).strip()
                if not clean or len(clean) > 100:
                    raise ValueError("label must contain 1-100 characters")
                user["label"] = clean
            if enabled is not None:
                user["enabled"] = bool(enabled)
                if not enabled:
                    user["key_version"] = int(user.get("key_version") or 0) + 1
            user["updated_at"] = int(time.time())
            _write(self.path, self.users)
            return self.public(user)

    @shared_transaction
    def rotate(self, user_id: str) -> tuple[dict, str] | None:
        raw = "m2u_" + secrets.token_urlsafe(32)
        with _LOCK:
            user = self.get(user_id)
            if not user:
                return None
            updated = dict(user, key_hash=_hash_key(raw))
            ciphertext = self._seal(updated, raw)
            user['key_ciphertext'] = ciphertext
            user["key_hash"] = updated['key_hash']
            user["key_version"] = int(user.get("key_version") or 0) + 1
            user["enabled"] = True
            user["updated_at"] = int(time.time())
            _write(self.path, self.users)
            return self.public(user), raw

    @shared_transaction
    def set_limits(self, user_id, limits):
        user = self.get(user_id)
        if not user:
            return None
        user['limits'] = dict(limits)
        _write(self.path, self.users)
        return self.public(user)

    @shared_transaction
    def revoke(self, user_id: str) -> dict | None:
        with _LOCK:
            user = self.get(user_id)
            if not user:
                return None
            user.pop('key_ciphertext', None)
            user["key_hash"] = None
            user["key_version"] = int(user.get("key_version") or 0) + 1
            user["updated_at"] = int(time.time())
            _write(self.path, self.users)
            return self.public(user)

    @shared_transaction
    def capability_state(self, user_id: str) -> tuple[bool, int, str]:
        user = self.get(user_id)
        if not user:
            return False, 0, ""
        return (bool(user.get("enabled", True) and user.get("key_hash")),
                int(user.get("key_version") or 0), str(user.get("key_hash") or ""))

