# Graph Report - muse2api  (2026-11-15)

## Corpus Check
- 332 files · ~161,376 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 64 file(s) not represented in the graph (top: (none) 16, .xcconfig 8, .xml 7)

## Summary
- 3764 nodes · 7091 edges · 206 communities (157 shown, 49 thin omitted)
- Extraction: 96% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 276 edges (avg confidence: 0.86)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `abe7a95c`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- test_admin_layout.py
- os
- BaseModel
- test_video_late_attachment.py
- dependencies.dart
- _owner
- images_edits
- Store
- worker
- migrate_accounts
- json
- subprocess
- test_account_proxy.py
- test_ref_image_safety.py
- package:flutter_test/flutter_test.dart
- media_page.dart
- dependencies
- desktop_connection_test.dart
- Browser extension · run()
- _check_update_sync
- Backend tests · makeApi()
- json
- task_repository_impl.dart
- ../errors/app_failure.dart
- engine.py
- media_bloc.dart
- Tools · showPanel()
- package:muse_app/features/connection/domain/entities/server_connection.dart
- RuntimeBlockers
- .write_media
- ChatBloc
- Project configuration · muse2api
- Backend tests · Client
- ServerConnection
- Browser extension · extension/manifest.json
- desktop_engine_io.dart
- muse_account.dart
- Flutter platform · AppDelegate
- AccountProxyTests
- account_batch_keepalive_page_test.dart
- library_batch_saver_io.dart
- desktop_engine_process_test.dart
- chat_completions
- shell.dart
- account_bloc.dart
- server_connection.dart
- Backend tests · Handler
- Backend tests · Page (48)
- Backend tests · check() (49)
- media_preview.dart
- image_bloc_test.dart
- ReferenceAdmission
- storage_usage_cubit.dart
- Flutter tests · chat_history_test.dart
- generation_recovery_cubit.dart
- Flutter Chat · chat_bloc.dart
- media_delete_bloc_test.dart
- image_prompt_page.dart
- image_prompt_repository_test.dart
- Flutter platform · _MyApplication
- media_save_button.dart
- desktop_install_panel_test.dart
- account_quota_section.dart
- connection_bloc.dart
- Flutter Accounts · proxy_editor.dart
- Flutter Images · image_bloc.dart
- Flutter platform · WindowClassRegistrar
- install.py
- account_repository_impl.dart
- server_status.dart
- task_bloc.dart
- cookie_import_form.dart
- status_page_test.dart
- secure_credential_store.dart
- Flutter Media · delete_media.dart
- Project configuration · generated_plugin_registrant
- WS
- task_delete_bloc_test.dart
- Flutter Chat · chat_page.dart
- ../../../connection/domain/entities/server_connection.dart
- Flutter Chat · chat_history_repository_impl.dart
- connection_repository.dart
- launcher.py
- package:flutter_bloc/flutter_bloc.dart
- valid_media_name
- ../../../../core/errors/app_failure.dart
- Flutter Chat · manage_chat_history.dart
- Flutter Core · generation_workspace.dart
- app.py
- list_header.dart
- Flutter Accounts · _
- bool get
- connection_local_data_source.dart
- server_status_bloc.dart
- Project configuration · string
- MuseEngine
- ._write_accounts
- Flutter Chat · send_message.dart
- desktop_engine_installer_io.dart
- chat_bloc_test.dart
- Flutter Accounts · proxy_bloc.dart
- Flutter Accounts · manage_proxy.dart
- DesktopEngine
- manage_accounts.dart
- Flutter Core · reference_image.dart
- pending_generation_store.dart
- Flutter Accounts · cookie_update_dialog.dart
- chat_repository_impl.dart
- generation_task_decoder.dart
- video_page.dart
- Backend tests · QuotaLocalizationTests
- UserStore
- studio_theme.dart
- LedgerTests
- test_proxy_status_receipt.py
- image_prompt_cubit.dart
- Flutter platform · web/manifest.json
- Flutter platform · Win32Window
- AccountRepository
- image_page.dart
- AdminAuthority
- media_item.dart
- Flutter platform · .MessageHandler()
- DesktopInstallTests
- CredentialStore
- test_account_proxy.py
- Flutter Core · pick_reference_images.dart
- List
- save_media.dart
- String?
- Client
- Client
- get_muse_cookie.py
- desktop_runtime_paths.dart
- Flutter platform · analysis_options.yaml
- Flutter Chat · chat_message.dart
- generate_image.dart
- Flutter Media · media_delete_result.dart
- Flutter platform · Point
- Flutter platform · Size
- Store
- Flutter platform · MainActivity
- Flutter Media · media_name.dart
- test_idempotency_acceptance.py
- test_quota_account_binding.py
- dart:async
- keepalive_status.dart
- test_limits_web.cjs
- HistoryRecordStore
- .test_cancelled_proxy_retains_worker_reservation_at_each_wait
- ConcurrencyLock
- test_reference_media_hardening.py
- keepalive_status_section.dart
- test_parallel_generation_simulation
- prompt_image_loader.dart
- ../../../../core/errors/app_failure.dart
- query_library.dart
- build_tools_prompt
- text_prompt_cubit.dart
- video_bloc.dart
- media_repository_impl.dart
- generation_task.dart
- DesktopLauncherTests
- test_reference_limits.py
- ._wait_attachment
- load_server_status.dart
- _http_exc
- storage_usage.dart
- GenerationIdempotencyMiddleware
- DesktopBuildTests
- .test_maintenance_waiting_gen_lock_and_keepalive_lock_recheck
- batch_keepalive_repository.dart
- VideoBloc
- FixtureProxy
- reference_cubit.dart
- desktop_engine_failure.dart
- add_account
- ImageBloc
- .__init__
- Handler
- _
- _RefImageHTTPHandler
- backend
- .test_cancelled_workers_ignore_untrusted_result_path
- test_admin_base_url.py
- AccountCipher
- save_library.dart
- ProtectionReviewTests
- CiBackendTests

