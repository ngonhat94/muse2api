# Video projects MVP API

## Safe planning diagnostics and curl

Async `planning` and request receipts add nullable `error_code` and `error_stage`; the existing `error` string and status/stage enums remain compatible. New queued/successful plans have null diagnostic fields. Older records may omit them: absence means unavailable evidence, not a model-configuration diagnosis. Historical exceptions discarded by older workers cannot be reconstructed. Receipt snapshots retain diagnostics when a newer plan replaces the current one.

| error_code | error_stage | Meaning / next check |
| --- | --- | --- |
| `no_account` | `adapter` | Account selection found no eligible account; ask administrator to check availability. |
| `auth_failed` | `adapter` | Adapter authority/auth rejection (401/403); check session/account health. |
| `upstream_failed` | `adapter` | Known upstream failure or HTTP 429/502/503/504; check service health. |
| `upstream_failed` | `adapter_response` | Missing/invalid choices/message/content envelope, non-text content, or content over 64,000 characters. |
| `invalid_json` | `parse` | Text is not strict JSON; markdown fences are deliberately not normalized. |
| `invalid_schema` | `schema` | JSON is not a bounded unapproved script/scenes draft (including total duration and unique order). |
| `project_changed` | `apply` | Revision conflict; generated content was not applied. Refresh; human edits survive. |
| `unknown` | last observed stage | Unclassified exception; do not infer its cause. Restart uses the persisted milestone; thread-start interruption uses `admission`. |

`stage` remains the broad lifecycle milestone (`failed` on failure); `error_stage` identifies the last failing boundary. Diagnostics are categories, not proof of a specific underlying provider cause. Unexpected adapter exceptions remain `unknown` rather than guessing authentication/configuration. Pre-admission failures remain HTTP errors without creating a receipt; legacy revision-only POST retains its existing synchronous safe error contract.

Server logger `video_projects` emits one JSON `planning_failed` warning with project/request/job IDs, category, stage, exception class, numeric HTTP status when known, and fixed schema location `draft` for schema rejection. It never includes exception text/traceback, Pydantic input or arbitrary schema keys, prompts, raw model output, keys or cookies. Do not enable verbose curl or shell tracing with real credentials. Do not paste credentials or full project text into support logs.

Read-only diagnosis (Bash; requires `curl` and Python 3). Set these values privately in your shell; placeholders below are not real credentials or user IDs. Use a trusted HTTPS API URL with no trailing slash, query, or fragment. Curl receives the bearer header through stdin, not its process arguments:

```bash
MUSE_URL='https://your-trusted-api.example'
read -rsp 'API key: ' MUSE_API_KEY; printf '\n'
PROJECT_ID='your-project-id'
REQUEST_ID='your-existing-request-uuid'
: "${MUSE_URL:?}" "${MUSE_API_KEY:?}" "${PROJECT_ID:?}" "${REQUEST_ID:?}"

muse_get() {
  printf 'Authorization: Bearer %s\n' "$MUSE_API_KEY" |
    curl --fail-with-body --silent --show-error --max-time 30 \
      --proto '=https' --header @- "$MUSE_URL$1"
}

# Existing project: print only revision and planning diagnostics, not idea/script.
muse_get "/v1/video-projects/$PROJECT_ID" |
  python3 -c 'import json,sys; p=json.load(sys.stdin); q=p.get("planning") or {}; print(json.dumps({"revision":p.get("revision"),"planning":{k:q.get(k) for k in ("id","request_id","status","stage","error_code","error_stage","error")}},indent=2))'

# Exact owner/project-bound receipt: GET observes only; never submits work.
muse_get "/v1/video-projects/$PROJECT_ID/requests/$REQUEST_ID" |
  python3 -m json.tool
```

`not_found` is not retry authorization. Unknown/missing diagnostics on an old failed project cannot recover its lost exception. Share only the diagnostic subset and request ID with the administrator.

**Optional manual action — NOT diagnosis:** the following POST can incur model usage. Run only after explicitly deciding to authorize planning. It never runs as part of the GET commands above. Use the current revision from GET. For reconciliation of a possibly accepted submission, reuse that submission's exact UUID: the same UUID returns current project state without calling the planner again, even with a stale revision. A new UUID explicitly authorizes a new plan; never automatically rotate UUIDs or retry unknown outcomes.

