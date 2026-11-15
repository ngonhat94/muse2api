# Graph Report - muse2api  (2026-11-14)

## Corpus Check
- 277 files · ~118,938 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 62 file(s) not represented in the graph (top: (none) 14, .xcconfig 8, .xml 7)

## Summary
- 3078 nodes · 5667 edges · 170 communities (137 shown, 33 thin omitted)
- Extraction: 96% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 203 edges (avg confidence: 0.87)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `b60f4749`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- json
- Backend store · Store
- app.py
- test_video_late_attachment.py
- test_ref_image_safety.py
- dependencies.dart
- account_import_test.dart
- Backend app · ImageRequest
- test_admin_layout.py
- shell.dart
- account_bloc.dart
- subprocess
- HTTPProxyRelay
- test_reference_media.py
- Flutter tests · next_phases_transport_test.dart
- text_prompt_cubit.dart
- Backend app · ResponsesRequest
- desktop_engine_process_test.dart
- image_prompt_page_test.dart
- Browser extension · run()
- desktop_connection_test.dart
- Backend tests · makeApi()
- Backend tests · FakeClock
- _run_generation
- media_repository_impl.dart
- engine.py
- String?
- Tools · showPanel()
- desktop_engine_io.dart
- desktop_engine_stub.dart
- Flutter tests · account_batch_keepalive_page_test.dart
- ChatBloc
- Project configuration · muse2api
- Backend tests · Client
- connection_bloc_test.dart
- Browser extension · extension/manifest.json
- Backend tests · Client (36)
- cookie_import_form.dart
- Flutter platform · AppDelegate
- studio_theme.dart
- asyncio
- MuseAuthError
- account_batch_keepalive_bloc_test.dart
- Project configuration · Request
- media_save_button.dart
- video_page.dart
- Backend tests · Handler
- Backend tests · Page (48)
- Backend tests · check() (49)
- Flutter Videos · video_bloc.dart
- Flutter tests · reference_images_test.dart
- launcher.py
- generation_recovery_cubit.dart
- Flutter tests · chat_history_test.dart
- Flutter platform · dependencies
- Flutter Chat · chat_bloc.dart
- media_delete_bloc_test.dart
- MuseGenerationError
- image_prompt_repository_test.dart
- Flutter platform · _MyApplication
- task_bloc.dart
- image_prompt_page.dart
- account_repository_impl.dart
- connection_bloc.dart
- Flutter Accounts · proxy_editor.dart
- Flutter Images · image_bloc.dart
- Flutter platform · WindowClassRegistrar
- Flutter Core · media_preview.dart
- keepalive_status_bloc.dart
- Flutter Status · server_status_bloc.dart
- _AppShellState
- proxy.py
- Flutter Media · media_page.dart
- install.py
- Flutter Media · delete_media.dart
- Project configuration · generated_plugin_registrant
- WS
- desktop_install_panel_test.dart
- Flutter Chat · chat_page.dart
- load_tasks.dart
- Flutter Chat · chat_history_repository_impl.dart
- connection_repository.dart
- image_page.dart
- text_prompt_page.dart
- secure_credential_store.dart
- connection_local_data_source.dart
- Flutter Chat · manage_chat_history.dart
- Flutter Core · generation_workspace.dart
- desktop_engine_installer_io.dart
- list_header.dart
- Flutter Accounts · _
- Flutter Accounts · muse_account.dart
- Flutter Status · load_server_status.dart
- Project configuration · string
- video_bloc_test.dart
- pending_generation_store.dart
- Flutter Chat · send_message.dart
- image_prompt_cubit.dart
- chat_bloc_test.dart
- Flutter Accounts · proxy_bloc.dart
- Flutter Accounts · manage_proxy.dart
- media_save_test.dart
- manage_accounts.dart
- Flutter Core · reference_image.dart
- keepalive_status.dart
- Flutter Accounts · cookie_update_dialog.dart
- save_media.dart
- DesktopEngine
- _RefImageHTTPHandler
- Backend tests · QuotaLocalizationTests
- DesktopInstallTests
- connection_page.dart
- Flutter Core · reference_picker.dart
- media_save_button_test.dart
- connection_local_data_source.dart
- Flutter platform · web/manifest.json
- Flutter platform · Win32Window
- batch_keepalive_repository.dart
- Flutter Core · generation_task_decoder.dart
- package:flutter_test/flutter_test.dart
- Flutter Core · reference_cubit.dart
- Flutter platform · .MessageHandler()
- VideoBloc
- FakeClock
- Flutter Core · pick_reference_images.dart
- _
- DesktopBuildTests
- Flutter Core · device_reference_file_source.dart
- Flutter Core · media_uri.dart
- server_status.dart
- sys
- MuseEngine
- Flutter platform · analysis_options.yaml
- Flutter Chat · chat_message.dart
- generate_image.dart
- Flutter Media · media_delete_result.dart
- Flutter platform · Point
- Flutter platform · Size
- Config
- Flutter platform · MainActivity
- Flutter Media · media_name.dart
- List
- test_quota_account_binding.py
- chat_repository_impl.dart
- status_page_test.dart
- desktop_runtime_paths.dart
- image_task.dart
- media_repository_impl.dart
- generation_task.dart
- _
- test_admin_base_url.py
- browser_checks
- connection_repository.dart
- DateTime?
- ConnectServer
- desktop_engine_failure.dart
- FixtureProxy