## God Nodes (most connected - your core abstractions)
1. `Store` - 80 edges
2. `MuseEngine` - 70 edges
3. `Config` - 57 edges
4. `ConnectionBloc` - 51 edges
5. `_owner()` - 35 edges
6. `MuseGenerationError` - 30 edges
7. `Client` - 26 edges
8. `RuntimeBlockers` - 25 edges
9. `ServerConnection` - 24 edges
10. `_AppShellState` - 23 edges

## Surprising Connections (you probably didn't know these)
- `ProtectionReviewTests` --uses--> `UserStore`  [INFERRED]
  tests/test_protection_review_fixes.py → tenant.py
- `AccountProxyTests` --uses--> `Config`  [INFERRED]
  tests/test_account_proxy.py → config.py
- `ProtectionReviewTests` --uses--> `MuseEngine`  [INFERRED]
  tests/test_protection_review_fixes.py → engine.py
- `ProtectionReviewTests` --uses--> `Store`  [INFERRED]
  tests/test_protection_review_fixes.py → store.py
- `MediaBoundaryTests` --uses--> `MuseEngine`  [INFERRED]
  tests/test_media_boundary.py → engine.py

## Import Cycles
- None detected.

## Communities (206 total, 49 thin omitted)

### Community 0 - "test_admin_layout.py"
Cohesion: 0.13
Nodes (6): CDP, CDPError, http_json(), FakeEngine, find_page_ws(), main()

### Community 1 - "os"
Cohesion: 0.11
Nodes (20): _allowed(), backup(), directory_fd(), _json(), _load(), main(), operator_cipher(), _packet() (+12 more)

### Community 2 - "BaseModel"
Cohesion: 0.08
Nodes (24): _account_proxy(), AccountPatch, AccountProxy, ChatMessage, ChatRequest, create_user(), patch_account(), patch_user() (+16 more)

### Community 3 - "test_video_late_attachment.py"
Cohesion: 0.11
Nodes (8): js_constant(), python_constant(), FakeClock, wait_case(), cases(), load_waiter(), main(), scenario()

### Community 4 - "dependencies.dart"
Cohesion: 0.04
Nodes (22): chatHistory, connectionRepository, connectServer, desktopEngine, forgetConnection, generateImage, generateVideo, getImageTask (+14 more)

### Community 5 - "_owner"
Cohesion: 0.11
Nodes (26): _bounded_maintenance(), asynchronous(), reserve(), synchronous(), cancel_task(), clear_tasks(), del_account(), del_task() (+18 more)

### Community 6 - "images_edits"
Cohesion: 0.11
Nodes (23): _bounded_reference(), build_image_prompt(), build_video_prompt(), create_image_task(), create_video(), _describe_kinds(), _extra_media(), _generic_upload_mime() (+15 more)

### Community 7 - "Store"
Cohesion: 0.12
Nodes (5): _directory_fd(), Store, _write(), RetentionTests, Migration

### Community 8 - "worker"
Cohesion: 0.18
Nodes (11): _account_operation(), _bind_account_proxy(), _clear_account_proxy(), _renew_and_persist(), _run_generation_locked(), _run_generation_reserved(), emit(), worker() (+3 more)

### Community 9 - "migrate_accounts"
Cohesion: 0.09
Nodes (11): RequestLimiter, IntegrationTests, check(), check(), check(), check(), check(), RateTests (+3 more)

### Community 10 - "json"
Cohesion: 0.07
Nodes (8): _read(), wait(), Response, fixture(), api_checks(), fake_proxy(), fixture(), Server

### Community 11 - "subprocess"
Cohesion: 0.23
Nodes (9): _detect_chromium(), build_engine(), copy_setup_resources(), engine_bundle_ready(), main(), run(), source_fingerprint(), main() (+1 more)

### Community 12 - "test_account_proxy.py"
Cohesion: 0.07
Nodes (9): HTTPProxyRelay, normalize_server(), public_proxy(), _RelayServer, request_proxies(), request_proxy_context(), split_proxy_url(), browser_checks() (+1 more)

### Community 13 - "test_ref_image_safety.py"
Cohesion: 0.12
Nodes (5): box(), FakeForm, FakeMultipart, FakeUpload, mp4()

