# Scene narration API — phase 1

Canonical backend contract for the companion Flutter client. Additive to video-projects-api.md. No publishing or Shorts automation.

## Discovery and provider

Existing production requirements include `requests`; neither edge-tts nor a speech runtime is packaged. The OpenAI adapter uses OpenAI's actual HTTPS `POST /v1/audio/speech` binary PCM interface (signed 16-bit little-endian mono 24 kHz, wrapped into validated WAV server-side) through requests (no SDK/new dependency). It does **not** use Muse browser chat. Disabled by default. Server-only environment: `MUSE_TTS_PROVIDER=openai`, `MUSE_TTS_API_KEY`, optional `MUSE_TTS_MODEL` (default `gpt-4o-mini-tts`) and `MUSE_TTS_VOICE` (default `coral`). Endpoint fixed to api.openai.com, no client URL/key/voice override, no redirects/retries/fallback. Offline tests never call a provider. OpenAI currently documents this Speech API model as deprecated with shutdown January 6, 2027; this is a bounded existing-interface adapter, not a Realtime API integration. Operator must replace/migrate it before that deadline (https://developers.openai.com/api/docs/guides/text-to-speech). Clearly disclose AI-generated speech to end users. Operator must configure credentials and approve billing before use.

### VieNeu-TTS on a Gradio VPS

Set these on the Muse backend and restart it after configuration:

```sh
MUSE_TTS_PROVIDER=vieneu-gradio
MUSE_TTS_GRADIO_URL=https://your-vieneu-host.example
MUSE_TTS_VOICE="Thiện Minh"
```

Use the HTTPS origin of the Gradio web UI. Load the model in VieNeu and select an installed preset voice ID for the server configuration. Muse uses one preset per backend. The loaded model is managed on the VPS, so its identifier is left null in the scene record. Provider configuration and the capability check do not load models or start synthesis.

The adapter targets the VieNeu Gradio 5.49.1 preset speech handler. It submits the scene text once to `/gradio_api/call/wrapper`, reads its event stream, then downloads the completed WAV from the same origin. The raw request includes both hidden Gradio State slots. Only a final Gradio temporary WAV path is accepted. Redirects, reference uploads, cookies, OpenAI credentials and automatic retries are disabled. The existing scene duration and WAV limits apply. A provider error, timeout or incompatible Gradio handler fails the accepted attempt. Read the existing Muse receipt before considering another submission.

The VPS receives the scene text and caches generated files under its own access and retention rules. Restrict the VPS ingress to the Muse backend for private projects. The authenticated Muse audio route protects the copy stored by Muse. Flutter uses the existing capability provider field (`vieneu-gradio`) to identify the destination in its consent dialog.

## Wire contract

All routes require incumbent authenticated principal and owner scope; cross-owner IDs return 404.

* `GET /v1/video-projects/narration-capability`: `{available, provider, timing: "scene", max_characters: 4000}`. Availability means configuration and FFmpeg tools exist, not verified provider credit or health.
* `POST /v1/video-projects/{pid}/scenes/{sid}/narration`: strict body `{revision: int, request_id: UUID string, confirm_cost: true}`. Explicit consent required even when server pricing is unknown. Returns accepted project snapshot with durable receipt **before** asynchronous provider work; no polling POSTs. UUID identifies one action for this owner. Same UUID replays without another provider call, even after edits or failure; another action returns 409. New UUID is a new explicitly authorized attempt.
* `GET /v1/video-projects/{pid}` and existing `GET .../requests/{request_id}` reconcile only; never submit provider work. Request action `narration`, scene_id populated. Status enum `queued|processing|completed|failed|unknown`; absent receipt `not_found`. Restart interrupts active jobs to `unknown`; retry requires a new UUID and confirmation, never automatic paid resubmission.
* Each scene adds `narration_audio`: null or `{id,request_id,status,source_revision,provider,model,voice,media_id,duration,error,error_code}`. `source_revision` is a SHA-256 content binding of narration text + scene duration; unrelated project revision changes do not invalidate it. Only completed, matching binding audio is usable. Narration/duration edits mark it `stale`; existing scene narration text remains the source. Fixed public errors only. Audio is served only through authenticated `GET .../scenes/{sid}/narration/audio`; no public provider URL. Failed/stale/missing files never return audio.
* `GET /v1/video-projects/{pid}/captions?format=srt|vtt`: authenticated attachment, requires every scene's current completed audio. One cue per scene, from scene start until measured audio end; timeline offset advances by configured scene duration. This is **scene timing**, not word/forced alignment. Captions are generated from the current snapshot; no stale persisted caption file.
* Project adds `audio_mode`: `legacy` for old/new untouched projects, switches to `spoken` on first accepted narration action. Spoken render requires current completed audio for **every** scene; missing/stale/failed audio blocks export. Legacy render keeps previous source-audio/silent behavior intentionally. No new silent override is introduced and TTS failure never changes spoken mode back to legacy.

Limits: <=12 scenes, <=120 seconds project, scene 1–15 seconds, text <=4000 characters, audio <=8 MiB and <= scene duration (0.05s tolerance); overflow is rejected rather than truncated/speed changed. Two global narration jobs, one per owner, <=50 accepted narration attempts per scene; storage quotas and revocation lifecycle apply. WAV PCM must decode fully, contain non-silent finite samples, mono/stereo, 8–96kHz; unsafe/remote media rejected. Final MP4 must fully decode, contain expected video/audio codecs and dimensions, and match timeline duration before persistence. No invoice/cost estimate is fabricated.

## Upstream assessment

Reviewed darkzOGx/youtube-automation-agent (MIT), executable `utils/ai-video-generator.js` (`generateTTSAudio`, OpenAI speech request) and `utils/scene-repair-service.js` (`regenerateNarration`, stale revision state, `rebuildNarration`, `buildSRT`, silence confirmation). Adopted concepts, not copied source: explicit consent, revision binding, measured audio, per-scene rebuild and fail-closed export. Did not adopt simulation/fallback, approximate word alignment, unbounded response streaming, raw upstream error disclosure, or Node dependencies. Muse's existing Python ownership/store/job boundaries remain authoritative.