```bash
REVISION='current-integer-revision'
REQUEST_ID='explicitly-chosen-request-uuid'
BODY=$(python3 -c 'import json,sys; from uuid import UUID; print(json.dumps({"revision":int(sys.argv[1]),"request_id":str(UUID(sys.argv[2]))}))' "$REVISION" "$REQUEST_ID") || exit
printf 'Authorization: Bearer %s\n' "$MUSE_API_KEY" |
  curl --fail-with-body --silent --show-error --max-time 30 --proto '=https' \
    --header @- --header 'Content-Type: application/json' \
    --request POST --data "$BODY" "$MUSE_URL/v1/video-projects/$PROJECT_ID/plan" |
  python3 -c 'import json,sys; p=json.load(sys.stdin); print(json.dumps({"revision":p.get("revision"),"planning":p.get("planning")},indent=2))'
unset MUSE_API_KEY BODY
```

All routes require the existing bearer authentication. Projects, tasks, and media are tenant-owned. Base: `/v1/video-projects`.

`GET /v1/me` explicitly returns `capabilities.generation: true` for authenticated normal tenants and administrators. This is permission, not provider readiness: account availability, quotas and request limits are checked at submission. Disabled/revoked/invalid keys get HTTP 401, never a successful capability response.

## Executed shared HTTP contract

`docs/verification-logs/video-projects-http-contract.json` is generated from actual FastAPI TestClient HTTP requests (no auth overrides), not hand-written response data. It captures me/create/manual script+scene/approve/generate/completed/select/render/render_completed/reload/list. Existing video workers run with only the external generation adapter replaced by an unpaid synthetic local FFmpeg clip; render runs the real renderer and signed media URLs are downloaded without bearer headers. `media_gets` records actual response status, content type, byte count and SHA-256. Credentials are omitted. Random IDs, timestamps and signed URLs are intentionally actual output; URLs expire and cannot be reused against another instance.

Regenerate from repository root with existing dependencies and ffmpeg/ffprobe installed:

```sh
TMPDIR=$PWD/tests MUSE2API_TEST_TMP=$PWD/tests MUSE2API_CONTRACT_EXPORT=$PWD/docs/verification-logs/video-projects-http-contract.json python tests/run_backend_offline.py tests/test_video_project_contract.py -v
```

The offline guard rejects network sockets, requests, real engine generation and unrelated subprocesses. Frontend contract harnesses can consume each `exchanges[].response` alongside its recorded method/path/request body. This artifact proves backend HTTP behavior; frontend consumption still needs its own paired verification. CI installs FFmpeg and runs this contract in the guarded suite. Docker image smoke explicitly imports `app` and `video_projects` and creates/reloads a project through the running image's HTTP routes. `Dockerfile` uses `COPY *.py`, so new root modules are packaged automatically.

## Routes

- `GET /` → `{ "projects": [project, ...] }` (also supported without trailing slash).
- `POST /` with `title`, `idea`, `aspect_ratio` (`16:9` or `9:16`) → full project.
- `GET /:id` → refreshed project, reconciled jobs and renewed signed media URLs.
- `PATCH /:id` with `revision` and editable `title`, `idea`, `aspect_ratio`, `script`, `script_approved`, `scenes` → full project.
- `POST /:id/plan` with `revision,request_id` (UUID) → full project promptly after a durable planning receipt is saved. Poll project GET for the validated unapproved draft. Same UUID replays latest project before checking revision, without calling the planner again. Legacy `revision`-only requests retain synchronous draft/error behavior (no receipt; may exceed client timeout).
- `GET /:id/requests/:request_id` → `{request_id,action,accepted,status,scene_id,task_id,error}`. Known action is `plan|generate|render`; absent receipt has `action:null,accepted:false,status:"not_found"` and null scene/task/error. Known status is `queued|processing|completed|failed|unknown`. Scene ID is populated only for generation; task ID is the durable planning/render ID or generation task ID. Lookup binds owner and project; another tenant gets 404, another owned project sees not_found. HTTP/auth/observation failures are errors, **not** not_found or an invented unknown. GET only observes existing work and never submits or retries. Even not_found must not trigger automatic POST with a new ID.
- `POST /:id/scenes/:scene_id/generate` with `revision`, `request_id` UUID → full project. Requires script and scene approval.
- `POST /:id/render` with `revision`, `request_id` UUID → full project; bounded asynchronous FFmpeg simple-cut MP4. Requires approved script and all scenes, each with a selected completed owned take.