### Community 14 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.04
Nodes (39): apiError, enhance, timeout, main, main, act, batch, bloc (+31 more)

### Community 15 - "media_page.dart"
Cohesion: 0.08
Nodes (17): build, _cancelSave, _changeQuery, _confirming, createState, dispose, _newest, _save (+9 more)

### Community 16 - "dependencies"
Cohesion: 0.06
Nodes (30): enable-swift-package-manager, dependencies, bloc, crypto, cupertino_icons, desktop_drop, file_selector, flutter (+22 more)

### Community 18 - "desktop_connection_test.dart"
Cohesion: 0.07
Nodes (28): cancelInstall, cancellation, cancellations, exits, fail, forgetConnection, install, installation (+20 more)

### Community 19 - "Browser extension · run()"
Cohesion: 0.20
Nodes (12): applyLang(), ESSENTIAL, grabCookies(), I18N_EN, I18N_EN_HTML, I18N_EN_PATTERNS, LANG, log() (+4 more)

### Community 20 - "_check_update_sync"
Cohesion: 0.11
Nodes (17): _acquire_runtime_lock(), admin_repo_push(), _do_push(), admin_upgrade_now(), _check_update_sync(), _ensure_git_repo(), _git(), _installed_sha_file() (+9 more)

### Community 21 - "Backend tests · makeApi()"
Cohesion: 0.09
Nodes (14): body, end, here, html, lastBrace, start, assert, context (+6 more)

### Community 22 - "json"
Cohesion: 0.07
Nodes (7): _load_dotenv(), load_accounts(), StorageQuotaExceeded, deny(), guarded_popen(), LoggingTests, main()

### Community 23 - "task_repository_impl.dart"
Cohesion: 0.09
Nodes (14): JsonApiClient, api, _json, save, test, api, load, api (+6 more)

### Community 24 - "../errors/app_failure.dart"
Cohesion: 0.15
Nodes (9): request, capability, endpoint, mediaUri, parameters, plain, protectedMediaUri, replace (+1 more)

### Community 25 - "engine.py"
Cohesion: 0.10
Nodes (9): _mp4_duration(), checked(), _NoRefImageRedirect, _open_public_ref_image(), RefImageSafetyError, _sniff_mime(), _webm_duration(), elements() (+1 more)

### Community 26 - "media_bloc.dart"
Cohesion: 0.09
Nodes (32): _select, close, CollectionBloc, CollectionCleared, CollectionEvent, CollectionLoaded, CollectionPaused, CollectionState (+24 more)

### Community 27 - "Tools · showPanel()"
Cohesion: 0.36
Nodes (12): checkSessionStatus(), executePush(), getCookies(), loadCfg(), mountFloatingTrigger(), normBase(), saveCfg(), showPanel() (+4 more)

### Community 28 - "package:muse_app/features/connection/domain/entities/server_connection.dart"
Cohesion: 0.07
Nodes (18): main, open, main, server, source, main, connection, main (+10 more)

### Community 31 - "ChatBloc"
Cohesion: 0.29
Nodes (18): didChangeAppLifecycleState, ChatBloc, ChatCleared, ChatEvent, ChatHistoryFlushed, ChatSessionChanged, ChatStopped, ChatSubmitted (+10 more)

### Community 32 - "Project configuration · muse2api"
Cohesion: 0.17
Nodes (11): build, container_name, environment, image, ports, restart, shm_size, volumes (+3 more)

### Community 34 - "ServerConnection"
Cohesion: 0.07
Nodes (22): AppFailure, message, toString, ServerConnection, connection, main, server, body (+14 more)

### Community 35 - "Browser extension · extension/manifest.json"
Cohesion: 0.18
Nodes (10): action, default_popup, default_title, default_locale, description, host_permissions, manifest_version, name (+2 more)

### Community 36 - "desktop_engine_io.dart"
Cohesion: 0.09
Nodes (20): cancelInstall, _connection, createDesktopEngine, dataDirectory, executable, _exits, _generation, install (+12 more)

### Community 37 - "muse_account.dart"
Cohesion: 0.09
Nodes (17): enabled, expiresAt, extraExpires, extraLeft, extraRemaining, extraUsed, healthy, id (+9 more)

### Community 38 - "Flutter platform · AppDelegate"
Cohesion: 0.07
Nodes (11): Cocoa, Flutter, FlutterMacOS, AppDelegate, SceneDelegate, RunnerTests, AppDelegate, MainFlutterWindow (+3 more)

### Community 39 - "AccountProxyTests"
Cohesion: 0.16
Nodes (4): AccountPoolManager, MuseAuthError, MuseProxyError, test_account_pool_manager()

### Community 40 - "account_batch_keepalive_page_test.dart"
Cohesion: 0.05
Nodes (29): ensureVisible, keepaliveStatus, main, mount, open, pump, pumpAndSettle, pumpWidget (+21 more)

### Community 41 - "library_batch_saver_io.dart"
Cohesion: 0.07
Nodes (19): select, _busy, createLibrarySaver, NativeLibrarySaver, save, createLibrarySaver, save, UnsupportedLibrarySaver (+11 more)

