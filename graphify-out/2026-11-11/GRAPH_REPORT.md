# Graph Report - muse2api  (2026-11-11)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 2657 nodes · 4833 edges · 160 communities (119 shown, 41 thin omitted)
- Extraction: 97% EXTRACTED · 3% INFERRED · 0% AMBIGUOUS · INFERRED: 130 edges (avg confidence: 0.87)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `8a3dab9d`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- mailtm_otp.py
- Backend store · Store
- app.py
- test_video_late_attachment.py
- Backend tests · check()
- dependencies.dart
- account_import_test.dart
- Backend app · ImageRequest
- test_admin_layout.py
- shell.dart
- account_bloc.dart
- subprocess
- Backend proxy · HTTPProxyRelay
- test_reference_media.py
- Flutter tests · next_phases_transport_test.dart
- MuseEngine
- Backend app · ResponsesRequest
- desktop_engine_process_test.dart
- time
- Browser extension · run()
- desktop_connection_test.dart
- Backend tests · makeApi()
- Backend tests · FakeClock
- Response
- task_repository_impl.dart
- engine.py
- String?
- Tools · showPanel()
- desktop_engine_io.dart
- desktop_engine_stub.dart
- Flutter tests · account_batch_keepalive_page_test.dart
- ChatBloc
- Project configuration · muse2api
- Backend tests · Client
- chat_transport_test.dart
- Browser extension · extension/manifest.json
- Backend tests · Client (36)
- cookie_import_form.dart
- Flutter platform · AppDelegate
- studio_theme.dart
- Backend app · ConcurrencyLock
- _check_update_sync
- launcher.py
- account_batch_keepalive_bloc_test.dart
- Project configuration · Request
- app.dart
- video_page.dart
- Backend tests · Handler
- Backend tests · Page (48)
- Backend tests · check() (49)
- Flutter Videos · video_bloc.dart
- Flutter tests · reference_images_test.dart
- launcher.py
- Backend tests · FakeForm (53)
- Flutter tests · chat_history_test.dart
- Flutter platform · dependencies
- Flutter Chat · chat_bloc.dart
- media_delete_bloc_test.dart
- Flutter tests · status_page_test.dart
- asyncio
- Flutter platform · _MyApplication
- _AppShellState
- Config
- media_repository_impl.dart
- ConnectionBloc
- Flutter Accounts · proxy_editor.dart
- Flutter Images · image_bloc.dart
- Flutter platform · WindowClassRegistrar
- Flutter Core · media_preview.dart
- account_page.dart
- Flutter Status · server_status_bloc.dart
- Flutter Chat · chat_thread.dart
- BaseModel
- Flutter Media · media_page.dart
- image_remote_data_source.dart
- Flutter Media · delete_media.dart
- Project configuration · generated_plugin_registrant
- WS
- ServerConnection
- Flutter Chat · chat_page.dart
- Flutter Videos · video_repository_impl.dart
- Flutter Chat · chat_history_repository_impl.dart
- connection_repository.dart
- image_page.dart
- VideoBloc
- secure_credential_store.dart
- Flutter Connection · connection_repository_impl.dart
- Flutter Chat · manage_chat_history.dart
- Flutter Core · generation_workspace.dart
- Flutter Tasks · task_bloc.dart
- list_header.dart
- Flutter Accounts · _
- Backend tests · Client (92)
- Flutter Accounts · muse_account.dart
- Flutter Status · load_server_status.dart
- Project configuration · string
- Flutter tests · video_bloc_test.dart
- account_keepalive_bloc_test.dart
- Flutter Chat · send_message.dart
- test_reference_media_hardening.py
- AccountProxy
- Flutter Accounts · proxy_bloc.dart
- Flutter Accounts · manage_proxy.dart
- secure_history_record_store.dart
- Flutter Accounts · AccountRepository
- Flutter Core · reference_image.dart
- keepalive_status.dart
- Flutter Accounts · cookie_update_dialog.dart
- Flutter Tasks · load_tasks.dart
- Flutter tests · connection_bloc_test.dart
- _RefImageHTTPHandler
- Backend tests · QuotaLocalizationTests
- DesktopLauncherTests
- Flutter Connection · connection_local_data_source.dart
- Flutter Core · reference_picker.dart
- chat_repository_impl.dart
- proxy_repository_impl.dart
- Flutter platform · web/manifest.json
- Flutter platform · Win32Window
- Page
- Flutter Core · generation_task_decoder.dart
- desktop_engine_failure.dart
- Flutter Core · reference_cubit.dart
- Flutter platform · .MessageHandler()
- Browser
- connection_page.dart
- Flutter Core · pick_reference_images.dart
- _
- DesktopBuildTests
- Flutter Core · device_reference_file_source.dart
- Flutter Core · media_uri.dart
- FakeJSONRequest
- Flutter Chat · HistoryRecordStore
- ._apply_cookies
- Flutter platform · analysis_options.yaml
- Flutter Chat · chat_message.dart
- ../../../../core/domain/reference_image.dart
- Flutter Media · media_delete_result.dart
- Flutter platform · Point
- Flutter platform · Size
- Backend tests · FakeForm
- Flutter platform · MainActivity
- Flutter Media · media_name.dart
- List
- FakeMultipartRequest
- credential_store.dart
- FakeUpload
- Handler
- FakeClock
- Response
- Response

