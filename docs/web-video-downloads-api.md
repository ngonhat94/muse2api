# Public video downloads

This adapter adopts OmniGet's link, quality and progress workflow through yt-dlp. OmniGet source was reviewed at tonhowtf/omniget. This implementation uses Muse's owner-bound store, admission, request reconciliation and media APIs.

## Discovery and admission

GET /v1/video-downloads/capability requires authentication and returns available, sites, qualities, max_bytes and max_seconds. The Python server requires yt-dlp 2026.10.26, FFmpeg and ffprobe. The frozen native engine reports unavailable because the isolated Python worker is required. The Flutter client can connect to a supported Python backend from desktop or mobile.

The additive `youtube` object reports `available`, `runtime` (deno), `runtime_version`, `ejs_version`, `diagnostic` and `live_verified` (always false). General `available` only describes the basic downloader tools. `youtube.available` also requires the reviewed Deno 2.9.8 and yt-dlp-ejs 0.8.0. Neither field promises that a particular source or server IP can access YouTube. Capability checks only inspect local packages and run `deno --version`; they never contact YouTube. The Dockerfile copies the pinned official Deno image by digest and installs the pinned EJS wheel. Other Python installations must supply the same runtime/package pair. Frozen engines remain unsupported.

POST /v1/video-downloads requires authenticated JSON with request_id (UUID), url and quality (480, 720 or 1080, default 720). Extra fields are rejected. Body limit is 32 KiB, URL limit 2048 characters. Returns HTTP 202 with the durable job after admission.

Accepted initial host families are YouTube, TikTok, Facebook/fb.watch, Instagram, X/Twitter and Vimeo. HTTP links normalize to HTTPS. Userinfo, unrelated hosts and nonstandard ports are rejected. A provider's extractor may still reject a particular video because it is unavailable, requires authentication, has DRM, is live or is a playlist. Site support follows the pinned yt-dlp version. The request contains no headers, cookie file, browser profile, proxy or executable options.

Quality limits the shorter video edge, covering portrait and landscape media. The worker chooses MP4 video and M4A audio when separate audio is needed. Final ffprobe validation requires MP4, video duration at most 600 seconds, shorter edge within the chosen quality, dimensions at most 4096 each and at most 8,847,360 pixels. Maximum final file size is 128 MiB.

## Jobs and reconciliation

GET /v1/video-downloads returns the caller's 20 most recently admitted jobs. A new job prunes older terminal history records while retaining the saved media in the library and preserving UUID tombstones.

GET /v1/video-downloads/{id} returns an owner-bound job. Missing and foreign jobs return 404. Public fields include id, request_id, url, site, quality, status, stage, downloaded, total, title, error_code and timestamps. Completed jobs include media_id, duration, dimensions and url_result. The result URL is a signed Muse media capability and is null when the media has expired or was removed.

Statuses are queued, processing, completed, failed, cancelled and unknown. Progress stages include probing and downloading. downloaded/total describe the current media component. Total may be unknown or estimated. Completion is reported after validation and quota-accounted persistence. Raw yt-dlp logs, stack traces, CDN URLs and private environment data are excluded.

Failed jobs may include an additive `diagnostic` object: `reason`, a fixed Vietnamese `message`, and at most eight fixed `flags` observed in warnings/errors. No exception text, extracted URLs, credentials, headers or environment values enter this object. The parent validates these values again before persistence. Existing job records may lack it. UUID replay and receipt reads preserve the original diagnostic without running another worker. Older Flutter clients continue to use the existing coarse `error_code`; displaying the detailed message is a separate client change.

YouTube reasons distinguish `youtube_bot_check`, `youtube_login_required`, `youtube_po_token_required`, `youtube_js_runtime_missing`, `youtube_js_runtime_unsupported`, `youtube_ejs_missing`, and `youtube_js_challenge_failed`. Other fixed reasons cover `upstream_rate_limited`, `upstream_forbidden`, `blocked_destination`, `blocked_process`, `upstream_failure` and the existing bounds/protected/authentication/unsupported categories. A bot prompt uses coarse `error_code=unavailable`; an actual login/private/age prompt uses `authentication_required`. Merely mentioning cookies in a FAQ or URL is not evidence of authentication. A missing solver is detected before making a YouTube request. Flags describe observed symptoms, not proof that the server IP has been banned. Historical jobs cannot recover raw causes discarded by the older worker.

