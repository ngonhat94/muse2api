"""账号池与任务存储（JSON 落盘，原子写）。"""
from __future__ import annotations

import json
import os
import tempfile
import threading
import time
import uuid
import stat
from contextlib import contextmanager


@contextmanager
def _directory_fd(path, create=False):
    """Walk from the filesystem root; never follow a mutable path symlink."""
    fd = os.open('/', os.O_RDONLY | os.O_DIRECTORY)
    try:
        for part in os.path.abspath(path).split(os.sep):
            if not part:
                continue
            if create:
                try:
                    os.mkdir(part, 0o700, dir_fd=fd)
                except FileExistsError:
                    pass
            child = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
            os.close(fd)
            fd = child
        yield fd
    finally:
        os.close(fd)

from proxy import public_proxy
from protection import AccountCipher, load_accounts, StorageQuotaExceeded

_LOCK = threading.Lock()
ADMIN_OWNER = "admin"
MEDIA_EXTENSIONS = frozenset((".gif", ".jpeg", ".jpg", ".mov", ".mp4",
                              ".png", ".webm", ".webp"))


def valid_media_name(name: object) -> bool:
    return (isinstance(name, str) and 1 <= len(name) <= 255
            and os.path.basename(name) == name and name not in (".", "..")
            and os.path.splitext(name)[1].lower() in MEDIA_EXTENSIONS)

# 登录会话存在性检查；可用性仍须经上游认证（与 engine 一致）
# hatch_vml 是可选工作区令牌，缺失不能据此拒绝会话导入
ESSENTIAL_COOKIES = ("hatch_sess",)


def _is_pos(v) -> bool:
    try:
        return int(v) > 0
    except (TypeError, ValueError):
        return False


# hatch_vml 固定约 2 天，且不因使用而延长 —— 它就是决定账号寿命的那条 cookie。
# 实测对照：生成前后 synced_at 变了、也捞到新 cookie，但 4 条核心 cookie 的
# expires 一动不动。所以拿不到 hatch_vml 的 expires 时，按「导入时间 + 2 天」估算，
# 而不是退回到 hatch_native_auth_device 的 30 天（那个不决定生死，会误导用户）。
VML_TTL = 2 * 86400


def min_expiry(cookies_exp: dict | None) -> int | None:
    """核心 cookie 里最早过期的那个（通用兜底，不区分哪条决定寿命）。"""
    if not cookies_exp:
        return None
    vals = []
    for name in ESSENTIAL_COOKIES:
        v = cookies_exp.get(name)
        try:
            v = int(v)
        except (TypeError, ValueError):
            continue
        if v > 0:
            vals.append(v)
    if not vals:
        for v in cookies_exp.values():
            try:
                v = int(v)
            except (TypeError, ValueError):
                continue
            if v > 0:
                vals.append(v)
    return min(vals) if vals else None


def account_expiry(cookies_exp: dict | None,
                   base_ts: int | None = None) -> int | None:
    """账号实际失效时间。

    优先级：
      1) hatch_vml 的真实 expires（最准）；
      2) 拿不到就用 base_ts(导入/同步时刻) + VML_TTL 估算 —— 因为寿命就是 2 天；
      3) 都没有再退回核心 cookie 最早过期。
    """
    ce = cookies_exp or {}
    vml = ce.get("hatch_vml")
    if _is_pos(vml):
        return int(vml)
    if base_ts:
        return int(base_ts) + VML_TTL
    return min_expiry(ce)


def _read(path: str, default):
    if not os.path.isfile(path):
        return default
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except Exception:  # noqa: BLE001
        return default


def _write(path: str, obj):
    d = os.path.dirname(path)
    os.makedirs(d, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=d)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(obj, f, ensure_ascii=False, indent=1)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, path)
        with _directory_fd(d) as directory:
            os.fsync(directory)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