## God Nodes (most connected - your core abstractions)
1. `MuseEngine` - 58 edges
2. `ConnectionBloc` - 43 edges
3. `MuseGenerationError` - 38 edges
4. `Store` - 25 edges
5. `ChatBloc` - 23 edges
6. `_AppShellState` - 22 edges
7. `Win32Window` - 21 edges
8. `AccountBloc` - 20 edges
9. `_` - 20 edges
10. `ServerConnection` - 19 edges

## Surprising Connections (you probably didn't know these)
- `AccountProxyTests` --uses--> `Store`  [INFERRED]
  tests/test_account_proxy.py → store.py
- `AccountProxyTests` --uses--> `MuseEngine`  [INFERRED]
  tests/test_account_proxy.py → engine.py
- `AccountProxyTests` --uses--> `Config`  [INFERRED]
  tests/test_account_proxy.py → config.py
- `AccountProxyTests` --uses--> `MuseGenerationError`  [INFERRED]
  tests/test_account_proxy.py → engine.py
- `reject()` --uses--> `MuseGenerationError`  [INFERRED]
  tests/test_reference_media_hardening.py → engine.py

## Import Cycles
- None detected.

## Communities (160 total, 41 thin omitted)

### Community 0 - "mailtm_otp.py"
Cohesion: 0.27
Nodes (5): login(), main(), new_account(), poll(), req()

### Community 1 - "Backend store · Store"
Cohesion: 0.11
Nodes (8): public_proxy(), account_expiry(), _is_pos(), min_expiry(), _read(), Store, _write(), test_maintenance_selection_does_not_count_as_use()

### Community 2 - "app.py"
Cohesion: 0.07
Nodes (25): AccountRequest, add_account(), _admin_html(), admin_media(), admin_page(), admin_status(), admin_tasks(), build_tools_prompt() (+17 more)

### Community 3 - "test_video_late_attachment.py"
Cohesion: 0.14
Nodes (6): js_constant(), python_constant(), cases(), load_waiter(), main(), scenario()

### Community 4 - "Backend tests · check()"
Cohesion: 0.23
Nodes (9): extension_files(), extension_zip(), main(), addresses(), check(), check_endpoints(), expect_error(), redirect() (+1 more)

### Community 5 - "dependencies.dart"
Cohesion: 0.04
Nodes (17): chatHistory, connectionRepository, connectServer, desktopEngine, forgetConnection, generateImage, generateVideo, getImageTask (+9 more)

### Community 6 - "account_import_test.dart"
Cohesion: 0.13
Nodes (12): act, batch, bloc, fail, failReload, import, list, loaded (+4 more)

### Community 7 - "Backend app · ImageRequest"
Cohesion: 0.09
Nodes (28): build_image_prompt(), build_video_prompt(), create_image_task(), create_video(), worker(), _describe_kinds(), _extra_media(), _generic_upload_mime() (+20 more)

