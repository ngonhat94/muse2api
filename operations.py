"""Offline operator tooling. No app/config imports, startup, network or key generation."""
from __future__ import annotations
import fcntl
import importlib.util
import json
import os
from pathlib import Path
import shutil
import stat
from contextlib import contextmanager

LIMIT = 64 * 1024 * 1024


REQUIRED = frozenset({'accounts.json', 'users.json', 'tasks.json', 'media-index.json',
                      'media-index.json.ownership-migrated'})
MAX_FILES = 10000


def operator_cipher():
    from protection import AccountCipher
    from cryptography.fernet import Fernet
    path = os.environ.get('MUSE2API_COOKIE_KEY_FILE', '')
    raw = os.environ.get('MUSE2API_COOKIE_KEY', '')
    if path:
        if raw:
            raise ValueError('configure exactly one key source')
        with directory_fd(Path(path).parent) as parent:
            fd = os.open(Path(path).name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=parent)
            with os.fdopen(fd, 'rb') as handle:
                info = os.fstat(handle.fileno())
                if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077 or info.st_nlink != 1:
                    raise ValueError('unsafe key file')
                raw = handle.read(4097).decode().strip()
    result = AccountCipher.__new__(AccountCipher)
    result.cipher = Fernet(raw.encode('ascii'))
    return result


def main(argv=None):
    import argparse
    parser = argparse.ArgumentParser(description='Offline operations. Never starts runtime or migrates/provisions data.')
    sub = parser.add_subparsers(dest='command', required=True)
    p = sub.add_parser('preflight')
    p.add_argument('directory')
    p.add_argument('--min-free-bytes', type=int, default=1024**3)
    p.add_argument('--inspect-accounts', action='store_true')
    b = sub.add_parser('backup')
    b.add_argument('directory')
    b.add_argument('archive')
    b.add_argument('--include-media', action='store_true')
    b.add_argument('--apply', action='store_true')
    v = sub.add_parser('verify')
    v.add_argument('archive')
    r = sub.add_parser('restore')
    r.add_argument('archive')
    r.add_argument('destination')
    r.add_argument('--apply', action='store_true')
    for command in (p,b,v,r):
        command.add_argument('--json', action='store_true')
    args = parser.parse_args(argv)
    try:
        if args.command == 'preflight':
            report = preflight(args.directory, args.min_free_bytes, args.inspect_accounts)
        elif args.command == 'backup':
            report = backup(args.directory, args.archive, args.include_media, args.apply)
        elif args.command == 'verify':
            report = verify(args.archive)
        else:
            report = restore(args.archive, args.destination, args.apply)
        code = report.get('exit_code', 0)
    except (OSError, ValueError, TypeError, ImportError):
        code = 2
        report = {'schema':1, 'exit_code':2, 'status':'block',
                  'remediation':'Operation refused. Check matching external key, intact snapshot, safe permissions, offline lock and new destination. No retry/migration is automatic. If publication fsync failed, inspect visible output before retry.'}
    if args.json:
        print(json.dumps(report, sort_keys=True))
    elif 'checks' in report:
        for check in report['checks']:
            print(f"{check['status'].upper()} {check['name']}: {check['remediation']}")
    else:
        print(json.dumps(report, sort_keys=True))
    return code


def _json(raw):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError('duplicate JSON key')
            result[key] = value
        return result
    try:
        return json.loads(raw, object_pairs_hook=unique)
    except RecursionError:
        # Python 3.11's decoder raises before schema validation on deep input.
        raise ValueError('JSON nesting exceeds safe limit') from None


def _allowed(name):
    if name in REQUIRED:
        return True
    if not isinstance(name, str) or not name.startswith('media/'):
        return False
    leaf = name[6:]
    return (0 < len(leaf) <= 255 and '/' not in leaf and '\\' not in leaf
            and leaf not in {'.', '..'} and '\x00' not in leaf
            and Path(leaf).suffix.lower() in {'.png','.jpg','.jpeg','.gif','.webp','.mp4','.mov','.webm'})


