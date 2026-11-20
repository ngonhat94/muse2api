"""Explicit operator entry point; no application startup imports."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from operations import main

if __name__ == '__main__':
    raise SystemExit(main())