### Community 8 - "test_admin_layout.py"
Cohesion: 0.10
Nodes (7): CDP, http_json(), wait(), fixture(), FakeEngine, find_page_ws(), main()

### Community 9 - "shell.dart"
Cohesion: 0.11
Nodes (10): build, _createImage, createState, _destinations, dispose, _imagePrompt, initState, _more (+2 more)

### Community 10 - "account_bloc.dart"
Cohesion: 0.09
Nodes (34): AccountActed, AccountBloc, AccountCookiesUpdated, AccountEvent, AccountImported, AccountsBatchKeepaliveRequested, AccountsCleared, AccountsLoaded (+26 more)

### Community 11 - "subprocess"
Cohesion: 0.17
Nodes (10): _proxy_test_identity(), _detect_chromium(), _load_dotenv(), build_engine(), engine_bundle_ready(), main(), run(), source_fingerprint() (+2 more)

### Community 12 - "Backend proxy · HTTPProxyRelay"
Cohesion: 0.06
Nodes (12): HTTPProxyRelay, normalize_server(), _RelayServer, request_proxies(), split_proxy_url(), AccountProxyTests, browser_checks(), FixtureProxy (+4 more)

### Community 13 - "test_reference_media.py"
Cohesion: 0.15
Nodes (5): box(), data_url(), FakeMultipart, FakeUpload, mp4()

### Community 14 - "Flutter tests · next_phases_transport_test.dart"
Cohesion: 0.08
Nodes (19): apiError, ChatRemoteDataSource, streamReply, main, main, server, main, server (+11 more)

### Community 16 - "Backend app · ResponsesRequest"
Cohesion: 0.08
Nodes (20): admin_upgrade_now(), _as_tool_calls(), build_chat_prompt(), _chat_chunk(), chat_completions(), run(), sync_stream(), tool_call_deltas() (+12 more)

### Community 17 - "desktop_engine_process_test.dart"
Cohesion: 0.09
Nodes (17): announced, ChildProcess, errors, exitCode, exited, finish, handshake, input (+9 more)

### Community 18 - "time"
Cohesion: 0.08
Nodes (22): _account_operation(), _account_proxy(), _bind_account_proxy(), _clear_account_proxy(), clear_tasks(), delete_media(), healthz(), _pos() (+14 more)

### Community 19 - "Browser extension · run()"
Cohesion: 0.20
Nodes (12): applyLang(), ESSENTIAL, grabCookies(), I18N_EN, I18N_EN_HTML, I18N_EN_PATTERNS, LANG, log() (+4 more)

### Community 20 - "desktop_connection_test.dart"
Cohesion: 0.09
Nodes (21): exits, fail, forgetConnection, local, pending, readFails, readSavedConnection, remote (+13 more)

### Community 21 - "Backend tests · makeApi()"
Cohesion: 0.14
Nodes (6): body, end, here, html, lastBrace, start

### Community 22 - "Backend tests · FakeClock"
Cohesion: 0.07
Nodes (17): quota(), renew(), wait_case(), account(), route(), test(), api_checks(), fake_proxy() (+9 more)

### Community 24 - "task_repository_impl.dart"
Cohesion: 0.11
Nodes (10): JsonApiClient, request, api, load, api, clear, delete, list (+2 more)

### Community 25 - "engine.py"
Cohesion: 0.08
Nodes (18): AccountPoolManager, _run_generation_locked(), test_account_proxy(), _mp4_duration(), MuseAuthError, checked(), MuseGenerationError, MuseModelRefusalError (+10 more)

### Community 26 - "String?"
Cohesion: 0.12
Nodes (12): close, connection, error, _generation, items, loading, poll, _timer (+4 more)

### Community 27 - "Tools · showPanel()"
Cohesion: 0.36
Nodes (12): checkSessionStatus(), executePush(), getCookies(), loadCfg(), mountFloatingTrigger(), normBase(), saveCfg(), showPanel() (+4 more)