### Community 42 - "desktop_engine_process_test.dart"
Cohesion: 0.10
Nodes (17): announced, ChildProcess, errors, exitCode, exited, finish, handshake, input (+9 more)

### Community 43 - "chat_completions"
Cohesion: 0.07
Nodes (25): _as_tool_calls(), _await_generation(), run(), run(), bounded(), build_chat_prompt(), _chat_chunk(), chat_completions() (+17 more)

### Community 44 - "shell.dart"
Cohesion: 0.05
Nodes (17): build, dependencies, AppDependencies, build, _createImage, createState, _createVideo, _destinations (+9 more)

### Community 45 - "account_bloc.dart"
Cohesion: 0.06
Nodes (40): _AppShellState, AccountActed, AccountBloc, AccountCookiesUpdated, AccountEvent, AccountImported, AccountsBatchKeepaliveRequested, AccountsCleared (+32 more)

### Community 46 - "server_connection.dart"
Cohesion: 0.10
Nodes (17): apiKey, attachPrincipal, baseUrl, can, capabilities, endpoint, headers, id (+9 more)

### Community 50 - "media_preview.dart"
Cohesion: 0.10
Nodes (16): build, connection, createState, didUpdateWidget, dispose, _failed, initState, _load (+8 more)

### Community 51 - "image_bloc_test.dart"
Cohesion: 0.04
Nodes (40): ImageRepositoryImpl, ImageRepository, main, connection, create, failPoll, failPost, FakeImages (+32 more)

### Community 53 - "storage_usage_cubit.dart"
Cohesion: 0.08
Nodes (23): StorageRepository, _attempt, bind, _connection, error, loading, refresh, repository (+15 more)

### Community 54 - "Flutter tests · chat_history_test.dart"
Cohesion: 0.06
Nodes (26): cancelled, cancelling, completed, delete, deleted, deleting, fail, finished (+18 more)

### Community 55 - "generation_recovery_cubit.dart"
Cohesion: 0.08
Nodes (17): close, connect, connection, image, images, RecoveryEntry, refresh, retry (+9 more)

### Community 56 - "Flutter Chat · chat_bloc.dart"
Cohesion: 0.07
Nodes (23): activeId, ChatState, close, _closing, connection, error, generation, history (+15 more)

### Community 57 - "media_delete_bloc_test.dart"
Cohesion: 0.06
Nodes (22): main, calls, done, main, save, start, a, b (+14 more)

### Community 58 - "image_prompt_page.dart"
Cohesion: 0.13
Nodes (16): ImagePromptCubit, ImagePromptState, build, _copy, createState, _dragging, _drop, ImagePromptPage (+8 more)

### Community 59 - "image_prompt_repository_test.dart"
Cohesion: 0.11
Nodes (14): ClosingClient, close, closed, ClosingClient, image, main, send, calls (+6 more)

### Community 60 - "Flutter platform · _MyApplication"
Cohesion: 0.10
Nodes (13): main(), first_frame_cb(), my_application_activate(), my_application_class_init(), my_application_dispose(), my_application_init(), my_application_local_command_line(), my_application_new() (+5 more)

### Community 61 - "media_save_button.dart"
Cohesion: 0.15
Nodes (14): SaveMedia, build, _busy, _bytes, _cancelled, createState, didUpdateWidget, dispose (+6 more)

### Community 62 - "desktop_install_panel_test.dart"
Cohesion: 0.10
Nodes (16): ConnectServer, Connect, app, calls, cancelInstall, install, main, noSuchMethod (+8 more)

### Community 63 - "account_quota_section.dart"
Cohesion: 0.25
Nodes (6): MuseAccount, account, build, _percentage, _text, _usage

### Community 64 - "connection_bloc.dart"
Cohesion: 0.07
Nodes (42): address, apiKey, attempt, _cancelInstallation, close, connect, connection, ConnectionBloc (+34 more)

### Community 65 - "Flutter Accounts · proxy_editor.dart"
Cohesion: 0.10
Nodes (20): ManageProxy, account, build, _clearPassword, _configuration, connection, createState, didUpdateWidget (+12 more)

### Community 66 - "Flutter Images · image_bloc.dart"
Cohesion: 0.08
Nodes (22): _accept, admissionUncertain, busy, close, connection, connectionChanged, discardUncertain, error (+14 more)

### Community 67 - "Flutter platform · WindowClassRegistrar"
Cohesion: 0.14
Nodes (8): EnableNonClientDpiScaling, Scale(), Win32Window::Win32Window(), WindowClassRegistrar, class_registered_, WindowClassRegistrar::GetWindowClass(), instance_, WindowClassRegistrar::UnregisterWindowClass()

### Community 68 - "install.py"
Cohesion: 0.31
Nodes (10): copy_sources(), install(), main(), protocol(), publish_runtime(), run_step(), setup_lock(), SetupError (+2 more)

### Community 69 - "account_repository_impl.dart"
Cohesion: 0.12
Nodes (11): act, api, implements, import, keepaliveAll, keepaliveStatus, list, _statusCount (+3 more)

### Community 70 - "server_status.dart"
Cohesion: 0.17
Nodes (10): browserRunning, disabledAccounts, enabledAccounts, errorAccounts, expiredAccounts, expiringAccounts, healthyAccounts, mediaCount (+2 more)