class Store:
    def __init__(self, cfg):
        self.cfg = cfg
        self._account_cipher = AccountCipher()
        self.accounts: list[dict] = load_accounts(cfg.accounts_file, self._account_cipher)
        for a in self.accounts:
            ce = a.get("cookies_exp") or {}
            if _is_pos(ce.get("hatch_vml")):
                a["expires_at"] = int(ce["hatch_vml"])
        self.tasks: dict[str, dict] = _read(cfg.tasks_file, {})
        self._had_media_index = os.path.exists(cfg.media_index_file)
        loaded_media = _read(cfg.media_index_file, {})
        self.media: dict[str, dict] = loaded_media if isinstance(loaded_media, dict) else {}
        self._migrate_legacy_ownership()

    def _write_accounts(self):
        _write(self.cfg.accounts_file, self._account_cipher.encode(self.accounts))

    def _migrate_legacy_ownership(self):
        """Idempotently pin pre-tenant records to the legacy administrator."""
        marker = self.cfg.media_index_file + ".ownership-migrated"
        if os.path.exists(marker):
            return
        os.makedirs(os.path.dirname(marker), exist_ok=True)
        # Interrupted migration fails closed on subsequent starts.
        with open(marker, "x", encoding="utf-8") as handle:
            handle.write("1\n")
            handle.flush()
            os.fsync(handle.fileno())
        with _directory_fd(os.path.dirname(marker)) as directory:
            os.fsync(directory)
        accounts_changed = False
        tasks_changed = False
        for account in self.accounts:
            if not account.get("owner_id"):
                account["owner_id"] = ADMIN_OWNER
                accounts_changed = True
        for task in self.tasks.values():
            if not task.get("owner_id"):
                task["owner_id"] = ADMIN_OWNER
                tasks_changed = True
        media_changed = False
        # A pre-existing ownership index is already tenant-era. Never repair
        # missing/corrupt ownership by granting administrator access.
        # Existing on-disk blobs are legacy administrator assets. Unknown new
        # blobs remain inaccessible until register_media records their owner.
        if not self._had_media_index:
            try:
                with _directory_fd(self.cfg.media_dir) as directory:
                    for name in os.listdir(directory):
                        info = os.stat(name, dir_fd=directory, follow_symlinks=False)
                        if valid_media_name(name) and stat.S_ISREG(info.st_mode) and name not in self.media:
                            self.media[name] = {"owner_id": ADMIN_OWNER,
                                                "created_at": int(info.st_mtime)}
                            media_changed = True
            except FileNotFoundError:
                pass
        if accounts_changed:
            self._write_accounts()
        if tasks_changed:
            _write(self.cfg.tasks_file, self.tasks)
        if media_changed:
            _write(self.cfg.media_index_file, self.media)

    # ---------- 账号 ----------
    def add_account(self, cookies: dict, label: str = "",
                    cookies_exp: dict | None = None,
                    owner_id: str = ADMIN_OWNER) -> dict:
        with _LOCK:
            aid = uuid.uuid4().hex[:12]
            exp = {k: int(v) for k, v in (cookies_exp or {}).items()
                   if _is_pos(v)}
            now = int(time.time())
            acc = {"id": aid, "owner_id": owner_id, "label": label or aid, "cookies": cookies,
                   "cookies_exp": exp, "expires_at": account_expiry(exp, now),
                   "expiry_anchor": None,
                   "enabled": True, "created_at": now,
                   "last_used": None, "last_keepalive": None, "use_count": 0,
                   "ok": None, "note": "", "synced_at": None}
            self.accounts.append(acc)
            self._write_accounts()
            return acc

    @staticmethod
    def public_account(account: dict) -> dict:
        item = {k: v for k, v in account.items() if k not in ("cookies", "proxy")}
        item["proxy"] = public_proxy(account.get("proxy"))
        item["cookie_count"] = len(account.get("cookies", {}))
        note = str(item.get('note') or '')
        for secret in account.get('cookies', {}).values():
            if isinstance(secret, str) and secret:
                note = note.replace(secret, '[redacted]')
        import re
        item['note'] = re.sub(r'https?://\S+', '[redacted URL]', note)
        return item

    def list_accounts(self, owner_id: str = ADMIN_OWNER) -> list[dict]:
        out = []
        for a in self.accounts:
            if a.get("owner_id") != owner_id:
                continue
            item = self.public_account(a)
            ce = a.get("cookies_exp") or {}
            if _is_pos(ce.get("hatch_vml")):
                item["expires_at"] = int(ce["hatch_vml"])
            item["cookie_count"] = len(a.get("cookies", {}))
            item["essential_ok"] = all(
                a.get("cookies", {}).get(n) for n in ESSENTIAL_COOKIES)
            # 有效期是 hatch_vml 的实测 expires，还是按「2 天寿命」推算的
            item["expires_estimated"] = not _is_pos(ce.get("hatch_vml"))
            out.append(item)
        return out

    def delete_account(self, aid: str, owner_id: str = ADMIN_OWNER) -> bool:
        with _LOCK:
            n = len(self.accounts)
            self.accounts = [a for a in self.accounts
                             if not (a["id"] == aid and a.get("owner_id") == owner_id)]
            self._write_accounts()
            return len(self.accounts) != n

    def pick_account(self, preferred_id: str | None = None, rotate: bool = True,
                     force_rotate: bool = False, exclude_id: str | None = None,
                     exclude_ids: set[str] | list[str] | None = None,
                     record_use: bool = True,
                     owner_id: str = ADMIN_OWNER) -> dict | None:
        """选择可用账号：优先复用当前已预热的健康账号（减少切号重连耗时），每满 15 次或遇错自动轮转。
        exclude_ids: 需要排除的账号 ID 集合（例如正在被其他并发线程占用的账号）。"""
        with _LOCK:
            live = [a for a in self.accounts
                    if a.get("owner_id") == owner_id
                    and a.get("enabled", True) and a.get("cookies")]
            if not live:
                return None
            blocked = set(exclude_ids or [])
            if exclude_id:
                blocked.add(exclude_id)
            if blocked:
                available = [a for a in live if a["id"] not in blocked]
                if available:
                    live = available
                elif exclude_ids is not None:
                    # 并发模式下要求避开所有繁忙账号，但当前无剩余空闲账号
                    return None
                elif len(live) > 1:
                    live = [a for a in live if a["id"] != exclude_id] or live
            if preferred_id and not rotate and not force_rotate:
                for a in live:
                    if a["id"] == preferred_id and a.get("ok") is not False:
                        self._sticky_id = preferred_id
                        self._sticky_count = 1
                        if record_use:
                            a["last_used"] = time.time()
                            a["use_count"] = a.get("use_count", 0) + 1
                            self._write_accounts()
                        return a
            healthy = [a for a in live if a.get("ok") is not False]
            candidates = healthy if healthy else live
            candidates.sort(key=lambda a: (a.get("last_used") or 0.0, a.get("use_count") or 0))
            acc = candidates[0]
            self._sticky_id = acc["id"]
            self._sticky_count = 1
            if record_use:
                acc["last_used"] = time.time()
                acc["use_count"] = acc.get("use_count", 0) + 1
                self._write_accounts()
            return acc

    def touch_keepalive(self, aid: str, ok: bool | None = True, note: str = "",
                        owner_id: str = ADMIN_OWNER):
        """ok=None 仅记录未确认的检测；保留上次账号状态、成功保活时间和有效期。"""
        with _LOCK:
            now_ts = int(time.time())
            for a in self.accounts:
                if a["id"] == aid and a.get("owner_id") == owner_id:
                    if ok is not None:
                        a["ok"] = ok
                    if ok is True:
                        a["last_keepalive"] = now_ts
                        # ponytail: 只信实际 Cookie 到期时间或原导入锚点，不凭检测成功虚推 48h。
                        a["expires_at"] = account_expiry(
                            a.get("cookies_exp"), a.get("expiry_anchor") or a.get("created_at"))
                    if note:
                        a["note"] = note[:300]
                    a["checked_at"] = now_ts
            self._write_accounts()

    def mark(self, aid: str, ok: bool, note: str = "",
             owner_id: str = ADMIN_OWNER):
        with _LOCK:
            for a in self.accounts:
                if a["id"] == aid and a.get("owner_id") == owner_id:
                    a["ok"] = ok
                    a["note"] = note[:300]
                    a["checked_at"] = int(time.time())
            self._write_accounts()

    def get_account(self, aid: str, owner_id: str = ADMIN_OWNER) -> dict | None:
        for a in self.accounts:
            if a["id"] == aid and a.get("owner_id") == owner_id:
                return a
        return None

    def get_account_internal(self, aid: str) -> dict | None:
        """Resolve a globally unique account only after a caller checked ownership."""
        for account in self.accounts:
            if account["id"] == aid:
                return account
        return None

    def update_account(self, aid: str, owner_id: str = ADMIN_OWNER, **kw) -> dict | None:
        """更新标签 / 启用状态 / cookies / 有效期等；值为 None 的字段跳过。

        传了 cookies_exp 会自动重算 expires_at，不用调用方自己算。
        估算锚点 expiry_anchor 的维护规则（避免有效期被反复虚推）：
          - 读到了 hatch_vml 的真实 expires  -> 清空锚点，直接用真值；
          - 读不到且锚点为空                -> 把锚点钉在当下（只钉一次）；
          - 补入全新会话 cookie（重登）      -> 调用方显式传 expiry_anchor=now 重置。
        """
        with _LOCK:
            for a in self.accounts:
                if a["id"] == aid and a.get("owner_id") == owner_id:
                    for k, v in kw.items():
                        if v is not None or k == "ok":
                            a[k] = v
                    if "cookies_exp" in kw and kw["cookies_exp"] is not None:
                        ce = a["cookies_exp"]
                        if _is_pos(ce.get("hatch_vml")):
                            a["expiry_anchor"] = None
                        elif not a.get("expiry_anchor"):
                            a["expiry_anchor"] = int(time.time())
                        a["expires_at"] = account_expiry(
                            ce, a.get("expiry_anchor") or a.get("created_at"))
                    self._write_accounts()
                    return a
        return None

    def stats(self, owner_id: str = ADMIN_OWNER) -> dict:
        now = int(time.time())
        owned = [a for a in self.accounts if a.get("owner_id") == owner_id]
        total = len(owned)
        enabled = sum(1 for a in owned if a.get("enabled", True))
        bad = sum(1 for a in owned
                  if a.get("enabled", True) and a.get("ok") is False)
        healthy = sum(1 for a in owned
                      if a.get("enabled", True) and a.get("ok") is True)
        expiring = sum(1 for a in owned
                       if a.get("enabled", True)
                       and a.get("expires_at")
                       and a["expires_at"] - now < 3 * 86400)
        expired = sum(1 for a in owned
                      if a.get("enabled", True)
                      and a.get("expires_at") and a["expires_at"] <= now)
        return {"total": total, "enabled": enabled, "disabled": total - enabled,
                "healthy": healthy, "error": bad,
                "expiring": expiring, "expired": expired}

    # ---------- 任务 ----------
    def create_task(self, kind: str, prompt: str,
                    owner_id: str = ADMIN_OWNER, task_id: str | None = None) -> dict:
        with _LOCK:
            tid = task_id or "task_" + uuid.uuid4().hex[:20]
            if tid in self.tasks:
                raise ValueError('task identity already exists')
            t = {"id": tid, "owner_id": owner_id, "object": "task", "kind": kind, "prompt": prompt,
                 "status": "queued", "created_at": int(time.time()),
                 "updated_at": int(time.time()), "result": None, "error": None}
            self.tasks[tid] = t
            _write(self.cfg.tasks_file, self.tasks)
            return t

    def update_task(self, tid: str, owner_id: str = ADMIN_OWNER, **kw):
        with _LOCK:
            t = self.tasks.get(tid)
            if not t or t.get("owner_id") != owner_id:
                return None
            t.update(kw)
            t["updated_at"] = int(time.time())
            _write(self.cfg.tasks_file, self.tasks)
            return t

    def get_task(self, tid: str, owner_id: str = ADMIN_OWNER) -> dict | None:
        task = self.tasks.get(tid)
        return task if task and task.get("owner_id") == owner_id else None

    def list_tasks(self, limit: int = 50, owner_id: str = ADMIN_OWNER) -> list[dict]:
        items = sorted((t for t in self.tasks.values() if t.get("owner_id") == owner_id),
                       key=lambda t: t.get("created_at") or 0, reverse=True)
        return items[:limit]

    def delete_task(self, tid: str, owner_id: str = ADMIN_OWNER) -> bool:
        with _LOCK:
            if tid in self.tasks and self.tasks[tid].get("owner_id") == owner_id:
                del self.tasks[tid]
                _write(self.cfg.tasks_file, self.tasks)
                return True
            return False

    def cancel_task(self, tid: str, owner_id: str = ADMIN_OWNER) -> dict | None:
        with _LOCK:
            task = self.tasks.get(tid)
            if not task or task.get("owner_id") != owner_id:
                return None
            if task.get("status") not in ("queued", "processing"):
                return task
            task.update(status="failed", cancelled=True, error="任务已取消",
                        updated_at=int(time.time()))
            _write(self.cfg.tasks_file, self.tasks)
            return task

    def clear_tasks(self, keep: int = 0, owner_id: str = ADMIN_OWNER) -> int:
        with _LOCK:
            items = sorted((t for t in self.tasks.values() if t.get("owner_id") == owner_id),
                           key=lambda t: t.get("created_at") or 0, reverse=True)
            keep_ids = {t["id"] for t in items[:keep]}
            owned_ids = {t["id"] for t in items}
            removed = len(owned_ids - keep_ids)
            self.tasks = {k: v for k, v in self.tasks.items()
                          if k not in owned_ids or k in keep_ids}
            _write(self.cfg.tasks_file, self.tasks)
            return max(0, removed)

    def retention(self, owner_id, dry_run=True, now=None):
        now = time.time() if now is None else now
        cutoff = now - self.storage_limits(owner_id)['retention_days'] * 86400
        candidates, quarantined = [], []
        with _LOCK, _directory_fd(self.cfg.media_dir, create=True) as directory:
            for name in sorted(os.listdir(directory)):
                info = os.stat(name, dir_fd=directory, follow_symlinks=False)
                if not stat.S_ISREG(info.st_mode) or not self.media_owner(name):
                    quarantined.append(name)
                    continue
                if self.media_owner(name) == owner_id and self.media[name].get('created_at', now) < cutoff:
                    candidates.append(name)
            if not dry_run:
                for name in candidates:
                    self._delete_media_at(name, owner_id, directory)
        return {'dry_run': dry_run, 'candidates': candidates, 'quarantined': quarantined}

    def storage_limits(self, owner_id):
        provider = getattr(self, 'limit_provider', lambda owner: {})
        overrides = provider(owner_id)
        return {'bytes': overrides.get('storage_bytes') or max(1, int(os.environ.get('MUSE2API_STORAGE_BYTES', 2 * 1024 ** 3))),
                'files': overrides.get('storage_files') or max(1, int(os.environ.get('MUSE2API_STORAGE_FILES', 1000))),
                'retention_days': overrides.get('retention_days') or max(1, int(os.environ.get('MUSE2API_MEDIA_RETENTION_DAYS', 30)))}

    def storage_usage(self, owner_id):
        # Unknown files are never adopted. Refuse writes until an operator
        # reconciles them; otherwise loss of the index could reset accounting.
        total = count = 0
        with _directory_fd(self.cfg.media_dir, create=True) as directory:
            for name in os.listdir(directory):
                info = os.stat(name, dir_fd=directory, follow_symlinks=False)
                if not stat.S_ISREG(info.st_mode) or not self.media_owner(name):
                    raise ValueError('storage accounting unavailable: unindexed or unsafe media')
                if self.media_owner(name) == owner_id:
                    total += info.st_size
                    count += 1
        return {'bytes': total, 'files': count, 'limits': self.storage_limits(owner_id)}

    def write_media(self, name, data, owner_id):
        if not valid_media_name(name):
            raise ValueError('invalid media filename')
        with _LOCK, _directory_fd(self.cfg.media_dir, create=True) as directory:
            usage = self.storage_usage(owner_id)
            limits = usage['limits']
            if usage['bytes'] + len(data) > limits['bytes'] or usage['files'] + 1 > limits['files']:
                raise StorageQuotaExceeded('storage quota exceeded; delete owned media or ask administrator')
            path = os.path.join(self.cfg.media_dir, name)
            # Exclusive create: never overwrite another tenant, even if UUID
            # collision or a competing file appears after accounting.
            try:
                fd = os.open(name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=directory)
            except FileExistsError:
                raise ValueError('media destination already exists') from None
            try:
                with os.fdopen(fd, 'wb') as handle:
                    handle.write(data)
                    handle.flush()
                    os.fsync(handle.fileno())
                self.media[name] = {'owner_id': owner_id, 'created_at': int(time.time())}
                _write(self.cfg.media_index_file, self.media)
            except BaseException:
                self.media.pop(name, None)
                os.unlink(name, dir_fd=directory)
                raise
            return path

    def open_media(self, name):
        if not valid_media_name(name):
            raise ValueError('invalid media filename')
        with _directory_fd(self.cfg.media_dir) as directory:
            fd = os.open(name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=directory)
        if not stat.S_ISREG(os.fstat(fd).st_mode):
            os.close(fd)
            raise ValueError('unsafe media')
        return os.fdopen(fd, 'rb')

    # ---------- 媒体 ----------
    def register_media(self, name: str, owner_id: str) -> None:
        if not valid_media_name(name):
            raise ValueError("invalid media filename")
        with _LOCK:
            existing = self.media_owner(name)
            if existing and existing != owner_id:
                raise ValueError('media belongs to another owner')
            if existing:
                return
            self.media[name] = {"owner_id": owner_id, "created_at": int(time.time())}
            _write(self.cfg.media_index_file, self.media)

    def media_owner(self, name: str) -> str | None:
        if not valid_media_name(name):
            return None
        item = self.media.get(name)
        return item.get("owner_id") if isinstance(item, dict) else None

    def list_media_names(self, owner_id: str = ADMIN_OWNER) -> list[str]:
        return [name for name, item in self.media.items()
                if valid_media_name(name) and isinstance(item, dict)
                and item.get("owner_id") == owner_id]

    def _delete_media_at(self, name, owner_id, directory):
        """Called only with accounting lock and a nofollow directory descriptor."""
        if self.media_owner(name) != owner_id:
            return False
        try:
            info = os.stat(name, dir_fd=directory, follow_symlinks=False)
        except FileNotFoundError:
            return False
        if not stat.S_ISREG(info.st_mode):
            raise ValueError('unsafe media')
        # unlinkat never follows a substituted leaf symlink. A parent rename
        # cannot redirect this operation away from the opened directory.
        os.unlink(name, dir_fd=directory)
        self.media.pop(name, None)
        _write(self.cfg.media_index_file, self.media)
        return True

    def delete_media(self, name: str, owner_id: str = ADMIN_OWNER) -> bool:
        with _LOCK:
            if self.media_owner(name) != owner_id:
                return False
            try:
                with _directory_fd(self.cfg.media_dir) as directory:
                    return self._delete_media_at(name, owner_id, directory)
            except FileNotFoundError:
                return False
