"""Offline explicit migration. Stop service and verify a protected backup first."""
import argparse
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from protection import migrate_accounts


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('accounts_file')
    parser.add_argument('--confirm-backup', action='store_true', required=True)
    args = parser.parse_args()
    try:
        changed = migrate_accounts(args.accounts_file)
    except Exception:
        # No exception strings, input paths or key material in command output.
        print('Migration failed; keep service stopped and recover matching backup/key.', file=sys.stderr)
        return 1
    print('Migration completed.' if changed else 'Already encrypted; authentication verified.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
