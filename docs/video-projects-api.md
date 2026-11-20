# Video projects MVP API

All routes require the existing bearer authentication. Projects, tasks, and media are tenant-owned. Base: `/v1/video-projects`.

- `GET /` → `{ "projects": [project, ...] }` (also supported without trailing slash).
- `POST /` with `title`, `idea`, `aspect_ratio` (`16:9` or `9:16`) → full project.
- `GET /:id` → refreshed project, reconciled jobs and renewed signed media URLs.
- `PATCH /:id` with `revision` and editable `title`, `idea`, `aspect_ratio`, `script`, `script_approved`, `scenes` → full project.
- `POST /:id/plan` with `revision` → validated, unapproved script/scenes draft via existing chat. If unavailable/invalid, keep the current project and edit manually; API returns an actionable error.
- `POST /:id/scenes/:scene_id/generate` with `revision`, `request_id` UUID → full project. Requires script and scene approval.
- `POST /:id/render` with `revision`, `request_id` UUID → full project; bounded asynchronous FFmpeg simple-cut MP4. Requires approved script and all scenes, each with a selected completed owned take.

Project: `id,title,idea,aspect_ratio,revision,script,script_approved,scenes,render,created_at,updated_at`. Scene: `id,order,narration,prompt,duration,approved,attempts,selected_attempt_id`. Editable scenes exclude `attempts`; existing scene IDs must belong to this project; omit ID for new scenes. `selected_attempt_id` may select a completed take belonging to the same scene. Duration is requested integer seconds (1–15); maximum 12 scenes and 120 requested seconds total.

Attempt: `id,task_id,status,media_id,url,error`. Render: `id,status,url,error,outdated`. Status enum: `queued|processing|completed|failed|unknown`. Empty optional fields are null. IDs are opaque except request_id, which must be a UUID. Timestamps are Unix seconds. Every successful mutation returns the latest full project and increments revision; stale revisions return 409. Child reconciliation also increments revision when durable state changes. A replay of a previously admitted request_id returns latest state even if the submitted revision is old. Reusing that UUID for another action/project/scene returns 409; no automatic paid resubmission. New UUID means explicit authorization for a new attempt/render.

Content edits invalidate corresponding approvals even when an edit simultaneously sends approved=true: approve the updated content in a subsequent PATCH. Script/idea/aspect edits invalidate all scene approvals; scene content edits invalidate that scene. Existing selected takes are preserved on regeneration and only the first successful take is selected automatically. Output snapshots become outdated on editorial/selection changes; a render already running may finish, but remains outdated if content changed. Titles alone do not invalidate approvals.

Only stable media IDs persist in projects. Signed URLs are generated on reads, never saved. Credentials are never stored in projects. Child jobs use the incumbent in-process video infrastructure, not HTTP self-calls. A restart/lost worker is reported unknown and never automatically resubmitted. A fresh request_id can explicitly authorize another attempt; previous selected takes remain available. No cancellation or batch submission in this MVP.

Capability failures: generation/planning require an available tenant account and incumbent generation authority; rendering requires ffmpeg and ffprobe on PATH. Unavailable capabilities return 503/400 with a manual-edit/recovery message. Admission checks existing tenant storage and heavy-request limits. Output writes use the incumbent atomic owner/quota media writer. Exhausted quota returns 507 before submission, or a failed render if quota changes while rendering. Missing/unowned/unsafe media cannot be rendered.

Rendering accepts no paths, URLs, filter expressions, executable names, or remote media from the client. It copies opened owned local files into isolated scratch, probes local streams, normalizes to 1280x720 or 720x1280 at 24fps H.264/AAC, retains source audio (silence when absent), and concatenates simple cuts. Narration is planning text only: no TTS, music, subtitles, or timeline editor. Each clip is bounded by requested duration; shorter sources are padded. Process wall-time, input/output size, scene count and total duration are bounded. There are no dependency installs or runtime/deployment changes in this feature.