### Community 71 - "task_bloc.dart"
Cohesion: 0.08
Nodes (27): GenerationTask, close, connection, deleting, _generation, id, load, matches (+19 more)

### Community 72 - "cookie_import_form.dart"
Cohesion: 0.14
Nodes (12): build, busy, CookieImportForm, _CookieImportFormState, _cookies, createState, dispose, _focus (+4 more)

### Community 73 - "status_page_test.dart"
Cohesion: 0.06
Nodes (23): main, preferences, batch, main, a, b, bloc, calls (+15 more)

### Community 74 - "secure_credential_store.dart"
Cohesion: 0.13
Nodes (8): delete, _key, read, storage, write, read, storage, write

### Community 75 - "Flutter Media · delete_media.dart"
Cohesion: 0.13
Nodes (12): MediaRepositoryImpl, deleteBatch, deleteSingle, list, MediaRepository, call, DeleteMedia, repository (+4 more)

### Community 76 - "Project configuration · generated_plugin_registrant"
Cohesion: 0.11
Nodes (4): FlutterWindow, flutter_controller_, FlutterWindow::FlutterWindow(), project_

### Community 78 - "task_delete_bloc_test.dart"
Cohesion: 0.08
Nodes (18): a, b, calls, cancel, clear, delete, failure, items (+10 more)

### Community 79 - "Flutter Chat · chat_page.dart"
Cohesion: 0.12
Nodes (11): bloc, build, showChatHistory, build, createState, dispose, _input, onConfigure (+3 more)

### Community 80 - "../../../connection/domain/entities/server_connection.dart"
Cohesion: 0.11
Nodes (14): TaskRepositoryImpl, cancel, clear, delete, list, TaskRepository, call, LoadTasks (+6 more)

### Community 81 - "Flutter Chat · chat_history_repository_impl.dart"
Cohesion: 0.17
Nodes (8): delete, _key, list, _queue, _read, save, store, _write

### Community 82 - "connection_repository.dart"
Cohesion: 0.11
Nodes (15): ConnectionRepositoryImpl, ConnectionRepository, forgetConnection, readSavedConnection, saveConnection, savedAddress, verify, call (+7 more)

### Community 83 - "launcher.py"
Cohesion: 0.22
Nodes (7): bootstrap(), browser_path(), EngineInUseError, instance_lock(), main(), protocol(), serve()

### Community 84 - "package:flutter_bloc/flutter_bloc.dart"
Cohesion: 0.06
Nodes (12): main, generate, main, requests, bytes, length, main, name (+4 more)

### Community 85 - "valid_media_name"
Cohesion: 0.17
Nodes (11): _capability_state(), worker(), delete_media(), get_media(), __call__(), _media_capability(), worker(), _on_acquired() (+3 more)

### Community 86 - "../../../../core/errors/app_failure.dart"
Cohesion: 0.14
Nodes (9): ConnectionRemoteDataSource, verify, forgetConnection, local, readSavedConnection, remote, saveConnection, savedAddress (+1 more)

### Community 87 - "Flutter Chat · manage_chat_history.dart"
Cohesion: 0.13
Nodes (12): ChatHistoryRepositoryImpl, ChatHistoryRepository, delete, list, save, delete, list, ManageChatHistory (+4 more)

### Community 88 - "Flutter Core · generation_workspace.dart"
Cohesion: 0.12
Nodes (14): MuseApp, build, busy, child, description, form, GenerationPreview, GenerationWorkspace (+6 more)

### Community 89 - "app.py"
Cohesion: 0.07
Nodes (30): admin_check_update(), _admin_html(), admin_media(), admin_page(), admin_status(), admin_tasks(), aggregate_operations(), cookie_helper() (+22 more)

### Community 90 - "list_header.dart"
Cohesion: 0.20
Nodes (8): build, d, error, formatDate, loading, onRefresh, title, two

### Community 91 - "Flutter Accounts · _"
Cohesion: 0.13
Nodes (15): _, exitIp, hasPassword, normalizeServer, parse, passed, password, ProxyConfiguration (+7 more)

### Community 92 - "bool get"
Cohesion: 0.15
Nodes (9): createDesktopEngine, start, stop, supported, unexpectedExit, start, stop, supported (+1 more)

### Community 93 - "connection_local_data_source.dart"
Cohesion: 0.18
Nodes (8): address, _addressKey, ConnectionLocalDataSource, credentials, forgetConnection, preferences, readConnection, saveConnection

### Community 94 - "server_status_bloc.dart"
Cohesion: 0.11
Nodes (15): busy, connection, connectionChanged, error, _generation, load, refresh, ServerStatusBloc (+7 more)

### Community 95 - "Project configuration · string"
Cohesion: 0.19
Nodes (4): wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16()

### Community 96 - "MuseEngine"
Cohesion: 0.12
Nodes (3): MuseEngine, MuseGenerationError, AccountProxyTests

### Community 97 - "._write_accounts"
Cohesion: 0.15
Nodes (4): account_expiry(), _is_pos(), min_expiry(), test_maintenance_selection_does_not_count_as_use()