GET /v1/video-downloads/requests/{request_id} looks up an accepted UUID for the caller. The same owner/UUID and normalized URL/quality return the same job without another worker. Changed payload or a UUID used for project generation, reference import or image import returns 409. A missing receipt may mean the initial request has not reached durable admission. The client stores the original UUID and payload before POST and never resubmits automatically after reload or transport failure.

POST /v1/video-downloads/{id}/cancel requests cancellation of an active owned job. It is idempotent and returns the current job. Cancellation can race with completion. The temporary source is removed after the worker exits. Already saved library media remain available.

Restart converts nonterminal jobs to unknown and does not restart downloads. A new user-confirmed download uses a new UUID. Old requests whose history record was pruned return 404 and never create another job.

## Limits and worker boundary

Existing request, heavy-admission, storage, key-version and authority checks apply. At most one active download per owner and two per API process. A worker runs for at most 480 seconds with at most 384 MiB scratch data. On Linux it limits data allocations (RLIMIT_DATA) to 1 GiB, CPU time to 90 seconds per process, individual files to 128 MiB and core dumps to zero. Deno additionally limits V8 old-space heap to 128 MiB and disables JIT. RLIMIT_DATA replaces the prior RLIMIT_AS: V8 reserves a large virtual-address cage and cannot start under the old 1 GiB virtual-address limit. These are per-process limits, not an aggregate container memory cap. Partial files are removed and failed output persistence removes newly owned media. The parent cancels only its own newly created worker process group, including solver children; the worker watchdog kills that same group after parent exit or timeout on POSIX.

The child receives a minimal environment and disables ambient proxies, yt-dlp caches, user plugins, browser cookies and remote JS components. Only yt-dlp's standard urllib handler is used. Every socket connection resolves and pins a public destination on port 80/443. Private, loopback, link-local, reserved, multicast, mapped-private and mixed public/private DNS answers are rejected, including redirects and CDN requests. FFmpeg/ffprobe subprocesses permit only local file/pipe input protocols.

For YouTube only, the worker enables the packaged Deno solver. It permits just `deno --version` or the known yt-dlp stdin invocation and reconstructs the command with fixed restrictions: no file read/write, network, environment access, process creation, FFI, system information or external imports; no prompt, remote/npm packages, config or lock files. Deno gets a fresh minimal environment and a scratch-scoped internal cache directory. This internal runtime cache is not yt-dlp's persistent cache and is removed with scratch. User-provided executable options, alternate interpreters and shell overrides are rejected. Existing parent-side authority/quota/UUID checks are unchanged. No browser cookie is imported. The optional broker below is disabled by default.

## Offline verification

`python tests/run_backend_offline.py tests/test_web_downloads.py` covers the diagnostic classifier, runtime readiness, process restrictions, sanitized durable errors, auth/owner/UUID/quota/cancellation and restart behavior with synthetic data.

`python tools/check_youtube_runtime.py` exercises the installed EJS core through the actual yt-dlp Deno protocol with synthetic prepared n/signature functions. It also verifies denied file/network/environment/process/system/FFI access. The image smoke invokes it in a fresh read-only, capability-dropped container with `--network none`, a scratch tmpfs and a 1 GiB container memory cap. No production container, YouTube request, metadata extraction or media download is used. These checks prove packaging and local solver/sandbox operation, not live YouTube accessibility.

The feature does not use Muse AI accounts, generation providers or speech services. Downloaded media use the existing owner-scoped library and signed media routes.

## Optional anonymous PO Token broker

The optional, disabled-by-default sidecar and worker IPC are specified in [provider review notes](../deploy/pot-provider/README.md). The deployment-only `MUSE_YOUTUBE_POT_SOCKET` setting accepts exactly `/run/muse-pot/provider.sock` on POSIX. Enabling it selects only mweb with yt-dlp's `fetch_pot=auto`; it does not prefetch tokens or request unsupported player/subtitle tokens. Only required GVS token requests reach the job broker. The provider is not started by the backend or capability check.

`capability.youtube.anonymous_po_token` adds `configured` and `live_verified=false`. Configured means opted in, not that the socket/provider/network is ready or that YouTube is accessible. Existing clients can ignore the field. Fixed diagnostics add `youtube_po_provider_failed`, `youtube_po_request_rejected`, `youtube_po_binding_mismatch` and `youtube_po_token_expired`; token contents and upstream exceptions are never returned. Tokens are not durable: receipt/replay reads cannot mint or recover one and accepted jobs never auto-retry after restart. Each admitted job's broker checks current authority/key version and cancellation before and after provider work. Limits, admission, owner isolation, UUID reconciliation and media persistence remain unchanged.