## God Nodes (most connected - your core abstractions)
1. `MuseEngine` - 60 edges
2. `ConnectionBloc` - 49 edges
3. `MuseGenerationError` - 38 edges
4. `Store` - 25 edges
5. `_AppShellState` - 23 edges
6. `ChatBloc` - 23 edges
7. `ServerConnection` - 22 edges
8. `Win32Window` - 21 edges
9. `AccountBloc` - 20 edges
10. `_` - 20 edges

## Surprising Connections (you probably didn't know these)
- `AccountProxyTests` --uses--> `Store`  [INFERRED]
  tests/test_account_proxy.py → store.py
- `AccountProxyTests` --uses--> `HTTPProxyRelay`  [INFERRED]
  tests/test_account_proxy.py → proxy.py
- `AccountProxyTests` --uses--> `MuseEngine`  [INFERRED]
  tests/test_account_proxy.py → engine.py
- `AccountProxyTests` --uses--> `MuseGenerationError`  [INFERRED]
  tests/test_account_proxy.py → engine.py
- `reject()` --uses--> `MuseGenerationError`  [INFERRED]
  tests/test_reference_media_hardening.py → engine.py

## Import Cycles
- None detected.

## Communities (170 total, 33 thin omitted)

### Community 0 - "json"
Cohesion: 0.11
Nodes (5): http_json(), wait(), fixture(), fixture(), find_page_ws()

### Community 1 - "Backend store · Store"
Cohesion: 0.09
Nodes (17): add_account(), parse_batch(), parse_cookie_text(), _pos(), query_any_quota(), query_quota(), _probe(), _probe() (+9 more)

### Community 2 - "app.py"
Cohesion: 0.08
Nodes (24): _admin_html(), admin_media(), admin_page(), admin_status(), admin_tasks(), build_tools_prompt(), cookie_helper(), del_account() (+16 more)

### Community 3 - "test_video_late_attachment.py"
Cohesion: 0.15
Nodes (6): js_constant(), python_constant(), cases(), load_waiter(), main(), scenario()

### Community 4 - "test_ref_image_safety.py"
Cohesion: 0.08
Nodes (13): extension_zip(), check(), Client, Response, main(), api_checks(), fake_proxy(), addresses() (+5 more)

### Community 5 - "dependencies.dart"
Cohesion: 0.04
Nodes (21): chatHistory, connectionRepository, connectServer, desktopEngine, forgetConnection, generateImage, generateVideo, getImageTask (+13 more)

### Community 6 - "account_import_test.dart"
Cohesion: 0.13
Nodes (12): act, batch, bloc, fail, failReload, import, list, loaded (+4 more)

### Community 7 - "Backend app · ImageRequest"
Cohesion: 0.11
Nodes (23): build_image_prompt(), build_video_prompt(), create_image_task(), create_video(), _describe_kinds(), _extra_media(), _generic_upload_mime(), get_image_task() (+15 more)

### Community 8 - "test_admin_layout.py"
Cohesion: 0.15
Nodes (4): CDP, CDPError, FakeEngine, main()

### Community 9 - "shell.dart"
Cohesion: 0.05
Nodes (16): build, dependencies, AppDependencies, build, _createImage, createState, _createVideo, _destinations (+8 more)

### Community 10 - "account_bloc.dart"
Cohesion: 0.07
Nodes (40): AccountActed, AccountBloc, AccountCookiesUpdated, AccountEvent, AccountImported, AccountsBatchKeepaliveRequested, AccountsCleared, AccountsLoaded (+32 more)