### Community 28 - "desktop_engine_io.dart"
Cohesion: 0.10
Nodes (17): _connection, createDesktopEngine, dataDirectory, executable, _exits, _generation, _process, _ready (+9 more)

### Community 29 - "desktop_engine_stub.dart"
Cohesion: 0.12
Nodes (13): ProcessDesktopEngine, createDesktopEngine, start, stop, supported, unexpectedExit, UnsupportedDesktopEngine, DesktopEngine (+5 more)

### Community 30 - "Flutter tests · account_batch_keepalive_page_test.dart"
Cohesion: 0.08
Nodes (19): bloc, build, showChatHistory, ensureVisible, keepaliveStatus, main, mount, open (+11 more)

### Community 31 - "ChatBloc"
Cohesion: 0.29
Nodes (18): didChangeAppLifecycleState, ChatBloc, ChatCleared, ChatEvent, ChatHistoryFlushed, ChatSessionChanged, ChatStopped, ChatSubmitted (+10 more)

### Community 32 - "Project configuration · muse2api"
Cohesion: 0.17
Nodes (11): build, container_name, environment, image, ports, restart, shm_size, volumes (+3 more)

### Community 33 - "Backend tests · Client"
Cohesion: 0.18
Nodes (3): build_cmd(), check(), Client

### Community 34 - "chat_transport_test.dart"
Cohesion: 0.12
Nodes (10): connection, main, server, body, close, closed, ClosingClient, connection (+2 more)

### Community 35 - "Browser extension · extension/manifest.json"
Cohesion: 0.18
Nodes (10): action, default_popup, default_title, default_locale, description, host_permissions, manifest_version, name (+2 more)

### Community 37 - "cookie_import_form.dart"
Cohesion: 0.14
Nodes (12): build, busy, CookieImportForm, _CookieImportFormState, _cookies, createState, dispose, _focus (+4 more)

### Community 38 - "Flutter platform · AppDelegate"
Cohesion: 0.07
Nodes (11): Cocoa, Flutter, FlutterMacOS, AppDelegate, SceneDelegate, RunnerTests, AppDelegate, MainFlutterWindow (+3 more)

### Community 39 - "studio_theme.dart"
Cohesion: 0.20
Nodes (9): accent, canvas, muted, raised, selected, StudioColors, StudioTheme, surface (+1 more)

### Community 41 - "_check_update_sync"
Cohesion: 0.16
Nodes (11): admin_repo_push(), _do_push(), _check_update_sync(), _ensure_git_repo(), _git(), _installed_sha_file(), _persist_env(), _read_env_key() (+3 more)

### Community 43 - "account_batch_keepalive_bloc_test.dart"
Cohesion: 0.14
Nodes (11): b, batchBusy, batches, batchLoaded, batchPending, cookiePending, keepaliveAll, KeepaliveRepo (+3 more)

### Community 44 - "Project configuration · Request"
Cohesion: 0.33
Nodes (3): _err_type(), _http_exc(), _validation_exc()

### Community 45 - "app.dart"
Cohesion: 0.12
Nodes (3): build, dependencies, AppDependencies

### Community 46 - "video_page.dart"
Cohesion: 0.13
Nodes (12): build, createState, dispose, _duration, _focus, _form, onConfigure, onTasks (+4 more)

### Community 50 - "Flutter Videos · video_bloc.dart"
Cohesion: 0.10
Nodes (19): _accept, admissionUncertain, busy, close, connection, duration, error, generate (+11 more)

### Community 51 - "Flutter tests · reference_images_test.dart"
Cohesion: 0.05
Nodes (28): AppFailure, message, toString, main, main, connection, create, failPoll (+20 more)

### Community 52 - "launcher.py"
Cohesion: 0.22
Nodes (7): bootstrap(), browser_path(), EngineInUseError, instance_lock(), main(), protocol(), serve()

### Community 54 - "Flutter tests · chat_history_test.dart"
Cohesion: 0.06
Nodes (26): cancelled, cancelling, completed, delete, deleted, deleting, fail, finished (+18 more)

