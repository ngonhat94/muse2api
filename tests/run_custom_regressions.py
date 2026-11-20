"""Manual offline custom regressions; no CI/CD or deployment actions."""
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]

if __name__ == '__main__':
    cases = json.loads((ROOT/'tests/custom_cases.json').read_text())
    for name, args in cases:
        print(f'RUN {name}', flush=True)
        subprocess.run([sys.executable, str(ROOT/'tests/run_backend_offline.py'),
                        f'tests/{name}', *args], cwd=ROOT,
                       env=dict(os.environ, PYTHONDONTWRITEBYTECODE='1'),
                       check=True, timeout=120)
    print(f'PASS: {len(cases)} guarded backend scripts')