def _validate(files, include_media):
    from protection import AccountCipher
    if not REQUIRED.issubset(files) or len(files) > MAX_FILES or any(not _allowed(n) for n in files):
        raise ValueError('incomplete or unsafe snapshot paths')
    if sum(len(v) for v in files.values()) > LIMIT:
        raise ValueError('snapshot size limit exceeded')
    accounts = operator_cipher().decode(_json(files['accounts.json']))
    users = _json(files['users.json'])
    tasks = _json(files['tasks.json'])
    media = _json(files['media-index.json'])
    if not isinstance(users, list) or not all(isinstance(u, dict) and isinstance(u.get('id'), str) and u['id'] for u in users):
        raise ValueError('invalid users metadata')
    ids = [u['id'] for u in users]
    if len(ids) != len(set(ids)) or 'admin' in ids:
        raise ValueError('duplicate or reserved owner')
    owners = set(ids) | {'admin'}
    if not isinstance(tasks, dict) or not isinstance(media, dict):
        raise ValueError('invalid ownership index')
    for row in list(accounts) + list(tasks.values()) + list(media.values()):
        if not isinstance(row, dict) or row.get('owner_id') not in owners:
            raise ValueError('unknown or missing owner')
    if files['media-index.json.ownership-migrated'] != b'1\n':
        raise ValueError('invalid migration guard')
    if any(not _allowed('media/' + name) for name in media):
        raise ValueError('invalid media index name')
    actual = {n[6:] for n in files if n.startswith('media/')}
    if (include_media and actual != set(media)) or (not include_media and actual):
        raise ValueError('media payload/index mismatch')


def _packet(files, include_media):
    import base64
    import hashlib
    _validate(files, include_media)
    return {'schema': 1, 'include_media': include_media,
            'files': [{'path': name, 'size': len(raw), 'sha256': hashlib.sha256(raw).hexdigest(),
                       'data': base64.b64encode(raw).decode('ascii')} for name, raw in sorted(files.items())]}


def _unpack(packet):
    import base64
    import hashlib
    if not isinstance(packet, dict) or set(packet) != {'schema','include_media','files'} or packet['schema'] != 1 or type(packet['include_media']) is not bool:
        raise ValueError('unsupported snapshot schema')
    rows = packet['files']
    if not isinstance(rows, list) or len(rows) > MAX_FILES:
        raise ValueError('snapshot count limit exceeded')
    files = {}
    total = 0
    for row in rows:
        if not isinstance(row, dict) or set(row) != {'path','size','sha256','data'}:
            raise ValueError('invalid manifest entry')
        name = row['path']
        if not isinstance(name, str) or not _allowed(name) or name in files:
            raise ValueError('unsafe or duplicate path')
        if type(row['size']) is not int or not 0 <= row['size'] <= LIMIT or not isinstance(row['data'], str):
            raise ValueError('invalid entry size')
        raw = base64.b64decode(row['data'], validate=True)
        total += len(raw)
        if total > LIMIT or len(raw) != row['size'] or hashlib.sha256(raw).hexdigest() != row['sha256']:
            raise ValueError('snapshot size or digest mismatch')
        files[name] = raw
    _validate(files, packet['include_media'])
    return files


def _secure_parent(fd):
    info = os.fstat(fd)
    if info.st_uid != os.getuid() or info.st_mode & 0o077:
        raise ValueError('output parent must be owner-only')


def backup(directory, archive, include_media=False, apply=False):
    directory, archive = Path(directory), Path(archive)
    if not apply:
        return {'action':'preview', 'schema':1, 'include_media':include_media,
                'remediation':'Stop runtime, select an owner-only external output parent; --apply reads selected data only.'}
    with runtime_lock(directory) as source, directory_fd(archive.parent) as parent:
        _secure_parent(source)
        _secure_parent(parent)
        key_path = os.environ.get('MUSE2API_COOKIE_KEY_FILE', '')
        if key_path and os.path.commonpath([os.path.abspath(directory), os.path.abspath(key_path)]) == os.path.abspath(directory):
            raise ValueError('external key must be outside selected source data')
        operator_cipher()
        # No output within source tree; no key or arbitrary paths can enter this allowlist.
        if os.path.commonpath([os.path.abspath(directory), os.path.abspath(archive)]) == os.path.abspath(directory):
            raise ValueError('output must be outside source data')
        files = {}
        for name in sorted(REQUIRED):
            files[name] = _read_at(source, name)
        if include_media:
            mediafd = os.open('media', os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=source)
            try:
                names = os.listdir(mediafd)
                if len(names) + len(files) > MAX_FILES:
                    raise ValueError('snapshot count limit exceeded')
                for leaf in names:
                    name = 'media/' + leaf
                    if not _allowed(name):
                        raise ValueError('unexpected media entry')
                    files[name] = _read_at(mediafd, leaf)
                    if sum(map(len, files.values())) > LIMIT:
                        raise ValueError('snapshot size limit exceeded')
            finally:
                os.close(mediafd)
        packet = _packet(files, include_media)
        encrypted = operator_cipher().cipher.encrypt(json.dumps(packet, separators=(',',':')).encode())
        # Publish through hard-link no-clobber; temporary file is encrypted from first byte.
        tmp = '.backup-' + __import__('uuid').uuid4().hex
        fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=parent)
        try:
            with os.fdopen(fd, 'wb') as handle:
                handle.write(encrypted)
                handle.flush()
                os.fsync(handle.fileno())
            os.link(tmp, archive.name, src_dir_fd=parent, dst_dir_fd=parent, follow_symlinks=False)
            os.fsync(parent)
        finally:
            os.unlink(tmp, dir_fd=parent)
    return {'action':'created', 'schema':1, 'files':len(files), 'include_media':include_media}