### Community 55 - "Flutter platform · dependencies"
Cohesion: 0.07
Nodes (29): enable-swift-package-manager, dependencies, bloc, crypto, cupertino_icons, file_selector, flutter, flutter_bloc (+21 more)

### Community 56 - "Flutter Chat · chat_bloc.dart"
Cohesion: 0.08
Nodes (23): activeId, ChatState, close, _closing, connection, error, generation, history (+15 more)

### Community 57 - "media_delete_bloc_test.dart"
Cohesion: 0.04
Nodes (37): ConnectServer, Connect, a, b, calls, deleteBatch, deleteSingle, failure (+29 more)

### Community 58 - "Flutter tests · status_page_test.dart"
Cohesion: 0.04
Nodes (23): ServerStatusBloc, ServerStatusState, ServerStatusPage, main, preferences, main, open, batch (+15 more)

### Community 59 - "asyncio"
Cohesion: 0.18
Nodes (7): admin_check_update(), _keepalive_loop(), run_keepalive_all(), _shutdown(), _startup(), trigger_keepalive_all(), test_keepalive_only_runs_when_due()

### Community 60 - "Flutter platform · _MyApplication"
Cohesion: 0.10
Nodes (13): main(), first_frame_cb(), my_application_activate(), my_application_class_init(), my_application_dispose(), my_application_init(), my_application_local_command_line(), my_application_new() (+5 more)

### Community 61 - "_AppShellState"
Cohesion: 0.09
Nodes (35): AppShell, _AppShellState, _select, GenerationTask, CollectionBloc, CollectionCleared, CollectionEvent, CollectionLoaded (+27 more)

### Community 63 - "media_repository_impl.dart"
Cohesion: 0.22
Nodes (4): api, deleteBatch, deleteSingle, list

### Community 64 - "ConnectionBloc"
Cohesion: 0.08
Nodes (34): address, apiKey, attempt, close, connect, connection, ConnectionBloc, ConnectionDisconnected (+26 more)

### Community 65 - "Flutter Accounts · proxy_editor.dart"
Cohesion: 0.10
Nodes (20): ManageProxy, account, build, _clearPassword, _configuration, connection, createState, didUpdateWidget (+12 more)

### Community 66 - "Flutter Images · image_bloc.dart"
Cohesion: 0.09
Nodes (28): _accept, busy, close, connection, error, generate, generation, getTask (+20 more)

### Community 67 - "Flutter platform · WindowClassRegistrar"
Cohesion: 0.14
Nodes (8): EnableNonClientDpiScaling, Scale(), Win32Window::Win32Window(), WindowClassRegistrar, class_registered_, WindowClassRegistrar::GetWindowClass(), instance_, WindowClassRegistrar::UnregisterWindowClass()

### Community 68 - "Flutter Core · media_preview.dart"
Cohesion: 0.10
Nodes (15): build, createState, didUpdateWidget, dispose, _failed, initState, _load, MediaPreview (+7 more)

### Community 69 - "account_page.dart"
Cohesion: 0.05
Nodes (29): act, api, implements, import, keepaliveAll, keepaliveStatus, list, _statusCount (+21 more)

### Community 70 - "Flutter Status · server_status_bloc.dart"
Cohesion: 0.17
Nodes (10): busy, connection, connectionChanged, error, _generation, load, refresh, snapshot (+2 more)

### Community 71 - "Flutter Chat · chat_thread.dart"
Cohesion: 0.15
Nodes (7): calls, cancelled, connection, history, reply, streamReply, tick

### Community 72 - "BaseModel"
Cohesion: 0.18
Nodes (8): AccountPatch, ChatMessage, ChatRequest, patch_account(), ProxyTestRequest, _responses_messages(), ResponsesRequest, save()

### Community 73 - "Flutter Media · media_page.dart"
Cohesion: 0.11
Nodes (10): build, _confirming, createState, _selected, _selectionConnection, build, build, _confirming (+2 more)

### Community 74 - "image_remote_data_source.dart"
Cohesion: 0.18
Nodes (5): create, ImageRemoteDataSource, _request, create, remote

