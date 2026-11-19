#!/usr/bin/env python3
import io
import json
from pathlib import Path
import sys
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import app


def main():
    source_root = Path(app.BASE_DIR) / "extension"
    source_names = {
        path.relative_to(source_root).as_posix()
        for path in source_root.rglob("*")
        if path.is_file()
    }
    response = app.extension_zip()
    with zipfile.ZipFile(io.BytesIO(response.body)) as archive:
        names = archive.namelist()
        expected_names = {f"muse2api-extension/{name}" for name in source_names}
        assert set(names) == expected_names, (
            f"extension archive mismatch: missing={sorted(expected_names - set(names))}, "
            f"extra={sorted(set(names) - expected_names)}"
        )
        assert len(names) == len(set(names)), "extension archive contains duplicate entries"
        assert all("\\" not in name for name in names), "ZIP paths must be portable"
        manifest = json.loads(archive.read("muse2api-extension/manifest.json"))
        assert manifest["version"] == "1.1.1"
        expected_origins = ['https://muapp-3d6.pages.dev', 'https://muse.dntrip.xyz']
        assert manifest['externally_connectable']['matches'] == [o + '/*' for o in expected_origins]
        assert all(o + '/*' in manifest['host_permissions'] for o in expected_origins)
        assert archive.read('muse2api-extension/import_policy.js') == (source_root / 'import_policy.js').read_bytes()
        assert manifest['key'] == json.loads((source_root / 'manifest.json').read_text())['key']
        assert manifest["name"] == "__MSG_extName__"
        for locale in ("en", "zh_CN"):
            messages = json.loads(archive.read(
                f"muse2api-extension/_locales/{locale}/messages.json"
            ))
            assert messages["extName"]["message"]
            assert messages["extDesc"]["message"]
    assert app.extension_files()["files"] == sorted(source_names)
    print("PASS: extension ZIP and file list exactly match the full source tree")


if __name__ == "__main__":
    main()
