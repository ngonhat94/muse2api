# Public video downloads

This adapter adopts OmniGet's link, quality and progress workflow through yt-dlp. OmniGet source was reviewed at tonhowtf/omniget. This implementation uses Muse's owner-bound store, admission, request reconciliation and media APIs.

## Discovery and admission

GET /v1/video-downloads/capability requires authentication and returns available, sites, qualities, max_bytes and max_seconds. The Python server requires yt-dlp 2026.10.26, FFmpeg and ffprobe. The frozen native engine reports unavailable because the isolated Python worker is required. The Flutter client can connect to a supported Python backend from desktop or mobile.

POST /v1/video-downloads requires authenticated JSON with request_id (UUID), url and quality (480, 720 or 1080, default 720). Extra fields are rejected. Body limit is 32 KiB, URL limit 2048 characters. Returns HTTP 202 with the durable job after admission.

Accepted initial host families are YouTube, TikTok, Facebook/fb.watch, Instagram, X/Twitter and Vimeo. HTTP links normalize to HTTPS. Userinfo, unrelated hosts and nonstandard ports are rejected. A provider's extractor may still reject a particular video because it is unavailable, requires authentication, has DRM, is live or is a playlist. Site support follows the pinned yt-dlp version. The request contains no headers, cookie file, browser profile, proxy or executable options.

Quality limits the shorter video edge, covering portrait and landscape media. The worker chooses MP4 video and M4A audio when separate audio is needed. Final ffprobe validation requires MP4, video duration at most 600 seconds, shorter edge within the chosen quality, dimensions at most 4096 each and at most 8,847,360 pixels. Maximum final file size is 128 MiB.

## Jobs and reconciliation

GET /v1/video-downloads returns the caller's 20 most recently admitted jobs. A new job prunes older terminal history records while retaining the saved media in the library and preserving UUID tombstones.

GET /v1/video-downloads/{id} returns an owner-bound job. Missing and foreign jobs return 404. Public fields include id, request_id, url, site, quality, status, stage, downloaded, total, title, error_code and timestamps. Completed jobs include media_id, duration, dimensions and url_result. The result URL is a signed Muse media capability and is null when the media has expired or was removed.

Statuses are queued, processing, completed, failed, cancelled and unknown. Progress stages include probing and downloading. downloaded/total describe the current media component. Total may be unknown or estimated. Completion is reported after validation and quota-accounted persistence. Raw yt-dlp logs, stack traces, CDN URLs and private environment data are excluded.

GET /v1/video-downloads/requests/{request_id} looks up an accepted UUID for the caller. The same owner/UUID and normalized URL/quality return the same job without another worker. Changed payload or a UUID used for project generation, reference import or image import returns 409. A missing receipt may mean the initial request has not reached durable admission. The client stores the original UUID and payload before POST and never resubmits automatically after reload or transport failure.

POST /v1/video-downloads/{id}/cancel requests cancellation of an active owned job. It is idempotent and returns the current job. Cancellation can race with completion. The temporary source is removed after the worker exits. Already saved library media remain available.

Restart converts nonterminal jobs to unknown and does not restart downloads. A new user-confirmed download uses a new UUID. Old requests whose history record was pruned return 404 and never create another job.

## Limits and worker boundary

Existing request, heavy-admission, storage, key-version and authority checks apply. At most one active download per owner and two per API process. A worker runs for at most 480 seconds with at most 384 MiB scratch data. On Linux the isolated process also limits address space to 1 GiB and individual files to 128 MiB. Partial files are removed, failed output persistence removes newly owned media, and the download worker exits after parent exit or timeout.

The child receives a minimal environment, disables ambient proxies, caches, user plugins, browser cookies, remote JS components and JS runtimes. Only yt-dlp's standard urllib handler is used. Every socket connection resolves and pins a public destination on port 80/443. Private, loopback, link-local, reserved, multicast, mapped-private and mixed public/private DNS answers are rejected, including redirects and CDN requests. FFmpeg/ffprobe subprocesses permit only local file/pipe input protocols. Other child executables are rejected.

The feature does not use Muse AI accounts, generation providers or speech services. Downloaded media use the existing owner-scoped library and signed media routes.