### Community 75 - "Flutter Media · delete_media.dart"
Cohesion: 0.13
Nodes (12): MediaRepositoryImpl, deleteBatch, deleteSingle, list, MediaRepository, call, DeleteMedia, repository (+4 more)

### Community 76 - "Project configuration · generated_plugin_registrant"
Cohesion: 0.11
Nodes (4): FlutterWindow, flutter_controller_, FlutterWindow::FlutterWindow(), project_

### Community 78 - "ServerConnection"
Cohesion: 0.20
Nodes (8): apiKey, baseUrl, endpoint, headers, isLocal, parse, ServerConnection, toString

### Community 79 - "Flutter Chat · chat_page.dart"
Cohesion: 0.18
Nodes (8): build, createState, dispose, _input, onConfigure, onCreateImage, _scroll, _welcome

### Community 80 - "Flutter Videos · video_repository_impl.dart"
Cohesion: 0.18
Nodes (8): VideoRepositoryImpl, create, VideoRepository, call, GenerateVideo, GetVideoTask, repository, FakeVideos

### Community 81 - "Flutter Chat · chat_history_repository_impl.dart"
Cohesion: 0.12
Nodes (8): delete, _key, list, _queue, _read, save, store, _write

### Community 82 - "connection_repository.dart"
Cohesion: 0.12
Nodes (15): ConnectionRepositoryImpl, ConnectionRepository, forgetConnection, readSavedConnection, saveConnection, savedAddress, verify, call (+7 more)

### Community 83 - "image_page.dart"
Cohesion: 0.12
Nodes (13): build, createState, didUpdateWidget, dispose, _form, initialPrompt, initState, onConfigure (+5 more)

### Community 84 - "VideoBloc"
Cohesion: 0.47
Nodes (10): _resumeVideo, VideoBloc, VideoEvent, _VideoPolled, VideoPollingRetried, VideoRequested, VideoResumed, VideosCleared (+2 more)

### Community 85 - "secure_credential_store.dart"
Cohesion: 0.22
Nodes (5): delete, _key, read, storage, write

### Community 86 - "Flutter Connection · connection_repository_impl.dart"
Cohesion: 0.14
Nodes (9): ConnectionRemoteDataSource, verify, forgetConnection, local, readSavedConnection, remote, saveConnection, savedAddress (+1 more)

### Community 87 - "Flutter Chat · manage_chat_history.dart"
Cohesion: 0.13
Nodes (12): ChatHistoryRepositoryImpl, ChatHistoryRepository, delete, list, save, delete, list, ManageChatHistory (+4 more)

### Community 88 - "Flutter Core · generation_workspace.dart"
Cohesion: 0.13
Nodes (13): MuseApp, build, busy, child, description, form, GenerationPreview, GenerationWorkspace (+5 more)

### Community 89 - "Flutter Tasks · task_bloc.dart"
Cohesion: 0.13
Nodes (13): close, connection, deleting, _generation, id, load, matches, _mutate (+5 more)

### Community 90 - "list_header.dart"
Cohesion: 0.20
Nodes (8): build, d, error, formatDate, loading, onRefresh, title, two

### Community 91 - "Flutter Accounts · _"
Cohesion: 0.13
Nodes (15): _, exitIp, hasPassword, normalizeServer, parse, passed, password, ProxyCheck (+7 more)

### Community 93 - "Flutter Accounts · muse_account.dart"
Cohesion: 0.14
Nodes (11): SavedAccountProxy, enabled, expiresAt, healthy, id, label, MuseAccount, plan (+3 more)

### Community 94 - "Flutter Status · load_server_status.dart"
Cohesion: 0.16
Nodes (8): updateCookies, ServerStatusRepositoryImpl, load, ServerStatusRepository, call, LoadServerStatus, repository, PendingStatusRepository

### Community 95 - "Project configuration · string"
Cohesion: 0.19
Nodes (4): wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16()

### Community 96 - "Flutter tests · video_bloc_test.dart"
Cohesion: 0.14
Nodes (9): connection, create, failPoll, failPost, makeBloc, pending, polls, posts (+1 more)