### Community 11 - "subprocess"
Cohesion: 0.13
Nodes (18): _detect_chromium(), build_engine(), copy_setup_resources(), engine_bundle_ready(), main(), run(), source_fingerprint(), find_chrome() (+10 more)

### Community 12 - "HTTPProxyRelay"
Cohesion: 0.13
Nodes (6): HTTPProxyRelay, request_proxies(), request_proxy_context(), ProxyFixture, Handler, Server

### Community 13 - "test_reference_media.py"
Cohesion: 0.12
Nodes (6): box(), data_url(), FakeForm, FakeMultipart, FakeUpload, mp4()

### Community 14 - "Flutter tests · next_phases_transport_test.dart"
Cohesion: 0.07
Nodes (22): apiError, request, main, main, server, main, server, fullQuota (+14 more)

### Community 15 - "text_prompt_cubit.dart"
Cohesion: 0.10
Nodes (17): enhance, TextPromptRepositoryImpl, timeout, enhance, TextPromptRepository, clear, _current, edit (+9 more)

### Community 16 - "Backend app · ResponsesRequest"
Cohesion: 0.07
Nodes (23): _as_tool_calls(), build_chat_prompt(), _chat_chunk(), chat_completions(), run(), sync_stream(), tool_call_deltas(), ChatMessage (+15 more)

### Community 17 - "desktop_engine_process_test.dart"
Cohesion: 0.10
Nodes (17): announced, ChildProcess, errors, exitCode, exited, finish, handshake, input (+9 more)

### Community 18 - "image_prompt_page_test.dart"
Cohesion: 0.08
Nodes (11): main, generate, main, requests, bytes, length, main, name (+3 more)

### Community 19 - "Browser extension · run()"
Cohesion: 0.20
Nodes (12): applyLang(), ESSENTIAL, grabCookies(), I18N_EN, I18N_EN_HTML, I18N_EN_PATTERNS, LANG, log() (+4 more)

### Community 20 - "desktop_connection_test.dart"
Cohesion: 0.07
Nodes (28): cancelInstall, cancellation, cancellations, exits, fail, forgetConnection, install, installation (+20 more)

### Community 21 - "Backend tests · makeApi()"
Cohesion: 0.14
Nodes (6): body, end, here, html, lastBrace, start

### Community 22 - "Backend tests · FakeClock"
Cohesion: 0.05
Nodes (10): _load_dotenv(), renew(), Browser, Response, wait_case(), account(), FakeForm, FakeJSONRequest (+2 more)

### Community 23 - "_run_generation"
Cohesion: 0.17
Nodes (10): ConcurrencyLock, worker(), _on_acquired(), prog_cb(), worker(), _on_acquired(), _run_generation(), test_concurrency_lock() (+2 more)

### Community 24 - "media_repository_impl.dart"
Cohesion: 0.08
Nodes (17): JsonApiClient, api, load, api, clear, delete, list, api (+9 more)

### Community 25 - "engine.py"
Cohesion: 0.10
Nodes (10): _mp4_duration(), _NoRefImageRedirect, _open_public_ref_image(), _webm_duration(), elements(), vint(), data_url(), element() (+2 more)

### Community 26 - "String?"
Cohesion: 0.08
Nodes (19): apiKey, baseUrl, endpoint, headers, isLocal, parse, ServerConnection, toString (+11 more)

### Community 27 - "Tools · showPanel()"
Cohesion: 0.36
Nodes (12): checkSessionStatus(), executePush(), getCookies(), loadCfg(), mountFloatingTrigger(), normBase(), saveCfg(), showPanel() (+4 more)

### Community 28 - "desktop_engine_io.dart"
Cohesion: 0.09
Nodes (20): cancelInstall, _connection, createDesktopEngine, dataDirectory, executable, _exits, _generation, install (+12 more)

### Community 29 - "desktop_engine_stub.dart"
Cohesion: 0.15
Nodes (9): createDesktopEngine, start, stop, supported, unexpectedExit, start, stop, supported (+1 more)

### Community 30 - "Flutter tests · account_batch_keepalive_page_test.dart"
Cohesion: 0.08
Nodes (24): ensureVisible, keepaliveStatus, main, mount, open, pump, pumpAndSettle, pumpWidget (+16 more)

