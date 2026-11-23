"""Non-root review image startup: metadata checks only, no credential reads/copies."""
import os
from pathlib import Path
import stat
import sys


def check_directory(path):
    metadata=path.lstat()
    if (not stat.S_ISDIR(metadata.st_mode) or metadata.st_uid!=10001
            or metadata.st_gid!=10001 or stat.S_IMODE(metadata.st_mode)!=0o700):
        raise ValueError('Unprepared runtime directory')


def check_runtime(root=Path('/runtime'),ipc=Path('/run/muse-pot')):
    if os.getuid()!=10001 or os.getgid()!=10001:
        raise ValueError('Non-root API requires UID/GID10001')
    for path in (root,root/'data',root/'profiles',ipc):check_directory(path)
    metadata=(root/'.env').lstat()
    if (not stat.S_ISREG(metadata.st_mode) or metadata.st_uid!=10001
            or metadata.st_gid!=10001 or stat.S_IMODE(metadata.st_mode)!=0o600
            or not 0<metadata.st_size<=1024*1024):
        raise ValueError('Prepared runtime config is required')


def main():
    try:
        expected={'HOME':'/runtime','MUSE2API_HOME':'/runtime',
                  'MUSE2API_PROFILE_ROOT':'/runtime/profiles'}
        if any(os.environ.get(key)!=value for key,value in expected.items()):
            raise ValueError('Runtime paths must match the prepared mounts')
        check_runtime()
        if not sys.argv[1:]:raise ValueError('Missing application command')
    except (OSError,ValueError):
        raise SystemExit('Non-root runtime is not prepared; refusing automatic initialization') from None
    os.umask(0o077)
    os.execvp(sys.argv[1],sys.argv[1:])

if __name__=='__main__':main()