### Community 97 - "account_keepalive_bloc_test.dart"
Cohesion: 0.05
Nodes (35): bind, SseDecoder, bloc, calls, fail, list, loaded, main (+27 more)

### Community 98 - "Flutter Chat · send_message.dart"
Cohesion: 0.18
Nodes (8): ChatRepository, streamReply, call, repository, SendMessage, FakeChatRepository, DelayedCancellationReplies, Replies

### Community 99 - "test_reference_media_hardening.py"
Cohesion: 0.31
Nodes (4): data_url(), element(), reject(), webm()

### Community 101 - "Flutter Accounts · proxy_bloc.dart"
Cohesion: 0.18
Nodes (17): accountId, busy, check, configuration, connection, error, manage, _message (+9 more)

### Community 102 - "Flutter Accounts · manage_proxy.dart"
Cohesion: 0.18
Nodes (8): ProxyRepositoryImpl, ProxyRepository, save, test, repository, save, test, Proxy

### Community 103 - "secure_history_record_store.dart"
Cohesion: 0.25
Nodes (3): read, storage, write

### Community 104 - "Flutter Accounts · AccountRepository"
Cohesion: 0.06
Nodes (28): AccountRepositoryImpl, KeepaliveSummary, AccountCookiesRepository, AccountAction, AccountRepository, act, import, list (+20 more)

### Community 105 - "Flutter Core · reference_image.dart"
Cohesion: 0.10
Nodes (17): bytes, fingerprint, fromBytes, maxFileBytes, maxFiles, maxTotalBytes, mime, name (+9 more)

### Community 106 - "keepalive_status.dart"
Cohesion: 0.05
Nodes (35): createdAt, filename, GenerationStatus, id, kind, progress, prompt, status (+27 more)

### Community 107 - "Flutter Accounts · cookie_update_dialog.dart"
Cohesion: 0.18
Nodes (10): build, _cookies, CookieUpdateDialog, _CookieUpdateDialogState, createState, dispose, _error, onSubmit (+2 more)

### Community 108 - "Flutter Tasks · load_tasks.dart"
Cohesion: 0.17
Nodes (9): TaskRepositoryImpl, clear, delete, list, TaskRepository, call, LoadTasks, repository (+1 more)

### Community 109 - "Flutter tests · connection_bloc_test.dart"
Cohesion: 0.17
Nodes (9): credentials, forgetConnection, readSavedConnection, saveConnection, saved, savedAddress, tick, verification (+1 more)

### Community 113 - "Flutter Connection · connection_local_data_source.dart"
Cohesion: 0.18
Nodes (8): address, _addressKey, ConnectionLocalDataSource, credentials, forgetConnection, preferences, readConnection, saveConnection

### Community 114 - "Flutter Core · reference_picker.dart"
Cohesion: 0.22
Nodes (8): PickReferenceImages, ReferenceCubit, build, enabled, onChanged, onLoadingChanged, ReferencePicker, video

### Community 115 - "chat_repository_impl.dart"
Cohesion: 0.18
Nodes (5): ChatMessageModel, toJson, ChatRepositoryImpl, remote, streamReply

### Community 116 - "proxy_repository_impl.dart"
Cohesion: 0.29
Nodes (4): api, _json, save, test

### Community 117 - "Flutter platform · web/manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 118 - "Flutter platform · Win32Window"
Cohesion: 0.24
Nodes (4): Win32Window, child_content_, quit_on_close_, window_handle_

### Community 120 - "Flutter Core · generation_task_decoder.dart"
Cohesion: 0.20
Nodes (8): created, decodeTask, filename, id, progress, result, status, url

### Community 121 - "desktop_engine_failure.dart"
Cohesion: 0.29
Nodes (5): code, DesktopEngineFailure, DesktopEngineFailureCode, fromProtocol, message

### Community 122 - "Flutter Core · reference_cubit.dart"
Cohesion: 0.20
Nodes (8): error, images, loading, move, pick, pickImages, ReferenceState, remove

### Community 126 - "connection_page.dart"
Cohesion: 0.11
Nodes (14): _ProxyForm, ChatPage, _address, build, ConnectionPage, createState, dispose, initState (+6 more)

