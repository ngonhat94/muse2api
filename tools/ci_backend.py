#!/usr/bin/env python3
"""Run explicitly inventoried backend regressions in isolated guarded processes.

No server startup, browser install or live Muse access. Unknown tests fail the
inventory gate until classified; failures/timeouts are never converted to skips.
"""
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
EXCLUDED = {
    'test_socks_proxy.py': 'Real local socket proxy fixtures; incompatible with deny-all bind/connect guard.',
    'test_admin_layout.py': 'Real Chromium and local HTTP fixture.',
    'test_composer_send_browser.py': 'Real Chromium and local HTTP fixture.',
    'test_reference_upload_browser.py': 'Real Chromium and local HTTP fixture.',
    'test_media_selection.py': 'Real Chromium/CDP fixture.',
    'test_muse_video_delivery.py': 'Real Chromium/CDP fixture.',
}
CASES = tuple((name, args) for name, args in (
    ('test_ci_backend.py', ()),
    ('test_account_proxy.py', ('--offline',)),
    ('test_account_proxy_routing.py', ()),
    ('test_admin_base_url.py', ()),
    ('test_async_images.py', ()),
    ('test_browser_context_downloads.py', ()),
    ('test_concurrency.py', ()),
    ('test_cookie_requirements.py', ()),
    ('test_data_protection.py', ()),
    ('test_desktop_build.py', ()),
    ('test_desktop_install.py', ()),
    ('test_desktop_launcher.py', ()),
    ('test_extension_upgrade_notice.py', ()),
    ('test_extension_zip.py', ()),
    ('test_generation_idempotency.py', ()),
    ('test_idempotency_acceptance.py', ()),
    ('test_keepalive_scheduling.py', ()),
    ('test_local_update_safety.py', ()),
    ('test_media_boundary.py', ()),
    ('test_media_delete.py', ()),
    ('test_multitenant_security.py', ()),
    ('test_operational_dashboard.py', ()),
    ('test_operations.py', ()),
    ('test_protection_review_fixes.py', ()),
    ('test_proxy_status_receipt.py', ('--backend-only',)),
    ('test_proxy_url_import.py', ()),
    ('test_quota_account_binding.py', ()),
    ('test_quota_localization.py', ()),
    ('test_ref_image_safety.py', ()),
    ('test_reference_admission.py', ()),
    ('test_reference_limits.py', ()),
    ('test_reference_media.py', ()),
    ('test_reference_media_hardening.py', ()),
    ('test_refusal_rotation.py', ()),
    ('test_session_health.py', ()),
    ('test_session_only_import.py', ()),
    ('test_tenant_review_blockers.py', ()),
    ('test_video_late_attachment.py', ()),
    ('test_vm_wait.py', ('engine.py', '--assert')),
    ('test_wake_confirmation.py', ()),
))


def main():
    selected = {name for name, _ in CASES}
    actual = {p.name for p in (ROOT/'tests').glob('test_*.py')}
    if selected & set(EXCLUDED) or actual != selected | set(EXCLUDED):
        raise RuntimeError(f'Unclassified/missing tests: {actual ^ (selected | set(EXCLUDED))}')
    scratch = os.environ.get('RUNNER_TEMP') or os.environ.get('MUSE2API_TEST_TMP') or os.environ.get('TMPDIR') or tempfile.gettempdir()
    scratch = str(Path(scratch).resolve())
    env = dict(os.environ, MUSE2API_TEST_TMP=scratch, TMPDIR=scratch, PYTHONDONTWRITEBYTECODE='1')
    for name, reason in EXCLUDED.items():
        print(f'EXCLUDED {name}: {reason}', flush=True)
    for name, args in CASES:
        print(f'RUN {name} {" ".join(args)}', flush=True)
        subprocess.run([sys.executable, str(ROOT/'tests/run_backend_offline.py'), f'tests/{name}', *args],
                       cwd=ROOT, env=env, check=True, timeout=120)
    print(f'PASS: {len(CASES)} guarded scripts; {len(EXCLUDED)} explicitly excluded.', flush=True)


if __name__ == '__main__':
    main()