### Community 31 - "ChatBloc"
Cohesion: 0.29
Nodes (18): didChangeAppLifecycleState, ChatBloc, ChatCleared, ChatEvent, ChatHistoryFlushed, ChatSessionChanged, ChatStopped, ChatSubmitted (+10 more)

### Community 32 - "Project configuration · muse2api"
Cohesion: 0.17
Nodes (11): build, container_name, environment, image, ports, restart, shm_size, volumes (+3 more)

### Community 34 - "connection_bloc_test.dart"
Cohesion: 0.06
Nodes (23): AppFailure, message, toString, main, main, connection, main, server (+15 more)

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
Cohesion: 0.11
Nodes (14): accent, border, canvas, muted, raised, selected, StudioColors, StudioTheme (+6 more)

### Community 41 - "asyncio"
Cohesion: 0.06
Nodes (27): admin_check_update(), admin_repo_push(), _do_push(), admin_upgrade_now(), _check_update_sync(), clear_tasks(), delete_media(), _ensure_git_repo() (+19 more)

### Community 42 - "MuseAuthError"
Cohesion: 0.15
Nodes (15): _account_operation(), _account_proxy(), AccountPoolManager, _bind_account_proxy(), _clear_account_proxy(), _probe_account_sync(), _renew_and_persist(), _run_generation_locked() (+7 more)

### Community 43 - "account_batch_keepalive_bloc_test.dart"
Cohesion: 0.04
Nodes (40): bind, SseDecoder, b, batchBusy, batches, batchLoaded, batchPending, cookiePending (+32 more)

### Community 44 - "Project configuration · Request"
Cohesion: 0.33
Nodes (3): _err_type(), _http_exc(), _validation_exc()

### Community 45 - "media_save_button.dart"
Cohesion: 0.15
Nodes (14): SaveMedia, build, _busy, _bytes, _cancelled, createState, didUpdateWidget, dispose (+6 more)

### Community 46 - "video_page.dart"
Cohesion: 0.12
Nodes (14): build, createState, dispose, _duration, _focus, _form, initState, onConfigure (+6 more)

### Community 50 - "Flutter Videos · video_bloc.dart"
Cohesion: 0.09
Nodes (20): _accept, admissionUncertain, busy, close, connection, duration, error, generate (+12 more)

### Community 51 - "Flutter tests · reference_images_test.dart"
Cohesion: 0.05
Nodes (26): connection, create, failPoll, failPost, FakeImages, keys, pending, polls (+18 more)

### Community 52 - "launcher.py"
Cohesion: 0.18
Nodes (8): bootstrap(), browser_path(), EngineInUseError, instance_lock(), main(), protocol(), serve(), _RelayHandler

### Community 53 - "generation_recovery_cubit.dart"
Cohesion: 0.11
Nodes (13): close, connect, connection, image, images, RecoveryEntry, refresh, retry (+5 more)

### Community 54 - "Flutter tests · chat_history_test.dart"
Cohesion: 0.06
Nodes (26): cancelled, cancelling, completed, delete, deleted, deleting, fail, finished (+18 more)

### Community 55 - "Flutter platform · dependencies"
Cohesion: 0.06
Nodes (30): enable-swift-package-manager, dependencies, bloc, crypto, cupertino_icons, desktop_drop, file_selector, flutter (+22 more)

### Community 56 - "Flutter Chat · chat_bloc.dart"
Cohesion: 0.07
Nodes (23): activeId, ChatState, close, _closing, connection, error, generation, history (+15 more)

### Community 57 - "media_delete_bloc_test.dart"
Cohesion: 0.04
Nodes (33): a, b, calls, deleteBatch, deleteSingle, failure, items, list (+25 more)

### Community 58 - "MuseGenerationError"
Cohesion: 0.15
Nodes (6): checked(), MuseGenerationError, MuseModelRefusalError, MuseProxyError, RefImageSafetyError, _sniff_mime()

### Community 59 - "image_prompt_repository_test.dart"
Cohesion: 0.11
Nodes (14): ClosingClient, close, closed, ClosingClient, image, main, send, calls (+6 more)

### Community 60 - "Flutter platform · _MyApplication"
Cohesion: 0.10
Nodes (13): main(), first_frame_cb(), my_application_activate(), my_application_class_init(), my_application_dispose(), my_application_init(), my_application_local_command_line(), my_application_new() (+5 more)

### Community 61 - "task_bloc.dart"
Cohesion: 0.06
Nodes (28): GenerationTask, close, CollectionState, connection, error, _generation, items, loading (+20 more)