### Community 128 - "Flutter Core · pick_reference_images.dart"
Cohesion: 0.25
Nodes (6): DeviceReferenceFileSource, call, ReferenceFileSource, select, source, FakeFiles

### Community 129 - "_"
Cohesion: 0.15
Nodes (11): _, accountCount, AccountImportDraft, _hasCookies, isBatch, label, parse, text (+3 more)

### Community 132 - "Flutter Core · media_uri.dart"
Cohesion: 0.29
Nodes (3): endpoint, mediaUri, storageFailure

### Community 134 - "Flutter Chat · HistoryRecordStore"
Cohesion: 0.29
Nodes (6): HistoryRecordStore, read, write, SecureHistoryRecordStore, MemoryHistory, MemoryStatusHistoryStore

### Community 136 - "Flutter platform · analysis_options.yaml"
Cohesion: 0.33
Nodes (5): analyzer, exclude, include, linter, rules

### Community 137 - "Flutter Chat · chat_message.dart"
Cohesion: 0.40
Nodes (4): ChatMessage, content, MessageRole, role

### Community 138 - "../../../../core/domain/reference_image.dart"
Cohesion: 0.16
Nodes (9): ImageRepositoryImpl, create, ImageRepository, call, GenerateImage, GetImageTask, repository, FakeImages (+1 more)

### Community 139 - "Flutter Media · media_delete_result.dart"
Cohesion: 0.50
Nodes (3): errorCount, MediaDeleteResult, removed

### Community 140 - "Flutter platform · Point"
Cohesion: 0.50
Nodes (3): Point, x, y

### Community 141 - "Flutter platform · Size"
Cohesion: 0.50
Nodes (3): Size, height, width

### Community 151 - "List"
Cohesion: 0.29
Nodes (4): ChatThread, id, messages, updatedAt

### Community 153 - "credential_store.dart"
Cohesion: 0.29
Nodes (6): CredentialStore, delete, read, write, SecureCredentialStore, MemoryCredentialStore

## Knowledge Gaps
- **881 isolated node(s):** `ConnectionStatus`, `address`, `apiKey`, `attempt`, `status` (+876 more)
  These have ≤1 connection - possible missing edges. (Counts symbols only; 1474 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **41 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `MuseEngine` connect `MuseEngine` to `app.py`, `test_reference_media_hardening.py`, `._apply_cookies`, `Backend proxy · HTTPProxyRelay`, `engine.py`?**
  _High betweenness centrality (0.061) - this node is a cross-community bridge._
- **What connects `ConnectionStatus`, `address`, `apiKey` to the rest of the system?**
  _881 weakly-connected nodes found - possible missing edges._
- **Should `Backend store · Store` be split into smaller, more focused modules?**
  _Cohesion score 0.10984848484848485 - nodes in this community are weakly interconnected._
- **Why does `ServerConnection` connect `ServerConnection` to `ConnectionBloc`, `Flutter Accounts · proxy_editor.dart`, `Flutter Images · image_bloc.dart`, `chat_transport_test.dart`, `Flutter Accounts · proxy_bloc.dart`, `account_page.dart`, `Flutter Status · server_status_bloc.dart`, `Flutter Media · media_page.dart`, `account_bloc.dart`, `Flutter tests · connection_bloc_test.dart`, `Flutter Videos · video_bloc.dart`, `desktop_connection_test.dart`, `Flutter Chat · chat_bloc.dart`, `Flutter Tasks · task_bloc.dart`, `String?`, `desktop_engine_io.dart`, `_AppShellState`?**
  _High betweenness centrality (0.027) - this node is a cross-community bridge._
- **Should `app.py` be split into smaller, more focused modules?**
  _Cohesion score 0.0707070707070707 - nodes in this community are weakly interconnected._
- **Why does `_write()` connect `Backend store · Store` to `Backend tests · FakeClock`?**
  _High betweenness centrality (0.019) - this node is a cross-community bridge._
- **Should `test_video_late_attachment.py` be split into smaller, more focused modules?**
  _Cohesion score 0.13725490196078433 - nodes in this community are weakly interconnected._