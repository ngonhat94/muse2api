"""Synthetic A/B/admin isolation checks; never contacts Muse or a real browser."""
from __future__ import annotations

import asyncio
import importlib.util
import json
import os
from pathlib import Path
import sys
import tempfile
from unittest.mock import patch
from urllib.parse import urlsplit


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "app.py"
sys.path.insert(0, str(ROOT))


class Response:
    def __init__(self, status: int, body: bytes):
        self.status_code = status
        self.body = body

    def json(self):
        return json.loads(self.body) if self.body else {}


class Client:
    def __init__(self, app, key: str):
        self.app = app
        self.key = key

    async def request(self, method: str, path: str, payload=None):
        parsed = urlsplit(path)
        body = json.dumps(payload).encode() if payload is not None else b""
        headers = {
            "authorization": f"Bearer {self.key}",
            "content-length": str(len(body)),
        }
        if payload is not None:
            headers["content-type"] = "application/json"
        scope = {
            "type": "http", "asgi": {"version": "3.0"}, "http_version": "1.1",
            "method": method, "scheme": "http", "path": parsed.path,
            "raw_path": parsed.path.encode(), "query_string": parsed.query.encode(),
            "root_path": "", "headers": [(k.encode(), v.encode()) for k, v in headers.items()],
            "server": ("test", 80), "client": ("fixture", 1),
        }
        messages = []
        sent = False

        async def receive():
            nonlocal sent
            if not sent:
                sent = True
                return {"type": "http.request", "body": body, "more_body": False}
            await asyncio.Event().wait()

        async def send(message):
            messages.append(message)

        await self.app(scope, receive, send)
        status = next(m["status"] for m in messages if m["type"] == "http.response.start")
        content = b"".join(m.get("body", b"") for m in messages)
        return Response(status, content)