### Community 62 - "image_prompt_page.dart"
Cohesion: 0.13
Nodes (16): ImagePromptCubit, ImagePromptState, build, _copy, createState, _dragging, _drop, ImagePromptPage (+8 more)

### Community 63 - "account_repository_impl.dart"
Cohesion: 0.13
Nodes (11): act, api, implements, import, keepaliveAll, keepaliveStatus, list, _statusCount (+3 more)

### Community 64 - "connection_bloc.dart"
Cohesion: 0.08
Nodes (41): address, apiKey, attempt, _cancelInstallation, close, connect, connection, ConnectionBloc (+33 more)

### Community 65 - "Flutter Accounts · proxy_editor.dart"
Cohesion: 0.10
Nodes (20): ManageProxy, account, build, _clearPassword, _configuration, connection, createState, didUpdateWidget (+12 more)

### Community 66 - "Flutter Images · image_bloc.dart"
Cohesion: 0.09
Nodes (29): _accept, busy, close, connection, error, generate, generation, getTask (+21 more)

### Community 67 - "Flutter platform · WindowClassRegistrar"
Cohesion: 0.14
Nodes (8): EnableNonClientDpiScaling, Scale(), Win32Window::Win32Window(), WindowClassRegistrar, class_registered_, WindowClassRegistrar::GetWindowClass(), instance_, WindowClassRegistrar::UnregisterWindowClass()

### Community 68 - "Flutter Core · media_preview.dart"
Cohesion: 0.10
Nodes (16): build, connection, createState, didUpdateWidget, dispose, _failed, initState, _load (+8 more)

### Community 69 - "keepalive_status_bloc.dart"
Cohesion: 0.12
Nodes (14): KeepaliveStatus, busy, connection, error, KeepaliveStatusBloc, KeepaliveStatusState, refresh, repository (+6 more)

### Community 70 - "Flutter Status · server_status_bloc.dart"
Cohesion: 0.17
Nodes (10): busy, connection, connectionChanged, error, _generation, load, refresh, snapshot (+2 more)

### Community 71 - "_AppShellState"
Cohesion: 0.23
Nodes (19): _AppShellState, _select, CollectionBloc, CollectionCleared, CollectionEvent, CollectionLoaded, CollectionPaused, MediaBloc (+11 more)

### Community 72 - "proxy.py"
Cohesion: 0.08
Nodes (12): AccountPatch, AccountProxy, AccountRequest, patch_account(), ProxyTestRequest, normalize_server(), _RelayServer, split_proxy_url() (+4 more)

### Community 73 - "Flutter Media · media_page.dart"
Cohesion: 0.08
Nodes (16): MuseAccount, account, build, _percentage, _text, _usage, build, _confirming (+8 more)

### Community 74 - "install.py"
Cohesion: 0.31
Nodes (10): copy_sources(), install(), main(), protocol(), publish_runtime(), run_step(), setup_lock(), SetupError (+2 more)

### Community 75 - "Flutter Media · delete_media.dart"
Cohesion: 0.13
Nodes (12): MediaRepositoryImpl, deleteBatch, deleteSingle, list, MediaRepository, call, DeleteMedia, repository (+4 more)

### Community 76 - "Project configuration · generated_plugin_registrant"
Cohesion: 0.11
Nodes (4): FlutterWindow, flutter_controller_, FlutterWindow::FlutterWindow(), project_

### Community 78 - "desktop_install_panel_test.dart"
Cohesion: 0.12
Nodes (11): app, calls, cancelInstall, install, main, noSuchMethod, pending, start (+3 more)

### Community 79 - "Flutter Chat · chat_page.dart"
Cohesion: 0.12
Nodes (11): bloc, build, showChatHistory, build, createState, dispose, _input, onConfigure (+3 more)

### Community 80 - "load_tasks.dart"
Cohesion: 0.17
Nodes (9): TaskRepositoryImpl, clear, delete, list, TaskRepository, call, LoadTasks, repository (+1 more)

### Community 81 - "Flutter Chat · chat_history_repository_impl.dart"
Cohesion: 0.15
Nodes (8): delete, _key, list, _queue, _read, save, store, _write

### Community 82 - "connection_repository.dart"
Cohesion: 0.16
Nodes (10): ConnectionRepositoryImpl, ConnectionRepository, call, repository, call, ForgetConnection, repository, RestoreConnection (+2 more)