### Community 98 - "Flutter Chat · send_message.dart"
Cohesion: 0.17
Nodes (9): ChatRepositoryImpl, ChatRepository, streamReply, call, repository, SendMessage, FakeChatRepository, DelayedCancellationReplies (+1 more)

### Community 99 - "desktop_engine_installer_io.dart"
Cohesion: 0.15
Nodes (9): cancelInstall, _generation, install, _installing, _process, _python, _setupRoot, sourceRoot (+1 more)

### Community 100 - "chat_bloc_test.dart"
Cohesion: 0.15
Nodes (7): calls, cancelled, connection, history, reply, streamReply, tick

### Community 101 - "Flutter Accounts · proxy_bloc.dart"
Cohesion: 0.17
Nodes (18): ProxyCheck, accountId, busy, check, configuration, connection, error, manage (+10 more)

### Community 102 - "Flutter Accounts · manage_proxy.dart"
Cohesion: 0.18
Nodes (8): ProxyRepositoryImpl, ProxyRepository, save, test, repository, save, test, Proxy

### Community 103 - "DesktopEngine"
Cohesion: 0.17
Nodes (11): ProcessDesktopInstaller, ProcessDesktopEngine, UnsupportedDesktopEngine, DesktopEngine, cancelInstall, DesktopEngineInstaller, DesktopInstallStage, install (+3 more)

### Community 104 - "manage_accounts.dart"
Cohesion: 0.12
Nodes (10): AccountAction, act, import, list, act, import, list, ManageAccounts (+2 more)

### Community 105 - "Flutter Core · reference_image.dart"
Cohesion: 0.10
Nodes (17): bytes, fingerprint, fromBytes, maxFileBytes, maxFiles, maxTotalBytes, mime, name (+9 more)

### Community 106 - "pending_generation_store.dart"
Cohesion: 0.15
Nodes (12): id, _key, kind, list, PendingGeneration, PendingGenerationStore, preferences, _queue (+4 more)

### Community 107 - "Flutter Accounts · cookie_update_dialog.dart"
Cohesion: 0.12
Nodes (14): build, _cookies, CookieUpdateDialog, _CookieUpdateDialogState, createState, dispose, _error, onSubmit (+6 more)

### Community 108 - "chat_repository_impl.dart"
Cohesion: 0.20
Nodes (4): ChatMessageModel, toJson, remote, streamReply

### Community 109 - "generation_task_decoder.dart"
Cohesion: 0.17
Nodes (9): created, decodeTask, filename, id, progress, resolvedFilename, result, status (+1 more)

### Community 110 - "video_page.dart"
Cohesion: 0.11
Nodes (14): build, createState, dispose, _duration, _focus, _form, initState, onConfigure (+6 more)

### Community 112 - "UserStore"
Cohesion: 0.20
Nodes (7): _hash_key(), shared_transaction(), wrapped(), UserStore, _write(), sync(), SharedUsers

### Community 113 - "studio_theme.dart"
Cohesion: 0.17
Nodes (11): accent, border, canvas, muted, raised, selected, StudioColors, StudioTheme (+3 more)

### Community 116 - "image_prompt_cubit.dart"
Cohesion: 0.09
Nodes (18): generate, ImagePromptRepositoryImpl, timeout, generate, ImagePromptRepository, clear, _current, error (+10 more)

### Community 117 - "Flutter platform · web/manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 118 - "Flutter platform · Win32Window"
Cohesion: 0.24
Nodes (4): Win32Window, child_content_, quit_on_close_, window_handle_

### Community 119 - "AccountRepository"
Cohesion: 0.19
Nodes (12): AccountRepositoryImpl, AccountCookiesRepository, AccountRepository, BatchKeepaliveRepository, KeepaliveStatusRepository, BatchRepo, PageRepo, CookiesRepo (+4 more)

### Community 120 - "image_page.dart"
Cohesion: 0.11
Nodes (14): build, createState, didUpdateWidget, dispose, _form, initialPrompt, initState, onConfigure (+6 more)

### Community 121 - "AdminAuthority"
Cohesion: 0.30
Nodes (4): rotate_apikey(), AdminAuthority, AdminEpochTests, AuthorityPersistenceTests

### Community 122 - "media_item.dart"
Cohesion: 0.25
Nodes (5): bytes, createdAt, isVideo, name, protectedUri

### Community 125 - "CredentialStore"
Cohesion: 0.25
Nodes (7): CredentialStore, delete, read, write, SecureCredentialStore, MemoryCredentialStore, FixtureCredentials

### Community 126 - "test_account_proxy.py"
Cohesion: 0.11
Nodes (10): request(), ui_checks(), test_keepalive_only_runs_when_due(), Response, addresses(), check(), check_endpoints(), expect_error() (+2 more)

### Community 128 - "Flutter Core · pick_reference_images.dart"
Cohesion: 0.25
Nodes (6): DeviceReferenceFileSource, call, ReferenceFileSource, select, source, FakeFiles

### Community 129 - "List"
Cohesion: 0.18
Nodes (7): GenerationRecoveryCubit, build, GenerationRecoveryPanel, ChatThread, id, messages, updatedAt

