"""Provision ONLY an explicitly new, empty review tree. No migration/secret copying.

Default prints a plan. --create requires root and a nonexistent dedicated path.
Never point at existing production runtime; no recursive chmod/chown/removal.
"""
import argparse
import json
import os
from pathlib import Path
import stat

UID = GID = 10001


def validate_root(path):
    path = Path(path).absolute()
    if '..' in path.parts:
        raise ValueError('Parent traversal is not allowed')
    if path.exists() or path.is_symlink():
        raise ValueError('Review root must not exist')
    if path.name in ('', '.', '..') or len(path.parts) < 4:
        raise ValueError('Use a dedicated new review path')
    for parent in path.parents:
        if parent.is_symlink():
            raise ValueError('Symlink parents are not allowed')
    if not path.parent.is_dir():
        raise ValueError('Review parent must already exist')
    return path


def create(path):
    path = validate_root(path)
    if os.getuid() != 0:
        raise ValueError('Creation requires root to set the dedicated identity')
    # Parent must be root-owned and not writable by others (prevents rename/symlink races).
    parent = path.parent.stat()
    if parent.st_uid != 0 or stat.S_IMODE(parent.st_mode) & 0o022:
        raise ValueError('Parent must be root-owned and not group/world-writable')
    path.mkdir(mode=0o700)  # Exclusive: never overwrite a raced existing root.
    for relative in ('runtime', 'runtime/data', 'runtime/profiles', 'ipc'):
        directory = path/relative
        directory.mkdir(mode=0o700)
        os.chown(directory, UID, GID)
    # Root-owned outer directory need only be traversed by the dedicated group.
    os.chown(path, 0, GID)
    path.chmod(0o710)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--create', action='store_true')
    args = parser.parse_args()
    try:
        path = validate_root(args.root)
        if args.create: create(path)
        print(json.dumps({'root':str(path),'uid':UID,'gid':GID,
                          'created':args.create,'copies_credentials':False}))
    except (OSError, ValueError):
        raise SystemExit('Review layout rejected; no existing tree is modified') from None


if __name__ == '__main__': main()