### Community 83 - "image_page.dart"
Cohesion: 0.11
Nodes (14): build, createState, didUpdateWidget, dispose, _form, initialPrompt, initState, onConfigure (+6 more)

### Community 84 - "text_prompt_page.dart"
Cohesion: 0.18
Nodes (12): TextPromptCubit, TextPromptState, build, _controller, createState, dispose, _focus, initState (+4 more)

### Community 85 - "secure_credential_store.dart"
Cohesion: 0.09
Nodes (15): CredentialStore, delete, read, write, delete, _key, read, SecureCredentialStore (+7 more)

### Community 86 - "connection_local_data_source.dart"
Cohesion: 0.14
Nodes (9): ConnectionRemoteDataSource, verify, forgetConnection, local, readSavedConnection, remote, saveConnection, savedAddress (+1 more)

### Community 87 - "Flutter Chat · manage_chat_history.dart"
Cohesion: 0.13
Nodes (12): ChatHistoryRepositoryImpl, ChatHistoryRepository, delete, list, save, delete, list, ManageChatHistory (+4 more)

### Community 88 - "Flutter Core · generation_workspace.dart"
Cohesion: 0.10
Nodes (17): MuseApp, GenerationRecoveryCubit, build, GenerationRecoveryPanel, build, busy, child, description (+9 more)

### Community 89 - "desktop_engine_installer_io.dart"
Cohesion: 0.17
Nodes (9): cancelInstall, _generation, install, _installing, _process, _python, _setupRoot, sourceRoot (+1 more)

### Community 90 - "list_header.dart"
Cohesion: 0.20
Nodes (8): build, d, error, formatDate, loading, onRefresh, title, two

### Community 91 - "Flutter Accounts · _"
Cohesion: 0.13
Nodes (15): _, exitIp, hasPassword, normalizeServer, parse, passed, password, ProxyConfiguration (+7 more)

### Community 93 - "Flutter Accounts · muse_account.dart"
Cohesion: 0.09
Nodes (17): enabled, expiresAt, extraExpires, extraLeft, extraRemaining, extraUsed, healthy, id (+9 more)

### Community 94 - "Flutter Status · load_server_status.dart"
Cohesion: 0.20
Nodes (7): ServerStatusRepositoryImpl, load, ServerStatusRepository, call, LoadServerStatus, repository, PendingStatusRepository

### Community 95 - "Project configuration · string"
Cohesion: 0.19
Nodes (4): wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16()

### Community 96 - "video_bloc_test.dart"
Cohesion: 0.17
Nodes (9): connection, create, failPoll, failPost, makeBloc, pending, polls, posts (+1 more)

### Community 97 - "pending_generation_store.dart"
Cohesion: 0.15
Nodes (12): id, _key, kind, list, PendingGeneration, PendingGenerationStore, preferences, _queue (+4 more)

### Community 98 - "Flutter Chat · send_message.dart"
Cohesion: 0.17
Nodes (9): ChatRepositoryImpl, ChatRepository, streamReply, call, repository, SendMessage, FakeChatRepository, DelayedCancellationReplies (+1 more)

### Community 99 - "image_prompt_cubit.dart"
Cohesion: 0.10
Nodes (17): generate, ImagePromptRepositoryImpl, timeout, generate, ImagePromptRepository, clear, _current, error (+9 more)

### Community 100 - "chat_bloc_test.dart"
Cohesion: 0.15
Nodes (7): calls, cancelled, connection, history, reply, streamReply, tick

### Community 101 - "Flutter Accounts · proxy_bloc.dart"
Cohesion: 0.17
Nodes (18): ProxyCheck, accountId, busy, check, configuration, connection, error, manage (+10 more)

### Community 102 - "Flutter Accounts · manage_proxy.dart"
Cohesion: 0.10
Nodes (13): api, _json, ProxyRepositoryImpl, save, test, updateCookies, ProxyRepository, save (+5 more)

### Community 103 - "media_save_test.dart"
Cohesion: 0.33
Nodes (3): connection, main, valid

### Community 104 - "manage_accounts.dart"
Cohesion: 0.11
Nodes (14): AccountAction, AccountRepository, act, import, list, act, import, list (+6 more)

### Community 105 - "Flutter Core · reference_image.dart"
Cohesion: 0.17
Nodes (10): bytes, fingerprint, fromBytes, maxFileBytes, maxFiles, maxTotalBytes, mime, name (+2 more)

### Community 106 - "keepalive_status.dart"
Cohesion: 0.17
Nodes (11): attempts, busy, checkedAt, failures, lastResult, lastRun, nextRun, running (+3 more)