Optional project `planning`: `{id,request_id,status,stage,error,started_at,updated_at}`. Status uses `queued|processing|completed|failed|unknown`; stage uses `queued|planning|validating|completed|failed|unknown`. These are factual milestones, not upstream percentages or a token stream. A single-runtime daemon worker resolves provider credentials only inside the existing authenticated chat adapter; credentials are never persisted. Authority is checked before and after planning. Restart turns unfinished planning into durable unknown, without reissue. Invalid JSON/provider failure leaves editorial content untouched and stores a fixed safe error message plus the additive diagnostics described below. Any revision change outside planning's own milestones prevents applying the result; the user edit survives and planning fails with an edit-conflict message. Only one active plan per project and eight globally are admitted. Admission rejection is an HTTP error before receipt persistence; after admission, worker outcomes are read through project/receipt GET. No automatic retries on uncertain outcomes.

Project: `id,title,idea,aspect_ratio,revision,script,script_approved,scenes,render,created_at,updated_at`, plus optional `planning`. Scene: `id,order,narration,prompt,duration,approved,attempts,selected_attempt_id`. Editable scenes exclude `attempts`; existing scene IDs must belong to this project; omit ID for new scenes. `selected_attempt_id` may select a completed take belonging to the same scene. Duration is requested integer seconds (1–15); maximum 12 scenes and 120 requested seconds total.

Attempt: `id,task_id,status,media_id,url,error`. Render: `id,status,url,error,outdated`. Status enum: `queued|processing|completed|failed|unknown`. Empty optional fields are null. IDs are opaque except request_id, which must be a UUID. Timestamps are Unix seconds. Every successful mutation returns the latest full project and increments revision; stale revisions return 409. Child reconciliation also increments revision when durable state changes. A replay of a previously admitted request_id returns latest state even if the submitted revision is old. Reusing that UUID for another action/project/scene returns 409; no automatic paid resubmission. New UUID means explicit authorization for a new attempt/render.

Content edits invalidate corresponding approvals even when an edit simultaneously sends approved=true: approve the updated content in a subsequent PATCH. Script/idea/aspect edits invalidate all scene approvals; scene content edits invalidate that scene. Existing selected takes are preserved on regeneration and only the first successful take is selected automatically. Output snapshots become outdated on editorial/selection changes; a render already running may finish, but remains outdated if content changed. Titles alone do not invalidate approvals.

Only stable media IDs persist in projects. Signed URLs are generated on reads, never saved. Credentials are never stored in projects. Child jobs use the incumbent in-process video infrastructure, not HTTP self-calls. A restart/lost worker is reported unknown and never automatically resubmitted. A fresh request_id can explicitly authorize another attempt; previous selected takes remain available. No cancellation or batch submission in this MVP.

Capability failures: generation/planning require an available tenant account and incumbent generation authority; rendering requires ffmpeg and ffprobe on PATH. Unavailable capabilities return 503/400 with a manual-edit/recovery message. Admission checks existing tenant storage and heavy-request limits. Output writes use the incumbent atomic owner/quota media writer. Exhausted quota returns 507 before submission, or a failed render if quota changes while rendering. Missing/unowned/unsafe media cannot be rendered.

Rendering accepts no paths, URLs, filter expressions, executable names, or remote media from the client. It copies opened owned local files into isolated scratch, probes local streams, normalizes to 1280x720 or 720x1280 at 24fps H.264/AAC, retains source audio (silence when absent), and concatenates simple cuts. Narration is planning text only: no TTS, music, subtitles, or timeline editor. Each clip is bounded by requested duration; shorter sources are padded. Process wall-time, input/output size, scene count and total duration are bounded. There are no dependency installs or runtime/deployment changes in this feature.
