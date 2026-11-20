from pathlib import Path
import json
root=Path(__file__).resolve().parents[1]
v=json.loads((root/'version.json').read_text())
m=json.loads((root/'extension/manifest.json').read_text())
assert m['version']=='1.1.1'
# Latest upstream release notes remain intact; extension guidance lives separately.
assert v['version'] == '1.6.12'
assert v['highlights'] and v['highlights_en']
guide = (root/'docs/BROWSER_ACCOUNT_IMPORT.md').read_text()
assert m['version'] in (root/'docs/BROWSER_ACCOUNT_IMPORT.md').read_text()
assert f"v{m['version']}" in (root/'extension/popup.html').read_text()
assert 'cùng browser profile' in guide and 'Reload' in guide
html=(root/'admin.html').read_text()
assert 'id="extensionUpgradeNotice"' in html and '"extension-upgrade-notice":' in html
assert 'href="/admin/extension"' in html
assert "releases/download/" not in html.split('id="extensionUpgradeNotice"', 1)[1].split('</div>', 1)[0]
assert 'id="extensionVersion"' in (root/'extension/popup.html').read_text()
assert '@version      1.1.2' in (root/'tools/muse2api_cookie_importer.user.js').read_text()
print('PASS: bilingual upgrade notice, version badge, release instructions and download link')