### Community 107 - "Flutter Accounts · cookie_update_dialog.dart"
Cohesion: 0.20
Nodes (10): build, _cookies, CookieUpdateDialog, _CookieUpdateDialogState, createState, dispose, _error, onSubmit (+2 more)

### Community 108 - "save_media.dart"
Cohesion: 0.18
Nodes (8): bytes, connection, image, MediaSaveSource, remote, save, saver, uri

### Community 109 - "DesktopEngine"
Cohesion: 0.17
Nodes (11): ProcessDesktopInstaller, ProcessDesktopEngine, UnsupportedDesktopEngine, DesktopEngine, cancelInstall, DesktopEngineInstaller, DesktopInstallStage, install (+3 more)

### Community 113 - "connection_page.dart"
Cohesion: 0.10
Nodes (16): AppShell, _ProxyForm, ChatPage, _address, build, ConnectionPage, createState, dispose (+8 more)

### Community 114 - "Flutter Core · reference_picker.dart"
Cohesion: 0.22
Nodes (7): PickReferenceImages, build, enabled, onChanged, onLoadingChanged, ReferencePicker, video

### Community 115 - "media_save_button_test.dart"
Cohesion: 0.15
Nodes (9): NativeMediaSaver, UnsupportedMediaSaver, MediaSaver, MediaSaveResult, calls, completer, FakeSaver, main (+1 more)

### Community 116 - "connection_local_data_source.dart"
Cohesion: 0.18
Nodes (8): address, _addressKey, ConnectionLocalDataSource, credentials, forgetConnection, preferences, readConnection, saveConnection

### Community 117 - "Flutter platform · web/manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 118 - "Flutter platform · Win32Window"
Cohesion: 0.24
Nodes (4): Win32Window, child_content_, quit_on_close_, window_handle_

### Community 119 - "batch_keepalive_repository.dart"
Cohesion: 0.13
Nodes (14): AccountRepositoryImpl, KeepaliveSummary, AccountCookiesRepository, BatchKeepaliveRepository, BatchKeepaliveResult, busy, keepaliveAll, summary (+6 more)

### Community 120 - "Flutter Core · generation_task_decoder.dart"
Cohesion: 0.20
Nodes (8): created, decodeTask, filename, id, progress, result, status, url

### Community 121 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.04
Nodes (24): main, preferences, main, open, batch, main, a, main (+16 more)

### Community 122 - "Flutter Core · reference_cubit.dart"
Cohesion: 0.18
Nodes (9): error, images, loading, move, pick, pickImages, ReferenceCubit, ReferenceState (+1 more)

### Community 125 - "VideoBloc"
Cohesion: 0.42
Nodes (11): _resumeVideo, VideoBloc, VideoEvent, _VideoPolled, VideoPollingRetried, VideoRequested, VideoResumed, VideosCleared (+3 more)

### Community 128 - "Flutter Core · pick_reference_images.dart"
Cohesion: 0.25
Nodes (6): DeviceReferenceFileSource, call, ReferenceFileSource, select, source, FakeFiles

### Community 129 - "_"
Cohesion: 0.11
Nodes (9): ChatRemoteDataSource, streamReply, create, ImageRemoteDataSource, _request, fromJson, ImageTaskModel, create (+1 more)

### Community 132 - "Flutter Core · media_uri.dart"
Cohesion: 0.18
Nodes (5): createMediaSaver, save, endpoint, mediaUri, storageFailure

### Community 133 - "server_status.dart"
Cohesion: 0.17
Nodes (10): browserRunning, disabledAccounts, enabledAccounts, errorAccounts, expiredAccounts, expiringAccounts, healthyAccounts, mediaCount (+2 more)

### Community 134 - "sys"
Cohesion: 0.33
Nodes (5): login(), main(), new_account(), poll(), req()

### Community 136 - "Flutter platform · analysis_options.yaml"
Cohesion: 0.33
Nodes (5): analyzer, exclude, include, linter, rules

### Community 137 - "Flutter Chat · chat_message.dart"
Cohesion: 0.40
Nodes (4): ChatMessage, content, MessageRole, role

### Community 138 - "generate_image.dart"
Cohesion: 0.18
Nodes (8): ImageRepositoryImpl, create, ImageRepository, call, GenerateImage, GetImageTask, repository, RejectedImageRepository

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

