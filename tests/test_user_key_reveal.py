"""Synthetic API key escrow; no network or production state."""
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
from cryptography.fernet import Fernet
from tenant import UserStore


class KeyRevealTests(unittest.TestCase):
    def setUp(self):
        self.home = tempfile.TemporaryDirectory()
        self.addCleanup(self.home.cleanup)
        self.env = patch.dict(os.environ, {'MUSE2API_COOKIE_KEY': Fernet.generate_key().decode(),
                                          'MUSE2API_COOKIE_KEY_FILE': ''})
        self.env.start()
        self.addCleanup(self.env.stop)
        self.path = str(Path(self.home.name) / 'users.json')
        self.store = UserStore(self.path)

    def test_encrypted_persistence_reopens_and_public_never_leaks(self):
        user, raw = self.store.create('Fixture')
        self.assertEqual(UserStore(self.path).reveal(user['id']), raw)
        self.assertNotIn(raw, Path(self.path).read_text())
        self.assertNotIn('key_ciphertext', user)
        self.assertNotIn('key_hash', user)
        self.assertTrue(user['key_revealable'])
        self.assertNotIn('key_ciphertext', json.dumps(self.store.list()))
        self.assertNotIn(raw, json.dumps(self.store.list()))

    def test_legacy_rotation_and_revocation(self):
        user, old = self.store.create('Fixture')
        rows = json.loads(Path(self.path).read_text())
        rows[0].pop('key_ciphertext')
        Path(self.path).write_text(json.dumps(rows))
        self.assertIsNone(self.store.reveal(user['id']))
        self.assertFalse(self.store.list()[0]['key_revealable'])
        self.assertIsNotNone(self.store.authenticate(old))
        _, new = self.store.rotate(user['id'])
        self.assertEqual(self.store.reveal(user['id']), new)
        self.assertIsNone(self.store.authenticate(old))
        self.store.revoke(user['id'])
        self.assertIsNone(self.store.reveal(user['id']))
        self.assertNotIn('key_ciphertext', Path(self.path).read_text())

    def test_ciphertext_tamper_swap_and_wrong_key_fail_closed(self):
        a, _ = self.store.create('A')
        b, _ = self.store.create('B')
        rows = json.loads(Path(self.path).read_text())
        rows[0]['key_ciphertext'] = rows[1]['key_ciphertext']
        Path(self.path).write_text(json.dumps(rows))
        with self.assertRaises(ValueError):
            self.store.reveal(a['id'])
        with patch.dict(os.environ, {'MUSE2API_COOKIE_KEY': Fernet.generate_key().decode()}):
            with self.assertRaises(ValueError):
                self.store.reveal(b['id'])

    def test_missing_encryption_key_does_not_write_plaintext(self):
        with patch.dict(os.environ, {'MUSE2API_COOKIE_KEY': ''}):
            with self.assertRaises(ValueError):
                self.store.create('A')
        self.assertFalse(Path(self.path).exists())


if __name__ == '__main__':
    unittest.main()