def _load(archive):
    from protection import AccountCipher
    from cryptography.fernet import InvalidToken
    # Uncompressed encrypted JSON, not ZIP/TAR: no archive link types or compression bombs.
    raw = read_file(archive, LIMIT * 2)
    try:
        packet = _json(operator_cipher().cipher.decrypt(raw))
        files = _unpack(packet)
        return packet, files
    except (InvalidToken, ValueError, TypeError, KeyError, AttributeError, UnicodeError):
        raise ValueError('snapshot authentication or validation failed; restore matching key and intact backup') from None


def verify(archive):
    packet, files = _load(archive)
    return {'action':'verified', 'schema':1, 'files':len(files), 'bytes':sum(map(len,files.values())),
            'include_media':packet['include_media']}


def _rename_new(parent, source, target):
    import ctypes
    import sys
    libc = ctypes.CDLL(None, use_errno=True)
    if sys.platform == 'darwin':
        fn = libc.renameatx_np
        fn.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint]
        result = fn(parent, os.fsencode(source), parent, os.fsencode(target), 4)  # RENAME_EXCL
    elif sys.platform.startswith('linux') and hasattr(libc, 'renameat2'):
        fn = libc.renameat2
        fn.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint]
        result = fn(parent, os.fsencode(source), parent, os.fsencode(target), 1)  # RENAME_NOREPLACE
    else:
        raise ValueError('atomic no-replace directory publication unavailable')
    if result:
        raise OSError(ctypes.get_errno(), 'isolated destination publication failed')


def restore(archive, destination, apply=False):
    packet, files = _load(archive)
    destination = Path(destination)
    if not destination.name or destination.name in {'.','..'}:
        raise ValueError('select a new isolated destination')
    with directory_fd(destination.parent) as parent:
        _secure_parent(parent)
        try:
            os.stat(destination.name, dir_fd=parent, follow_symlinks=False)
        except FileNotFoundError:
            pass
        else:
            raise FileExistsError('destination must not exist')
        if not apply:
            return {'action':'preview', 'schema':1, 'files':len(files), 'include_media':packet['include_media']}
        stage = '.restore-' + __import__('uuid').uuid4().hex
        os.mkdir(stage, 0o700, dir_fd=parent)
        stagefd = os.open(stage, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=parent)
        published = False
        try:
            os.mkdir('media', 0o700, dir_fd=stagefd)
            mediafd = os.open('media', os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=stagefd)
            try:
                for name, raw in files.items():
                    targetfd = mediafd if name.startswith('media/') else stagefd
                    fd = os.open(name.split('/')[-1], os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=targetfd)
                    with os.fdopen(fd, 'wb') as handle:
                        handle.write(raw)
                        handle.flush()
                        os.fsync(handle.fileno())
                fd = os.open('.tenant-runtime.lock', os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600, dir_fd=stagefd)
                os.close(fd)
                os.fsync(mediafd)
                os.fsync(stagefd)
                _rename_new(parent, stage, destination.name)
                published = True
                os.fsync(parent)
            finally:
                os.close(mediafd)
        finally:
            os.close(stagefd)
            if not published:
                # Only our unpredictable private staging name; no recursive following.
                shutil.rmtree(stage, dir_fd=parent)
    return {'action':'restored', 'schema':1, 'files':len(files), 'include_media':packet['include_media']}



@contextmanager
def directory_fd(path):
    fd = os.open('/', os.O_RDONLY | os.O_DIRECTORY)
    try:
        for part in Path(os.path.abspath(path)).parts[1:]:
            child = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=fd)
            os.close(fd)
            fd = child
        yield fd
    finally:
        os.close(fd)