### Community 153 - "chat_repository_impl.dart"
Cohesion: 0.20
Nodes (4): ChatMessageModel, toJson, remote, streamReply

### Community 154 - "status_page_test.dart"
Cohesion: 0.07
Nodes (22): HistoryRecordStore, read, write, SecureHistoryRecordStore, ServerStatusBloc, ServerStatusState, build, ServerStatusPage (+14 more)

### Community 155 - "desktop_runtime_paths.dart"
Cohesion: 0.12
Nodes (13): _busy, createMediaSaver, idleTimeout, _pick, save, data, desktopDataDirectory, desktopResourceDirectory (+5 more)

### Community 156 - "image_task.dart"
Cohesion: 0.14
Nodes (9): bytes, id, ImageTask, ImageTaskStatus, progress, status, terminal, main (+1 more)

### Community 157 - "media_repository_impl.dart"
Cohesion: 0.22
Nodes (4): api, deleteBatch, deleteSingle, list

### Community 158 - "generation_task.dart"
Cohesion: 0.20
Nodes (9): createdAt, filename, GenerationStatus, id, kind, progress, prompt, status (+1 more)

### Community 159 - "_"
Cohesion: 0.22
Nodes (9): _, accountCount, AccountImportDraft, _hasCookies, isBatch, label, parse, text (+1 more)

### Community 162 - "test_admin_base_url.py"
Cohesion: 0.29
Nodes (3): build_cmd(), check(), Response

### Community 164 - "connection_repository.dart"
Cohesion: 0.29
Nodes (5): forgetConnection, readSavedConnection, saveConnection, savedAddress, verify

### Community 165 - "DateTime?"
Cohesion: 0.33
Nodes (4): bytes, createdAt, isVideo, name

### Community 166 - "ConnectServer"
Cohesion: 0.40
Nodes (5): ConnectServer, Connect, UnusedConnect, Connect, Connect

### Community 167 - "desktop_engine_failure.dart"
Cohesion: 0.29
Nodes (6): code, DesktopEngineFailure, DesktopEngineFailureCode, fromInstallProtocol, fromProtocol, message

## Knowledge Gaps
- **1104 isolated node(s):** `dependencies`, `build`, `imagePromptRepository`, `textPromptRepository`, `saveMedia` (+1099 more)
  These have ≤1 connection - possible missing edges. (Counts symbols only; 1738 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **33 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `ServerConnection` connect `String?` to `connection_bloc.dart`, `Flutter Accounts · proxy_editor.dart`, `Flutter Images · image_bloc.dart`, `connection_bloc_test.dart`, `Flutter Core · media_preview.dart`, `keepalive_status_bloc.dart`, `Flutter Accounts · proxy_bloc.dart`, `Flutter Status · server_status_bloc.dart`, `Flutter Media · media_page.dart`, `account_bloc.dart`, `save_media.dart`, `Flutter Videos · video_bloc.dart`, `desktop_connection_test.dart`, `generation_recovery_cubit.dart`, `Flutter Chat · chat_bloc.dart`, `desktop_engine_io.dart`, `task_bloc.dart`?**
  _High betweenness centrality (0.037) - this node is a cross-community bridge._
- **What connects `dependencies`, `build`, `imagePromptRepository` to the rest of the system?**
  _1104 weakly-connected nodes found - possible missing edges._
- **Should `json` be split into smaller, more focused modules?**
  _Cohesion score 0.1111111111111111 - nodes in this community are weakly interconnected._
- **Why does `MuseEngine` connect `MuseEngine` to `app.py`, `browser_checks`, `test_admin_layout.py`, `.ensure_page`, `Config`, `Backend tests · FakeClock`, `engine.py`, `MuseGenerationError`, `._attach_images`?**
  _High betweenness centrality (0.028) - this node is a cross-community bridge._
- **Should `Backend store · Store` be split into smaller, more focused modules?**
  _Cohesion score 0.08658536585365853 - nodes in this community are weakly interconnected._
- **Why does `Win32Window` connect `Flutter platform · Win32Window` to `Flutter platform · WindowClassRegistrar`, `Flutter platform · Point`, `Project configuration · generated_plugin_registrant`, `Flutter platform · Size`, `Flutter platform · .MessageHandler()`, `Project configuration · windows`?**
  _High betweenness centrality (0.027) - this node is a cross-community bridge._
- **Should `app.py` be split into smaller, more focused modules?**
  _Cohesion score 0.0753045404208195 - nodes in this community are weakly interconnected._