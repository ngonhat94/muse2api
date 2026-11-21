# Shorts API — canonical backend-owned phase 2 contract

Base: `/v1/video-projects/{pid}/shorts`. All routes require the existing bearer identity and video-project capability; cross-owner IDs return 404. No AI/provider calls, publishing or AI quota charge. Reuses selected completed owned takes and existing narration only. Existing project API is unchanged.

## Draft

`POST base` → 201 Short; `GET base` → `{shorts:[Short]}`; `GET base/{id}` → Short; `PATCH base/{id}` → Short.

Create body (all explicit):
```json
{"project_revision":4,"title":"Trích đoạn","scene_ids":["scene-id"],"start":0.0,"end":5.0,"crop_x":0.5,"burn_captions":false}
```
PATCH uses the same complete fields plus `revision` (current Short revision). `project_revision` must match current project. Scene IDs form an ordered, unique list (1–12) of existing approved scenes with current selected completed takes. Timeline = those scenes concatenated in supplied order, each using its configured duration. `start` inclusive / `end` exclusive are seconds on this timeline; finite, 0 <= start < end <= timeline duration, output 0.25–60 seconds. No looping/frozen-frame substitution if a source is shorter than configured timing. `crop_x` finite normalized horizontal crop position 0..1, not a pixel offset or face tracker. Output is exactly 720×1280, 24fps H.264/AAC; full-height 9:16 crop when source is wide, full-width vertical-centered crop when source is narrower than 9:16. Even crop dimensions/offsets are clamped inside actual decoded dimensions. No letterboxing. Narration is reused only when current; legacy projects preserve source audio/silence. No speech provider configuration is required.

Short shape: `id,title,revision,project_revision,scene_ids,start,end,crop_x,burn_captions,source,created_at,updated_at,jobs,approved_render_id,source_current,output_eligible`. `source` is durable provenance including scene/take IDs, source binding, durations, narration IDs and timing. Editing draft increments only Short revision, clears approval; jobs/artifacts remain immutable and accessible by job ID. Current source/take/narration/layout changes make `source_current` and `output_eligible` false until explicitly saving a fresh draft. No implicit rebind.

## Render / receipt / reconciliation

`POST base/{id}/renders` → 202 RenderJob, body `{revision:1,request_id:"canonical UUID"}`. Explicit UUID is both render ID and immutable receipt. `GET base/{id}/renders/{request_id}` returns accepted job; absent UUID → 404 (safe observation, does not submit). Replaying identical POST returns original job even after revision change/restart; UUID with another Short/payload → 409. Unknown jobs never auto-render; manually inspect receipt, then explicitly submit a **new** UUID if desired. Max 2 local concurrent renders globally / 1 per owner; busy → 429. Queued/processing at restart become `unknown`, no automatic retry. Accepted snapshot preserves the draft revision, source provenance, exact trimmed clips, crop and caption cues independently of later edits.

RenderJob: `id,request_id,revision,status,snapshot,error,created_at,media_id` (nullable). Status: `queued|processing|completed|failed|unknown`. Public failure text is fixed, never raw FFmpeg/provider paths. `POST base/{id}/renders/{request_id}/approve`, body `{revision:currentShortRevision}` approves only completed current-source/current-draft output; stale → 409. No publishing side effects.

## Authenticated media

`GET base/{id}/frame?revision=1&at=0.0` → JPEG, **at is output-relative** in [0,end-start). Decodes selected real source frame using identical crop geometry; no burn-in in editor frame. Stale source/revision → 409. Use this for accurate adjustable crop preview, not a stretched thumbnail.

`GET base/{id}/renders/{request_id}/video` → MP4 (preview/final use same real rendered artifact, no public URL).

`GET base/{id}/renders/{request_id}/captions?format=srt|vtt` → UTF-8 captions from accepted snapshot, times rebased and clipped to output segment. Cues are scene-level editorial text, not word-aligned transcription; spoken cues end at actual narration duration, legacy cues span scene duration. Vietnamese preserved; markup escaped for burn rendering. Old job artifacts remain owner-readable, but cannot be approved as current after edits.

## Runtime limits / capability

`GET base/capability` → `{available,burn_captions,max_duration,width,height}`. Route registered before Short ID. Missing local filters/fonts yields 503 before burn admission; non-burn MP4 plus SRT/VTT remains available without any new dependency install. Burn requires libass `subtitles` filter and existing FreeSans/DejaVuSans font; capability validates actual local filter/font availability, not narration credentials. No arbitrary path or URL input. Inputs copied from owner-bound media handles; local-only FFmpeg protocols, 1 codec/filter thread, 300s overall render deadline, 90s per command, bounded 512MiB video inputs, 256MiB per clip, 64MiB part output and 256MiB final. Storage quota enforced by incumbent store. Preview is concurrency-bounded. Per project max 50 drafts / 50 accepted jobs per Short. Exact source media duration/dimensions/frame-rate validated before export; shorter sources fail safely.

Reference review: inspected `darkzOGx/youtube-automation-agent` master `utils/shorts-repurposing-service.js` and MIT LICENSE read-only. This implementation is independent Python code; no source copied. Retained only the general real-media crop/caption workflow idea; deliberately excluded automatic window proposals, scheduling, arbitrary filesystem paths, output overwrite and publishing. No semantic “best moment” claim.

Errors: 401 invalid/missing identity; 403 incumbent capability/policy denial; 404 foreign/missing IDs; 409 stale revision/source/UUID collision/ineligible approval; 422 malformed bounds/unknown scene/crop/format; 429 capacity/draft/job limits; 503 local rendering capability unavailable. HTTP validation errors follow incumbent FastAPI conventions. Cache policy for media: private, no-store.

Frontend integration: retain UUID until receipt resolves, never auto-submit on timeout/reload; load server capability and current selected scenes; on 409 preserve editor input and refresh explicitly. Render status polling does not change draft revision. Clients must not equate completed with output_eligible.