def _read_at(parent, name, limit=LIMIT):
    fd = os.open(name, os.O_RDONLY | os.O_NONBLOCK | os.O_NOFOLLOW, dir_fd=parent)
    with os.fdopen(fd, 'rb') as handle:
        info = os.fstat(handle.fileno())
        if not stat.S_ISREG(info.st_mode) or info.st_size > limit or info.st_nlink != 1:
            raise ValueError('unsafe file or size limit exceeded')
        value = handle.read(limit + 1)
        if len(value) > limit:
            raise ValueError('size limit exceeded')
        return value


def read_file(path, limit=LIMIT):
    path = Path(path)
    with directory_fd(path.parent) as parent:
        return _read_at(parent, path.name, limit)


@contextmanager
def runtime_lock(directory):
    # Existing sentinel only: never create/replace a lock and split its identity.
    with directory_fd(directory) as parent:
        fd = os.open('.tenant-runtime.lock', os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=parent)
        try:
            if not stat.S_ISREG(os.fstat(fd).st_mode):
                raise ValueError('unsafe runtime lock')
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            yield parent
        finally:
            os.close(fd)


def preflight(directory, min_free=1024**3, inspect_accounts=False):
    checks = []
    def add(name, status, remedy):
        checks.append(dict(name=name, status=status, remediation=remedy))
    try:
        if not isinstance(min_free, int) or min_free < 0:
            raise ValueError()
        with directory_fd(directory) as fd:
            info = os.fstat(fd)
            if info.st_uid != os.getuid() or info.st_mode & 0o077:
                raise ValueError()
        add('directory', 'pass', 'Keep data directory owner-only and without symlinks.')
    except (OSError, ValueError):
        add('directory', 'block', 'Select an existing owner-only data directory without symlink components.')
    try:
        from protection import AccountCipher
        operator_cipher()
        add('key', 'pass', 'Escrow the matching external key separately.')
    except (OSError, ValueError, ImportError):
        add('key', 'block', 'Provision exactly one valid external Fernet key; key file must be owner-only.')
    try:
        if shutil.disk_usage(directory).free < min_free or min_free < 0:
            raise ValueError()
        add('disk', 'pass', 'Monitor downloads/profiles separately; this is a point-in-time check.')
    except (OSError, ValueError):
        add('disk', 'block', 'Free disk space or explicitly choose an appropriate nonnegative byte threshold.')
    add('admin_config', 'pass' if os.environ.get('MUSE2API_KEY', '').strip() else 'block',
        'Inject administrator authentication configuration explicitly. This tool deliberately never loads .env files.')
    workers = [os.environ.get(k, '1') for k in ('WEB_CONCURRENCY', 'UVICORN_WORKERS', 'MUSE2API_WORKERS')]
    add('workers', 'pass' if all(w == '1' for w in workers) else 'block',
        'Use one worker and one replica; inspect the actual launch command separately.')
    try:
        with runtime_lock(directory):
            pass
        add('runtime_lock', 'pass', 'Availability is momentary, not permission to start another runtime.')
    except (OSError, ValueError):
        add('runtime_lock', 'block', 'Stop runtime; an existing safe runtime lock sentinel is required. Never delete a busy sentinel.')
    missing = [m for m in ('cryptography', 'fastapi', 'uvicorn', 'requests') if importlib.util.find_spec(m) is None]
    add('dependencies', 'block' if missing else 'pass', 'Install the pinned backend requirements in its environment.')
    if not inspect_accounts:
        add('accounts', 'warn', 'Not read. Explicit --inspect-accounts authenticates data and detects legacy migration needs.')
    else:
        try:
            value = json.loads(read_file(Path(directory) / 'accounts.json'))
            if isinstance(value, list):
                add('accounts', 'block', 'Legacy plaintext detected. Stop runtime and use explicit backed-up offline migration.')
            else:
                from protection import AccountCipher
                operator_cipher().decode(value)
                add('accounts', 'pass', 'Ciphertext authenticates with configured key; no upstream session validation performed.')
        except (OSError, ValueError, TypeError):
            add('accounts', 'block', 'Missing/corrupt accounts or key mismatch. Restore the matching protected snapshot and key.')
    add('deployment', 'warn', 'No browser, upstream, command-line worker, replica, TLS or reverse-proxy validation is performed.')
    return dict(schema=1, checks=checks, exit_code=2 if any(c['status'] == 'block' for c in checks) else 1 if any(c['status'] == 'warn' for c in checks) else 0)
