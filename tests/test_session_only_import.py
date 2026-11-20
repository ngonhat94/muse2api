"""Importer accepts a session-only cookie; live auth still decides validity."""
import os
import sys
import tempfile
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
with tempfile.TemporaryDirectory() as home:
    os.environ.update(MUSE2API_HOME=home, MUSE2API_PROFILE_ROOT=home,
                      MUSE2API_KEY='test-only')
    import app

    result = app.add_account(app.AccountRequest(cookies={'hatch_sess': 'fixture'}))
    assert result['essential_missing'] == [] and result['warning'] == ''
    aid = result['added'][0]['id']
    account = app.store.get_account(aid)
    assert account is not None and account['ok'] is None
    assert app.store.list_accounts()[0]['essential_ok']

    # Match the actual probe/renewal boundary. The strict runner forbids real
    # renewal; test_session_health.py separately exercises HTTP parsing with fakes.
    # Renewal raises on 401/unassigned rather than returning ok=False.
    outcomes = [
        {'ok': True, 'cookies': {'hatch_sess': 'fixture'},
         'cookies_exp': {}, 'vm_state': 'RUNNING'},
        app.MuseAuthError('synthetic HTTP 401'),
        app.MuseGenerationError('synthetic unassigned session'),
    ]
    for outcome in outcomes:
        with patch.object(app.engine, 'renew_session_http') as renew:
            if isinstance(outcome, Exception):
                renew.side_effect = outcome
            else:
                renew.return_value = outcome
            probe = app._probe_account_sync(aid)
        renew.assert_called_once_with({'hatch_sess': 'fixture'}, {}, wake_vm=True)
        assert probe['ok'] is (not isinstance(outcome, Exception))
        account = app.store.get_account(aid)
        assert account is not None
        if isinstance(outcome, app.MuseAuthError):
            assert account['ok'] is False
        elif isinstance(outcome, app.MuseGenerationError):
            assert account['ok'] is False  # ambiguous health preserves prior 401
        else:
            assert account['ok'] is True
    print('PASS: session-only import, unknown initial health, assigned accepted, '
          '401 rejected, unavailable not accepted')