### Community 130 - "save_media.dart"
Cohesion: 0.09
Nodes (17): NativeMediaSaver, UnsupportedMediaSaver, bytes, connection, image, MediaSaver, MediaSaveResult, MediaSaveSource (+9 more)

### Community 131 - "String?"
Cohesion: 0.10
Nodes (17): AppShell, AccountPage, _ProxyForm, ChatPage, _address, build, ConnectionPage, createState (+9 more)

### Community 132 - "Client"
Cohesion: 0.11
Nodes (4): check(), Client, RouteTests, start()

### Community 134 - "get_muse_cookie.py"
Cohesion: 0.11
Nodes (15): Browser, find_chrome(), fmt_ts(), init_console(), main(), say(), upload(), wait_cdp() (+7 more)

### Community 135 - "desktop_runtime_paths.dart"
Cohesion: 0.20
Nodes (8): data, desktopDataDirectory, desktopResourceDirectory, env, home, installedRuntimeDirectory, parent, runtimeExecutable

### Community 136 - "Flutter platform · analysis_options.yaml"
Cohesion: 0.33
Nodes (5): analyzer, exclude, include, linter, rules

### Community 137 - "Flutter Chat · chat_message.dart"
Cohesion: 0.40
Nodes (4): ChatMessage, content, MessageRole, role

### Community 138 - "generate_image.dart"
Cohesion: 0.33
Nodes (4): call, GenerateImage, GetImageTask, repository

### Community 139 - "Flutter Media · media_delete_result.dart"
Cohesion: 0.50
Nodes (3): errorCount, MediaDeleteResult, removed

### Community 140 - "Flutter platform · Point"
Cohesion: 0.50
Nodes (3): Point, x, y

### Community 141 - "Flutter platform · Size"
Cohesion: 0.50
Nodes (3): Size, height, width

### Community 151 - "test_idempotency_acceptance.py"
Cohesion: 0.16
Nodes (9): GenerationIdempotencyMiddleware, Capacity, Conflict, GenerationLedger, _RelayHandler, AdmissionFailureTests, FairCapacityTests, LedgerInitializationTests (+1 more)

### Community 153 - "dart:async"
Cohesion: 0.04
Nodes (40): bind, SseDecoder, b, batchBusy, batches, batchLoaded, batchPending, cookiePending (+32 more)

### Community 154 - "keepalive_status.dart"
Cohesion: 0.17
Nodes (11): attempts, busy, checkedAt, failures, lastResult, lastRun, nextRun, running (+3 more)

### Community 155 - "test_limits_web.cjs"
Cohesion: 0.06
Nodes (25): assert, c, calls, fs, html, limits, nodes, source (+17 more)

### Community 156 - "HistoryRecordStore"
Cohesion: 0.25
Nodes (7): HistoryRecordStore, read, write, SecureHistoryRecordStore, MemoryHistory, MemoryStatusHistoryStore, FixtureHistory

### Community 157 - ".test_cancelled_proxy_retains_worker_reservation_at_each_wait"
Cohesion: 0.31
Nodes (7): get(), operation(), renew(), wait(), get(), invalidate(), proxy_context()

### Community 159 - "test_reference_media_hardening.py"
Cohesion: 0.38
Nodes (4): data_url(), element(), reject(), webm()

### Community 161 - "keepalive_status_section.dart"
Cohesion: 0.12
Nodes (14): KeepaliveStatus, busy, connection, error, KeepaliveStatusBloc, KeepaliveStatusState, refresh, repository (+6 more)

### Community 163 - "prompt_image_loader.dart"
Cohesion: 0.33
Nodes (3): load, maxBytes, PromptImageLoader

### Community 164 - "../../../../core/errors/app_failure.dart"
Cohesion: 0.11
Nodes (9): ChatRemoteDataSource, streamReply, create, ImageRemoteDataSource, _request, fromJson, ImageTaskModel, create (+1 more)

### Community 165 - "query_library.dart"
Cohesion: 0.22
Nodes (8): indexed, LibraryType, map, needle, newest, queryLibrary, search, type

### Community 167 - "text_prompt_cubit.dart"
Cohesion: 0.06
Nodes (31): TextPromptRepositoryImpl, enhance, TextPromptRepository, clear, _current, edit, error, generate (+23 more)

### Community 170 - "video_bloc.dart"
Cohesion: 0.08
Nodes (22): _accept, admissionUncertain, busy, close, connection, duration, error, generate (+14 more)

### Community 171 - "media_repository_impl.dart"
Cohesion: 0.18
Nodes (5): api, deleteBatch, deleteSingle, list, loadStorage

### Community 172 - "generation_task.dart"
Cohesion: 0.18
Nodes (10): createdAt, filename, GenerationStatus, id, kind, progress, prompt, protectedUri (+2 more)

### Community 174 - "test_reference_limits.py"
Cohesion: 0.11
Nodes (4): FakeForm, FakeJSONRequest, FakeMultipartRequest, FakeUpload

