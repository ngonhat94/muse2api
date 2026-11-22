# Reference video MVP API (canonical client contract)

All routes require the existing bearer authentication. Use the existing `video_projects` capability/navigation gate; no new capability is required. Owner mismatches return 404, including administrators viewing another owner's job. No remote URLs are accepted.

## Upload and observation

`POST /v1/reference-videos` accepts multipart form data with exactly one `file` and no other fields. Returns HTTP 202 promptly after durable admission, with the job object (not a provider task). Upload/analysis use local FFmpeg only; there are no provider/VLM/audio calls.

`GET /v1/reference-videos/{id}` returns the same job shape:

```json
{"id":"opaque-id","status":"queued","stage":"queued","error":null,"shots":[],"created_at":1790000000,"updated_at":1790000000}
```

Statuses: `queued|processing|completed|failed|unknown`. Stages: `queued|probe|cuts|thumbnails|completed|failed|unknown`. `error` is null or a fixed safe public message; never infer diagnosis from arbitrary exception text. All timestamps are integer Unix seconds. Poll GET; do not automatically resubmit uploads. Interrupted queued/processing jobs become durable `unknown` on process restart and are NOT automatically restarted.

A completed `shots` item contains `id` (opaque string), `order` (zero-based), `start`, `end`, `duration` (seconds, numeric), `thumbnail_path` (relative authenticated API path). Shots are chronological, cover the video, and include unsuitable-for-import durations without silently splitting/truncating them. Midpoint JPEG keyframes are representative samples, not semantic summaries.

`GET /v1/reference-videos/{id}/shots/{shot_id}/thumbnail` returns authenticated `image/jpeg`, with private no-store caching. Fetch bytes with bearer auth rather than using an unauthenticated image URL. Missing/expired media returns 404. Never persist bearer tokens in URLs.

## Import

`POST /v1/reference-videos/{id}/import` JSON:

```json
{"request_id":"UUID","shot_ids":["opaque-shot-id"],"title":"Optional title"}
```

Returns HTTP 200 and a **full existing VideoProject**. Creates a NEW project, not a patch to an existing one. The project script and all scenes are unapproved, no attempts or render exist, and scene prompts explicitly state they are editable placeholders without semantic analysis. No automatic planning, approval, generation or paid call occurs. Continue through existing project editing/approval workflows.

Select 1–12 unique shots from a completed job; every selected shot must be 1–15 seconds, and their sum and the sum of rounded project durations must be <=120 seconds. Existing integer scene durations are nearest-second rounding (half up); exact source timings remain in the placeholder text. Selected shots are imported chronologically, independent of selection order. Invalid/unsuitable selections return 422; nothing is silently dropped or truncated.

`request_id` must be a UUID. Replaying the same owner/job/normalized selection/title UUID returns the same project's current full state even after restart or subsequent edits. Reusing a UUID with different payload, job or project action returns 409. Receipt and new project commit atomically in the existing durable project store, so a lost response cannot create duplicates.

## Limits and errors

Only `video/mp4`, `video/webm`, `video/quicktime` are accepted, checked again with ffprobe (MIME alone is not trusted). Max file 64 MiB, multipart body 65 MiB; duration (0,120] seconds; dimensions <=4096 each and <=8,847,360 pixels; frame rate <=120; <=120 detected shots. Two concurrent uploads/analyses per server, one per owner; 20 retained jobs/owner plus existing tenant storage quotas and heavy request admission. Maximum analysis wall time 120 seconds, individual subprocess <=30 seconds, single decoding/filter thread; local scratch source <=64 MiB, individual JPEG <=1 MiB and total thumbnails <=120 MiB, all charged through incumbent media storage. Source media is removed after terminal analysis; scratch is cleaned. Interrupted source media remains quota-accounted and can be deleted through existing owner media controls. Thumbnail retention follows incumbent owner-media retention; expired thumbnails do not invalidate already imported editorial projects.

HTTP errors: 401 missing/invalid identity, 404 missing/not-owned job/shot/media, 409 incomplete/unknown/failed job or UUID conflict, 413 body/file size, 415 unsupported MIME/container, 422 invalid multipart/import selection, 429 capacity/rate/job/project limit, 503 missing extraction binaries or unavailable accounting, 507 storage quota. Invalid/corrupt video discovered asynchronously yields `failed` with a safe message. Upload filenames are ignored. No URLs, shell commands, external protocols, client paths or executable arguments are accepted.

## Adapter and upstream scope

This is a **lightweight FFmpeg extraction adapter, not full semantic rea-video**. It detects visual hard-cut candidates using FFmpeg scene score >0.30 at source frame cadence after scaling, then extracts midpoint thumbnails. Fades, flashes, rapid motion and subtle cuts can be misclassified; no meaning, camera technique, transcript, music, authenticity or remake recipe is inferred.

Inspected upstream online: [README](https://github.com/JuneYaooo/rea-video/blob/main/README.md), [CLI](https://github.com/JuneYaooo/rea-video/blob/main/docs/cli.md), [Apache-2.0 license](https://github.com/JuneYaooo/rea-video/blob/main/LICENSE). Upstream decompose includes audio separation with first-use model downloads and optional OCR/ASR/VLM. `rea_video` is absent from the existing runtime; no upstream package/code/model was installed or vendored. Full rea-video integration, audio, VLM, VIDEO.md/capsule-cinema remakes and generation are explicitly deferred.

Runtime packaging: Docker already includes ffmpeg/ffprobe and copies root Python modules. Native desktop requires operator-provided binaries on PATH; unavailable runtimes fail closed with 503. Use a single API process as required by the incumbent project JSON store/runtime lock; this is not a distributed queue.

New imports with stored shot thumbnails attach those owned JPEGs as draft first frames. Approve them individually or replace them with still images in the project before generating clips. Replacing an imported frame leaves the reference job’s thumbnail intact.
