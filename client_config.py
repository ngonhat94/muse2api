"""Public connection directory; never stores or proxies credentials."""
import json
import os
import re
from urllib.parse import urlsplit

from tenant import _write

DEFAULT_SERVER_URL = 'https://18610-agq6gp235jkrlip6hyszdk5ctm.instabox.tech'


def validate_server_url(value):
    if not isinstance(value, str) or len(value) > 2048 or re.search(r'[\s\\\x00-\x1f\x7f]', value):
        raise ValueError('Expected a public HTTPS server URL')
    try:
        url = urlsplit(value)
        if (url.scheme != 'https' or not url.hostname or url.username is not None
                or url.password is not None or '?' in value or '#' in value
                or not re.fullmatch(r'[A-Za-z0-9.-]+', url.hostname)
                or url.port == 0 or '%' in url.path
                or any(part in ('.', '..') for part in url.path.split('/'))
                or url.path.rstrip('/').endswith('/v1')):
            raise ValueError()
    except ValueError:
        raise ValueError('Expected a public HTTPS server URL without credentials, query or fragment') from None
    return value.rstrip('/')


class ClientConfigStore:
    def __init__(self, path):
        self.path = path

    def read(self):
        try:
            with open(self.path, encoding='utf-8') as handle:
                value = json.load(handle)
            address = validate_server_url(value['server_url'])
        except (OSError, ValueError, KeyError, TypeError):
            address = DEFAULT_SERVER_URL
        return {'server_url': address}

    def save(self, address):
        value = {'server_url': validate_server_url(address)}
        _write(self.path, value)
        return value