### Community 176 - "load_server_status.dart"
Cohesion: 0.20
Nodes (7): ServerStatusRepositoryImpl, load, ServerStatusRepository, call, LoadServerStatus, repository, PendingStatusRepository

### Community 177 - "_http_exc"
Cohesion: 0.29
Nodes (4): _err_type(), _http_exc(), storage_quota_error(), _validation_exc()

### Community 180 - "storage_usage.dart"
Cohesion: 0.29
Nodes (6): bytes, files, limitBytes, limitFiles, retentionDays, StorageUsage

### Community 183 - ".test_maintenance_waiting_gen_lock_and_keepalive_lock_recheck"
Cohesion: 0.38
Nodes (3): __aenter__(), __enter__(), invalidate()

### Community 185 - "batch_keepalive_repository.dart"
Cohesion: 0.14
Nodes (8): KeepaliveSummary, updateCookies, BatchKeepaliveResult, busy, keepaliveAll, summary, keepaliveStatus, loadStorage

### Community 186 - "VideoBloc"
Cohesion: 0.37
Nodes (13): _resumeVideo, VideoAdmissionRetried, VideoBloc, VideoEvent, _VideoPolled, VideoPollingRetried, VideoRequested, VideoResumed (+5 more)

### Community 188 - "reference_cubit.dart"
Cohesion: 0.10
Nodes (17): PickReferenceImages, referencePayload, error, images, loading, move, pick, pickImages (+9 more)

### Community 190 - "desktop_engine_failure.dart"
Cohesion: 0.29
Nodes (6): code, DesktopEngineFailure, DesktopEngineFailureCode, fromInstallProtocol, fromProtocol, message

### Community 192 - "add_account"
Cohesion: 0.25
Nodes (6): AccountRequest, add_account(), parse_batch(), parse_cookie_text(), _pos(), update_cookies()

### Community 195 - "ImageBloc"
Cohesion: 0.47
Nodes (11): ImageAdmissionRetried, ImageBloc, ImageEvent, _ImagePolled, ImagePollingRetried, ImageRequested, ImagesCleared, _ImagePageState (+3 more)

### Community 202 - "_"
Cohesion: 0.22
Nodes (9): _, accountCount, AccountImportDraft, _hasCookies, isBatch, label, parse, text (+1 more)

### Community 205 - "backend"
Cohesion: 0.07
Nodes (27): env, name, runs-on, steps, timeout-minutes, concurrency, cancel-in-progress, group (+19 more)

### Community 210 - "test_admin_base_url.py"
Cohesion: 0.29
Nodes (3): build_cmd(), check(), Response

### Community 215 - "AccountCipher"
Cohesion: 0.13
Nodes (5): AccountCipher, migrate_accounts(), main(), Response, main()

### Community 216 - "save_library.dart"
Cohesion: 0.29
Nodes (5): LibrarySaveEntry, LibrarySaveStatus, name, save, status

## Knowledge Gaps
- **1207 isolated node(s):** `calls`, `cancelled`, `connection`, `history`, `reply` (+1202 more)
  These have ≤1 connection - possible missing edges. (Counts symbols only; 2047 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **49 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `ServerConnection` connect `ServerConnection` to `save_media.dart`, `media_page.dart`, `desktop_connection_test.dart`, `media_bloc.dart`, `keepalive_status_section.dart`, `desktop_engine_io.dart`, `video_bloc.dart`, `account_bloc.dart`, `server_connection.dart`, `media_preview.dart`, `storage_usage_cubit.dart`, `generation_recovery_cubit.dart`, `Flutter Chat · chat_bloc.dart`, `connection_bloc.dart`, `Flutter Accounts · proxy_editor.dart`, `Flutter Images · image_bloc.dart`, `task_bloc.dart`, `server_status_bloc.dart`, `Flutter Accounts · proxy_bloc.dart`?**
  _High betweenness centrality (0.033) - this node is a cross-community bridge._
- **Are the 4 inferred relationships involving `Store` (e.g. with `AccountProxyTests` and `MediaBoundaryTests`) actually correct?**
  _`Store` has 4 INFERRED edges - model-reasoned connections that need verification._
- **What connects `calls`, `cancelled`, `connection` to the rest of the system?**
  _1207 weakly-connected nodes found - possible missing edges._
- **Should `test_admin_layout.py` be split into smaller, more focused modules?**
  _Cohesion score 0.12648221343873517 - nodes in this community are weakly interconnected._
- **Why does `RuntimeBlockers` connect `RuntimeBlockers` to `.test_video_cancel_clear_does_not_free_reservations`, `.test_cancelled_proxy_retains_worker_reservation_at_each_wait`, `json`, `.test_maintenance_waiting_gen_lock_and_keepalive_lock_recheck`?**
  _High betweenness centrality (0.026) - this node is a cross-community bridge._
- **Are the 3 inferred relationships involving `MuseEngine` (e.g. with `AccountProxyTests` and `MediaBoundaryTests`) actually correct?**
  _`MuseEngine` has 3 INFERRED edges - model-reasoned connections that need verification._
- **Should `os` be split into smaller, more focused modules?**
  _Cohesion score 0.10707070707070707 - nodes in this community are weakly interconnected._