async def main():
    scratch = os.environ.get("MUSE2API_TEST_TMP") or str(ROOT / ".test-tmp")
    with tempfile.TemporaryDirectory(prefix="multitenant-", dir=scratch) as home:
        os.environ["MUSE2API_HOME"] = home
        os.environ["MUSE2API_KEY"] = "legacy-admin-key"
        data = Path(home) / "data"
        data.mkdir(parents=True)
        (data / "accounts.json").write_text(json.dumps([{
            "id": "legacy-account", "label": "Legacy", "cookies": {"hatch_sess": "legacy"},
            "enabled": True,
        }]))
        (data / "tasks.json").write_text(json.dumps({"legacy-task": {
            "id": "legacy-task", "kind": "image", "prompt": "legacy", "status": "failed",
            "created_at": 1,
        }}))
        from protection import migrate_accounts
        migrate_accounts(str(data / 'accounts.json'))
        spec = importlib.util.spec_from_file_location("multitenant_candidate", SOURCE)
        module = importlib.util.module_from_spec(spec)
        sys.modules[spec.name] = module
        spec.loader.exec_module(module)

        admin = Client(module.app, "legacy-admin-key")
        created_a = await admin.request("POST", "/admin/users", {"label": "Tenant A"})
        created_b = await admin.request("POST", "/admin/users", {"label": "Tenant B"})
        assert created_a.status_code == created_b.status_code == 201
        user_a, key_a = created_a.json()["user"], created_a.json()["api_key"]
        user_b, key_b = created_b.json()["user"], created_b.json()["api_key"]
        assert key_a.startswith("m2u_") and key_a not in Path(module.CFG.users_file).read_text()
        assert key_b not in Path(module.CFG.users_file).read_text()

        a, b = Client(module.app, key_a), Client(module.app, key_b)
        assert (await a.request("GET", "/v1/me")).json()["role"] == "user"
        assert (await admin.request("GET", "/v1/me")).json()["role"] == "admin"
        assert "browser_running" not in (await a.request("GET", "/readyz")).json()
        assert "browser_running" in (await admin.request("GET", "/readyz")).json()
        assert (await Client(module.app, "unknown").request("GET", "/v1/me")).status_code == 401
        assert "legacy-account" in {
            item["id"] for item in (await admin.request("GET", "/admin/accounts")).json()["accounts"]
        }

        add_a = await a.request("POST", "/admin/accounts", {"label": "A", "cookie_header": "hatch_sess=a"})
        add_b = await b.request("POST", "/admin/accounts", {"label": "B", "cookie_header": "hatch_sess=b"})
        aid_a, aid_b = add_a.json()["added"][0]["id"], add_b.json()["added"][0]["id"]
        assert {x["id"] for x in (await a.request("GET", "/admin/accounts")).json()["accounts"]} == {aid_a}
        assert {x["id"] for x in (await b.request("GET", "/admin/accounts")).json()["accounts"]} == {aid_b}
        assert (await a.request("PATCH", f"/admin/accounts/{aid_b}", {"label": "stolen"})).status_code == 404
        assert (await a.request("POST", f"/admin/accounts/{aid_b}/cookies", {
            "cookie_header": "hatch_sess=stolen",
        })).status_code == 404
        assert (await a.request("POST", f"/admin/accounts/{aid_b}/quota")).status_code == 404
        assert (await a.request("POST", f"/admin/accounts/{aid_b}/test")).status_code == 404
        assert (await a.request("DELETE", f"/admin/accounts/{aid_b}")).status_code == 404
        cross_keepalive = await a.request("POST", f"/admin/accounts/{aid_b}/keepalive")
        assert cross_keepalive.status_code == 200 and cross_keepalive.json()["ok"] is False
        assert module.store.pick_account(owner_id=user_a["id"])["id"] == aid_a
        module.store.update_account(aid_a, enabled=False, owner_id=user_a["id"])
        assert module.store.pick_account(owner_id=user_a["id"]) is None
        assert module.store.pick_account(owner_id=user_b["id"])["id"] == aid_b

        task_a = module.store.create_task("image", "A prompt", owner_id=user_a["id"])
        task_b = module.store.create_task("video", "B prompt", owner_id=user_b["id"])
        assert [x["id"] for x in (await a.request("GET", "/admin/tasks")).json()["tasks"]] == [task_a["id"]]
        assert (await a.request("GET", f"/v1/videos/{task_b['id']}")).status_code == 404
        assert (await a.request("DELETE", f"/admin/tasks/{task_b['id']}")).status_code == 404
        for route in (
            f"/admin/tasks/{task_b['id']}/cancel",
            f"/v1/images/tasks/{task_b['id']}/cancel",
            f"/v1/videos/{task_b['id']}/cancel",
            f"/v1/videos/generations/{task_b['id']}/cancel",
        ):
            assert (await a.request("POST", route)).status_code == 404
        cancelled = await a.request("POST", f"/admin/tasks/{task_a['id']}/cancel")
        assert cancelled.status_code == 200 and cancelled.json()["cancelled"] is True

        media_dir = Path(module.CFG.media_dir)
        (media_dir / "a.webp").write_bytes(b"A")
        (media_dir / "b.webp").write_bytes(b"B")
        module.store.register_media("a.webp", user_a["id"])
        module.store.register_media("b.webp", user_b["id"])
        media_a = (await a.request("GET", "/admin/media")).json()["media"]
        assert [item["name"] for item in media_a] == ["a.webp"]
        protected_url = media_a[0]["url"]
        assert "legacy-admin-key" not in protected_url and key_a not in protected_url
        assert (await a.request("GET", "/v1/media/a.webp")).status_code == 401
        assert (await Client(module.app, "unused").request("GET", protected_url)).body == b"A"
        with patch.object(module.time, "time", return_value=module.time.time() + 301):
            assert (await Client(module.app, "unused").request("GET", protected_url)).status_code == 401
        cross_cap = protected_url.replace("a.webp", "b.webp")
        assert (await Client(module.app, "unused").request("GET", cross_cap)).status_code in (401, 403, 404)
        denied_delete = await a.request("POST", "/admin/media/delete", {"names": ["b.webp"]})
        assert denied_delete.json()["removed"] == 0 and (media_dir / "b.webp").is_file()
        assert (await a.request("DELETE", "/admin/media/b.webp")).status_code == 404
        assert (await a.request("GET", "/v1/media/../accounts.json?cap=x")).status_code in (400, 404)

        assert (await a.request("GET", "/admin/apikey")).status_code == 403
        assert (await a.request("POST", "/admin/apikey/rotate")).status_code == 403
        assert (await a.request("GET", "/admin/repo/status")).status_code == 403
        assert (await a.request("POST", "/admin/update/upgrade", {"restart": False})).status_code == 403

        protected_b = (await b.request("GET", "/admin/media")).json()["media"][0]["url"]
        assert (await admin.request("PATCH", f"/admin/users/{user_b['id']}", {
            "enabled": False,
        })).status_code == 200
        assert (await b.request("GET", "/v1/me")).status_code == 401
        assert (await Client(module.app, "unused").request("GET", protected_b)).status_code == 401
        assert (await admin.request("PATCH", f"/admin/users/{user_b['id']}", {
            "enabled": True,
        })).status_code == 200
        assert (await b.request("GET", "/v1/me")).status_code == 200
        rotated_b = await admin.request("POST", f"/admin/users/{user_b['id']}/key")
        assert rotated_b.status_code == 200
        new_key_b = rotated_b.json()["api_key"]
        assert new_key_b not in Path(module.CFG.users_file).read_text()
        assert (await b.request("GET", "/v1/me")).status_code == 401
        assert (await Client(module.app, new_key_b).request("GET", "/v1/me")).status_code == 200

        assert (await admin.request("DELETE", f"/admin/users/{user_a['id']}/key")).status_code == 200
        assert (await a.request("GET", "/v1/me")).status_code == 401
        assert (await Client(module.app, "unused").request("GET", protected_url)).status_code == 401

        # Legacy records migrate once to the legacy admin, never to a newly created tenant.
        assert all(x.get("owner_id") for x in module.store.accounts)
        assert all(x.get("owner_id") for x in module.store.tasks.values())

    print("PASS: multitenant auth, isolation, aliases, media capability and revocation")


if __name__ == "__main__":
    asyncio.run(main())
