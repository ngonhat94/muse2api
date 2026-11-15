# Graph Report - muse2api  (2026-11-15)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 3689 nodes · 6947 edges · 218 communities (158 shown, 60 thin omitted)
- Extraction: 96% EXTRACTED · 4% INFERRED · 0% AMBIGUOUS · INFERRED: 286 edges (avg confidence: 0.86)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `b60f4749`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- test_admin_layout.py
- os
- app.py
- test_video_late_attachment.py
- dependencies.dart
- _owner
- images_edits
- Store
- MuseAuthError
- migrate_accounts
- BaseModel
- subprocess
- test_account_proxy.py
- test_ref_image_safety.py
- package:flutter_test/flutter_test.dart
- media_page.dart
- dependencies
- MuseEngine
- desktop_connection_test.dart
- Browser extension · run()
- _check_update_sync
- Backend tests · makeApi()
- json
- task_repository_impl.dart
- ../errors/app_failure.dart
- test_reference_media_hardening.py
- task_bloc.dart
- Tools · showPanel()
- package:muse_app/features/connection/domain/entities/server_connection.dart
- RuntimeBlockers
- .write_media
- ChatBloc
- Project configuration · muse2api
- Backend tests · Client
- connection_bloc_test.dart
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
- reference_images_test.dart
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
- account_repository_impl.dart
- connection_bloc.dart
- Flutter Accounts · proxy_editor.dart
- Flutter Images · image_bloc.dart
- Flutter platform · WindowClassRegistrar
- install.py
- keepalive_status_bloc.dart
- server_status.dart
- MuseGenerationError
- cookie_import_form.dart
- status_page_test.dart
- secure_history_record_store.dart
- Flutter Media · delete_media.dart
- Project configuration · generated_plugin_registrant
- WS
- task_delete_bloc_test.dart
- Flutter Chat · chat_page.dart
- task_repository.dart
- Flutter Chat · chat_history_repository_impl.dart
- connection_repository.dart
- media_saver_io.dart
- package:flutter_bloc/flutter_bloc.dart
- valid_media_name
- ../../../../core/errors/app_failure.dart
- Flutter Chat · manage_chat_history.dart
- Flutter Core · generation_workspace.dart
- account_page.dart
- list_header.dart
- Flutter Accounts · _
- bool get
- text_prompt_page.dart
- Flutter Status · load_server_status.dart
- Project configuration · string
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
- AccountBloc
- generation_task_decoder.dart
- video_page.dart
- Backend tests · QuotaLocalizationTests
- studio_theme.dart
- AccountCipher
- text_prompt_cubit_test.dart
- image_prompt_cubit.dart
- Flutter platform · web/manifest.json
- Flutter platform · Win32Window
- batch_keepalive_repository.dart
- image_page.dart
- package:flutter_test/flutter_test.dart
- reference_cubit.dart
- Flutter platform · .MessageHandler()
- DesktopInstallTests
- media_bloc.dart
- test_ref_image_safety.py
- Flutter Core · pick_reference_images.dart
- video_bloc_test.dart
- save_media.dart
- String?
- Client
- Client
- get_muse_cookie.py
- desktop_runtime_paths.dart
- Flutter platform · analysis_options.yaml
- Flutter Chat · chat_message.dart
- ../../../../core/domain/reference_image.dart
- Flutter Media · media_delete_result.dart
- Flutter platform · Point
- Flutter platform · Size
- Store
- Flutter platform · MainActivity
- Flutter Media · media_name.dart
- keepalive_status.dart
- test_quota_account_binding.py
- dart:async
- .patch
- test_limits_web.cjs
- image_task.dart
- .test_cancelled_proxy_retains_worker_reservation_at_each_wait
- ConcurrencyLock
- storage_usage_cubit.dart
- chat_repository_impl.dart
- .test_directory_sync_failure_reports_uncertain_publication_without_rewrite
- media_save_button_test.dart
- ../../../../core/errors/app_failure.dart
- query_library.dart
- account_import_test.dart
- text_prompt_cubit.dart
- video_bloc.dart
- media_repository_impl.dart
- generation_task.dart
- DesktopLauncherTests
- test_reference_limits.py
- ._wait_attachment
- HistoryRecordStore
- _http_exc
- secure_credential_store.dart
- media_item.dart
- storage_usage.dart
- RequestLimiter
- DesktopBuildTests
- .test_maintenance_waiting_gen_lock_and_keepalive_lock_recheck
- test_muse_video_delivery.py
- CredentialStore
- chat_history_sheet.dart
- FixtureProxy
- List
- test_browser_context_downloads.py
- desktop_engine_failure.dart
- StorageRepository
- check
- add_account
- .__init__
- run_backend_offline.py
- prompt_image_loader.dart
- Handler
- browser_checks
- _RefImageHTTPHandler
- ConnectServer
- .test_cancelled_workers_ignore_untrusted_result_path
- FakeForm
- Response
- Response
- test_parallel_generation_simulation
- test_keepalive_only_runs_when_due
- Response
- Response
- _load_dotenv
- LoggingTests

## God Nodes (most connected - your core abstractions)
1. `Store` - 79 edges
2. `MuseEngine` - 70 edges
3. `Config` - 56 edges
4. `ConnectionBloc` - 51 edges
5. `MuseGenerationError` - 38 edges
6. `_owner()` - 35 edges
7. `RuntimeBlockers` - 25 edges
8. `ServerConnection` - 24 edges
9. `_AppShellState` - 23 edges
10. `ChatBloc` - 23 edges

## Surprising Connections (you probably didn't know these)
- `AccountProxyTests` --uses--> `Config`  [INFERRED]
  tests/test_account_proxy.py → config.py
- `ProtectionReviewTests` --uses--> `MuseEngine`  [INFERRED]
  tests/test_protection_review_fixes.py → engine.py
- `ProtectionReviewTests` --uses--> `Store`  [INFERRED]
  tests/test_protection_review_fixes.py → store.py
- `ProtectionReviewTests` --uses--> `UserStore`  [INFERRED]
  tests/test_protection_review_fixes.py → tenant.py
- `MediaBoundaryTests` --uses--> `MuseEngine`  [INFERRED]
  tests/test_media_boundary.py → engine.py

## Import Cycles
- None detected.

## Communities (218 total, 60 thin omitted)

### Community 0 - "test_admin_layout.py"
Cohesion: 0.10
Nodes (8): CDP, CDPError, http_json(), wait(), fixture(), FakeEngine, find_page_ws(), main()

### Community 1 - "os"
Cohesion: 0.10
Nodes (20): _allowed(), backup(), directory_fd(), _json(), _load(), main(), operator_cipher(), _packet() (+12 more)

### Community 2 - "app.py"
Cohesion: 0.07
Nodes (29): admin_check_update(), _admin_html(), admin_media(), admin_page(), admin_status(), admin_tasks(), aggregate_operations(), cookie_helper() (+21 more)

### Community 3 - "test_video_late_attachment.py"
Cohesion: 0.09
Nodes (13): bootstrap(), browser_path(), EngineInUseError, instance_lock(), main(), protocol(), serve(), js_constant() (+5 more)

### Community 4 - "dependencies.dart"
Cohesion: 0.04
Nodes (22): chatHistory, connectionRepository, connectServer, desktopEngine, forgetConnection, generateImage, generateVideo, getImageTask (+14 more)

### Community 5 - "_owner"
Cohesion: 0.08
Nodes (36): _account_operation(), _account_proxy(), _bounded_maintenance(), asynchronous(), reserve(), synchronous(), cancel_task(), clear_tasks() (+28 more)

### Community 6 - "images_edits"
Cohesion: 0.11
Nodes (23): _await_generation(), _bounded_reference(), build_image_prompt(), build_video_prompt(), create_image_task(), create_video(), _describe_kinds(), _extra_media() (+15 more)

### Community 7 - "Store"
Cohesion: 0.12
Nodes (4): Store, _write(), StorageTests, Migration

### Community 8 - "MuseAuthError"
Cohesion: 0.10
Nodes (20): _bind_account_proxy(), run(), bounded(), _clear_account_proxy(), OutstandingJob, _pos(), _renew_and_persist(), responses_api() (+12 more)

### Community 9 - "migrate_accounts"
Cohesion: 0.11
Nodes (9): IntegrationTests, check(), check(), check(), check(), check(), Client, DashboardTests (+1 more)

### Community 10 - "BaseModel"
Cohesion: 0.09
Nodes (15): AccountPatch, AccountProxy, ChatMessage, ChatRequest, patch_account(), patch_user(), _proxy_test_identity(), _responses_messages() (+7 more)

### Community 11 - "subprocess"
Cohesion: 0.24
Nodes (9): _detect_chromium(), build_engine(), copy_setup_resources(), engine_bundle_ready(), main(), run(), source_fingerprint(), main() (+1 more)

### Community 12 - "test_account_proxy.py"
Cohesion: 0.07
Nodes (12): _NoRefImageRedirect, _open_public_ref_image(), HTTPProxyRelay, normalize_server(), public_proxy(), _RelayServer, request_proxies(), request_proxy_context() (+4 more)

### Community 13 - "test_ref_image_safety.py"
Cohesion: 0.10
Nodes (7): ui_checks(), box(), data_url(), FakeForm, FakeMultipart, FakeUpload, mp4()

### Community 14 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.05
Nodes (29): generate, timeout, enhance, timeout, main, main, main, server (+21 more)

### Community 15 - "media_page.dart"
Cohesion: 0.06
Nodes (22): build, _cancelSave, _changeQuery, _confirming, createState, dispose, _newest, _save (+14 more)

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
Cohesion: 0.10
Nodes (18): _acquire_runtime_lock(), admin_repo_push(), _do_push(), admin_upgrade_now(), _check_update_sync(), _ensure_git_repo(), _git(), _installed_sha_file() (+10 more)

### Community 21 - "Backend tests · makeApi()"
Cohesion: 0.09
Nodes (14): body, end, here, html, lastBrace, start, assert, context (+6 more)

### Community 22 - "json"
Cohesion: 0.07
Nodes (10): load_accounts(), migrate_accounts(), StorageQuotaExceeded, _read(), renew(), fixture(), main(), account() (+2 more)

### Community 23 - "task_repository_impl.dart"
Cohesion: 0.09
Nodes (15): api, cancel, clear, delete, list, api, create, VideoRepositoryImpl (+7 more)

### Community 24 - "../errors/app_failure.dart"
Cohesion: 0.11
Nodes (12): apiError, JsonApiClient, request, capability, endpoint, mediaUri, parameters, plain (+4 more)

### Community 25 - "test_reference_media_hardening.py"
Cohesion: 0.16
Nodes (8): _mp4_duration(), _webm_duration(), elements(), vint(), data_url(), element(), reject(), webm()

### Community 26 - "task_bloc.dart"
Cohesion: 0.07
Nodes (47): _AppShellState, _select, GenerationTask, close, CollectionBloc, CollectionCleared, CollectionEvent, CollectionLoaded (+39 more)

### Community 27 - "Tools · showPanel()"
Cohesion: 0.36
Nodes (12): checkSessionStatus(), executePush(), getCookies(), loadCfg(), mountFloatingTrigger(), normBase(), saveCfg(), showPanel() (+4 more)

### Community 28 - "package:muse_app/features/connection/domain/entities/server_connection.dart"
Cohesion: 0.09
Nodes (14): main, server, source, main, connection, main, connection, main (+6 more)

### Community 30 - ".write_media"
Cohesion: 0.13
Nodes (3): _directory_fd(), RetentionTests, MediaBoundaryTests

### Community 31 - "ChatBloc"
Cohesion: 0.29
Nodes (18): didChangeAppLifecycleState, ChatBloc, ChatCleared, ChatEvent, ChatHistoryFlushed, ChatSessionChanged, ChatStopped, ChatSubmitted (+10 more)

### Community 32 - "Project configuration · muse2api"
Cohesion: 0.17
Nodes (11): build, container_name, environment, image, ports, restart, shm_size, volumes (+3 more)

### Community 33 - "Backend tests · Client"
Cohesion: 0.18
Nodes (3): build_cmd(), check(), Client

### Community 34 - "connection_bloc_test.dart"
Cohesion: 0.08
Nodes (18): AppFailure, message, toString, body, close, closed, connection, main (+10 more)

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

### Community 40 - "account_batch_keepalive_page_test.dart"
Cohesion: 0.07
Nodes (25): ensureVisible, keepaliveStatus, main, mount, open, pump, pumpAndSettle, pumpWidget (+17 more)

### Community 41 - "library_batch_saver_io.dart"
Cohesion: 0.10
Nodes (14): _busy, createLibrarySaver, NativeLibrarySaver, save, createLibrarySaver, save, UnsupportedLibrarySaver, LibrarySaveEntry (+6 more)

### Community 42 - "desktop_engine_process_test.dart"
Cohesion: 0.10
Nodes (17): announced, ChildProcess, errors, exitCode, exited, finish, handshake, input (+9 more)

### Community 43 - "chat_completions"
Cohesion: 0.09
Nodes (14): _as_tool_calls(), build_chat_prompt(), build_tools_prompt(), _chat_chunk(), chat_completions(), run(), sync_stream(), tool_call_deltas() (+6 more)

### Community 44 - "shell.dart"
Cohesion: 0.05
Nodes (17): build, dependencies, AppDependencies, build, _createImage, createState, _createVideo, _destinations (+9 more)

### Community 45 - "account_bloc.dart"
Cohesion: 0.10
Nodes (18): action, batchCompleted, _batchKeepalive, busy, connection, cookies, error, _generation (+10 more)

### Community 46 - "server_connection.dart"
Cohesion: 0.10
Nodes (17): apiKey, attachPrincipal, baseUrl, can, capabilities, endpoint, headers, id (+9 more)

### Community 50 - "media_preview.dart"
Cohesion: 0.10
Nodes (16): build, connection, createState, didUpdateWidget, dispose, _failed, initState, _load (+8 more)

### Community 51 - "reference_images_test.dart"
Cohesion: 0.05
Nodes (27): main, connection, create, failPoll, failPost, FakeImages, keys, pending (+19 more)

### Community 53 - "storage_usage_cubit.dart"
Cohesion: 0.17
Nodes (11): _bind, build, connection, createState, _cubit, didUpdateWidget, dispose, initState (+3 more)

### Community 54 - "Flutter tests · chat_history_test.dart"
Cohesion: 0.06
Nodes (26): cancelled, cancelling, completed, delete, deleted, deleting, fail, finished (+18 more)

### Community 55 - "generation_recovery_cubit.dart"
Cohesion: 0.11
Nodes (13): close, connect, connection, image, images, RecoveryEntry, refresh, retry (+5 more)

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
Cohesion: 0.12
Nodes (11): app, calls, cancelInstall, install, main, noSuchMethod, pending, start (+3 more)

### Community 63 - "account_repository_impl.dart"
Cohesion: 0.09
Nodes (17): act, api, implements, import, keepaliveAll, keepaliveStatus, list, _statusCount (+9 more)

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

### Community 68 - "install.py"
Cohesion: 0.28
Nodes (10): copy_sources(), install(), main(), protocol(), publish_runtime(), run_step(), setup_lock(), SetupError (+2 more)

### Community 69 - "keepalive_status_bloc.dart"
Cohesion: 0.12
Nodes (13): busy, connection, error, KeepaliveStatusBloc, KeepaliveStatusState, refresh, repository, status (+5 more)

### Community 70 - "server_status.dart"
Cohesion: 0.17
Nodes (10): browserRunning, disabledAccounts, enabledAccounts, errorAccounts, expiredAccounts, expiringAccounts, healthyAccounts, mediaCount (+2 more)

### Community 71 - "MuseGenerationError"
Cohesion: 0.14
Nodes (7): AccountPoolManager, _prepare_reference_images(), checked(), MuseGenerationError, RefImageSafetyError, _sniff_mime(), test_account_pool_manager()

### Community 72 - "cookie_import_form.dart"
Cohesion: 0.14
Nodes (12): build, busy, CookieImportForm, _CookieImportFormState, _cookies, createState, dispose, _focus (+4 more)

### Community 73 - "status_page_test.dart"
Cohesion: 0.05
Nodes (21): main, preferences, main, a, b, bloc, calls, load (+13 more)

### Community 74 - "secure_history_record_store.dart"
Cohesion: 0.25
Nodes (3): read, storage, write

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
Cohesion: 0.13
Nodes (10): ChatMessageModel, toJson, build, createState, dispose, _input, onConfigure, onCreateImage (+2 more)

### Community 80 - "task_repository.dart"
Cohesion: 0.15
Nodes (10): TaskRepositoryImpl, cancel, clear, delete, list, TaskRepository, call, LoadTasks (+2 more)

### Community 81 - "Flutter Chat · chat_history_repository_impl.dart"
Cohesion: 0.15
Nodes (8): delete, _key, list, _queue, _read, save, store, _write

### Community 82 - "connection_repository.dart"
Cohesion: 0.11
Nodes (15): ConnectionRepositoryImpl, ConnectionRepository, forgetConnection, readSavedConnection, saveConnection, savedAddress, verify, call (+7 more)

### Community 83 - "media_saver_io.dart"
Cohesion: 0.14
Nodes (12): _busy, createMediaSaver, idleTimeout, NativeMediaSaver, _pick, replaceExisting, save, createMediaSaver (+4 more)

### Community 84 - "package:flutter_bloc/flutter_bloc.dart"
Cohesion: 0.08
Nodes (11): main, generate, main, requests, bytes, length, main, name (+3 more)

### Community 85 - "valid_media_name"
Cohesion: 0.13
Nodes (13): run(), _capability_state(), worker(), delete_media(), get_media(), __call__(), _media_capability(), worker() (+5 more)

### Community 86 - "../../../../core/errors/app_failure.dart"
Cohesion: 0.08
Nodes (17): address, _addressKey, ConnectionLocalDataSource, credentials, forgetConnection, preferences, readConnection, saveConnection (+9 more)

### Community 87 - "Flutter Chat · manage_chat_history.dart"
Cohesion: 0.13
Nodes (12): ChatHistoryRepositoryImpl, ChatHistoryRepository, delete, list, save, delete, list, ManageChatHistory (+4 more)

### Community 88 - "Flutter Core · generation_workspace.dart"
Cohesion: 0.12
Nodes (14): MuseApp, build, busy, child, description, form, GenerationPreview, GenerationWorkspace (+6 more)

### Community 89 - "account_page.dart"
Cohesion: 0.17
Nodes (5): build, createState, initState, _keepaliveDialogOpen, _showImport

### Community 90 - "list_header.dart"
Cohesion: 0.20
Nodes (8): build, d, error, formatDate, loading, onRefresh, title, two

### Community 91 - "Flutter Accounts · _"
Cohesion: 0.12
Nodes (16): _, exitIp, hasPassword, normalizeServer, parse, passed, password, ProxyCheck (+8 more)

### Community 92 - "bool get"
Cohesion: 0.15
Nodes (9): createDesktopEngine, start, stop, supported, unexpectedExit, start, stop, supported (+1 more)

### Community 93 - "text_prompt_page.dart"
Cohesion: 0.13
Nodes (12): TextPromptCubit, TextPromptState, build, _controller, createState, dispose, _focus, initState (+4 more)

### Community 94 - "Flutter Status · load_server_status.dart"
Cohesion: 0.12
Nodes (10): updateCookies, api, load, ServerStatusRepositoryImpl, load, ServerStatusRepository, call, LoadServerStatus (+2 more)

### Community 95 - "Project configuration · string"
Cohesion: 0.19
Nodes (4): wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16()

### Community 97 - "._write_accounts"
Cohesion: 0.15
Nodes (4): account_expiry(), _is_pos(), min_expiry(), test_maintenance_selection_does_not_count_as_use()

### Community 98 - "Flutter Chat · send_message.dart"
Cohesion: 0.17
Nodes (9): ChatRepositoryImpl, ChatRepository, streamReply, call, repository, SendMessage, FakeChatRepository, DelayedCancellationReplies (+1 more)

### Community 99 - "desktop_engine_installer_io.dart"
Cohesion: 0.17
Nodes (9): cancelInstall, _generation, install, _installing, _process, _python, _setupRoot, sourceRoot (+1 more)

### Community 100 - "chat_bloc_test.dart"
Cohesion: 0.15
Nodes (7): calls, cancelled, connection, history, reply, streamReply, tick

### Community 101 - "Flutter Accounts · proxy_bloc.dart"
Cohesion: 0.18
Nodes (17): accountId, busy, check, configuration, connection, error, manage, _message (+9 more)

### Community 102 - "Flutter Accounts · manage_proxy.dart"
Cohesion: 0.11
Nodes (12): api, _json, ProxyRepositoryImpl, save, test, ProxyRepository, save, test (+4 more)

### Community 103 - "DesktopEngine"
Cohesion: 0.17
Nodes (11): ProcessDesktopInstaller, ProcessDesktopEngine, UnsupportedDesktopEngine, DesktopEngine, cancelInstall, DesktopEngineInstaller, DesktopInstallStage, install (+3 more)

### Community 104 - "manage_accounts.dart"
Cohesion: 0.12
Nodes (10): AccountAction, act, import, list, act, import, list, ManageAccounts (+2 more)

### Community 105 - "Flutter Core · reference_image.dart"
Cohesion: 0.17
Nodes (10): bytes, fingerprint, fromBytes, maxFileBytes, maxFiles, maxTotalBytes, mime, name (+2 more)

### Community 106 - "pending_generation_store.dart"
Cohesion: 0.15
Nodes (12): id, _key, kind, list, PendingGeneration, PendingGenerationStore, preferences, _queue (+4 more)

### Community 107 - "Flutter Accounts · cookie_update_dialog.dart"
Cohesion: 0.10
Nodes (19): AppShell, AccountPage, build, _cookies, CookieUpdateDialog, _CookieUpdateDialogState, createState, dispose (+11 more)

### Community 108 - "AccountBloc"
Cohesion: 0.25
Nodes (16): AccountActed, AccountBloc, AccountCookiesUpdated, AccountEvent, AccountImported, AccountsBatchKeepaliveRequested, AccountsCleared, AccountsLoaded (+8 more)

### Community 109 - "generation_task_decoder.dart"
Cohesion: 0.17
Nodes (9): created, decodeTask, filename, id, progress, resolvedFilename, result, status (+1 more)

### Community 110 - "video_page.dart"
Cohesion: 0.11
Nodes (14): build, createState, dispose, _duration, _focus, _form, initState, onConfigure (+6 more)

### Community 113 - "studio_theme.dart"
Cohesion: 0.17
Nodes (11): accent, border, canvas, muted, raised, selected, StudioColors, StudioTheme (+3 more)

### Community 115 - "text_prompt_cubit_test.dart"
Cohesion: 0.17
Nodes (8): TextPromptRepositoryImpl, enhance, TextPromptRepository, enhance, main, pending, PendingPrompts, requests

### Community 116 - "image_prompt_cubit.dart"
Cohesion: 0.12
Nodes (14): ImagePromptRepositoryImpl, ImagePromptRepository, clear, _current, error, generate, image, loading (+6 more)

### Community 117 - "Flutter platform · web/manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 118 - "Flutter platform · Win32Window"
Cohesion: 0.24
Nodes (4): Win32Window, child_content_, quit_on_close_, window_handle_

### Community 119 - "batch_keepalive_repository.dart"
Cohesion: 0.11
Nodes (18): AccountRepositoryImpl, KeepaliveSummary, AccountCookiesRepository, AccountRepository, BatchKeepaliveRepository, BatchKeepaliveResult, busy, keepaliveAll (+10 more)

### Community 120 - "image_page.dart"
Cohesion: 0.11
Nodes (14): build, createState, didUpdateWidget, dispose, _form, initialPrompt, initState, onConfigure (+6 more)

### Community 121 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.09
Nodes (10): main, open, batch, main, a, main, otherHost, otherKey (+2 more)

### Community 122 - "reference_cubit.dart"
Cohesion: 0.13
Nodes (9): select, PickReferenceImages, referencePayload, build, enabled, onChanged, onLoadingChanged, ReferencePicker (+1 more)

### Community 125 - "media_bloc.dart"
Cohesion: 0.11
Nodes (13): ServerConnection, close, connection, deleting, _generation, load, matches, names (+5 more)

### Community 126 - "test_ref_image_safety.py"
Cohesion: 0.31
Nodes (7): main(), addresses(), check(), check_endpoints(), expect_error(), redirect(), response()

### Community 128 - "Flutter Core · pick_reference_images.dart"
Cohesion: 0.25
Nodes (6): DeviceReferenceFileSource, call, ReferenceFileSource, select, source, FakeFiles

### Community 129 - "video_bloc_test.dart"
Cohesion: 0.15
Nodes (10): connection, create, failPoll, failPost, keys, makeBloc, pending, polls (+2 more)

### Community 130 - "save_media.dart"
Cohesion: 0.18
Nodes (8): bytes, connection, image, MediaSaveSource, remote, save, saver, uri

### Community 131 - "String?"
Cohesion: 0.06
Nodes (27): _address, build, createState, dispose, initState, _key, _obscure, savedAddress (+19 more)

### Community 132 - "Client"
Cohesion: 0.10
Nodes (4): check(), Client, RouteTests, start()

### Community 134 - "get_muse_cookie.py"
Cohesion: 0.12
Nodes (15): find_chrome(), fmt_ts(), init_console(), main(), say(), upload(), wait_cdp(), _win_common_paths() (+7 more)

### Community 135 - "desktop_runtime_paths.dart"
Cohesion: 0.20
Nodes (8): data, desktopDataDirectory, desktopResourceDirectory, env, home, installedRuntimeDirectory, parent, runtimeExecutable

### Community 136 - "Flutter platform · analysis_options.yaml"
Cohesion: 0.33
Nodes (5): analyzer, exclude, include, linter, rules

### Community 137 - "Flutter Chat · chat_message.dart"
Cohesion: 0.40
Nodes (4): ChatMessage, content, MessageRole, role

### Community 138 - "../../../../core/domain/reference_image.dart"
Cohesion: 0.12
Nodes (11): generate, create, ImageRepositoryImpl, remote, create, ImageRepository, call, GenerateImage (+3 more)

### Community 139 - "Flutter Media · media_delete_result.dart"
Cohesion: 0.50
Nodes (3): errorCount, MediaDeleteResult, removed

### Community 140 - "Flutter platform · Point"
Cohesion: 0.50
Nodes (3): Point, x, y

### Community 141 - "Flutter platform · Size"
Cohesion: 0.50
Nodes (3): Size, height, width

### Community 142 - "Store"
Cohesion: 0.15
Nodes (3): Config, EncryptionTests, ProtectionReviewTests

### Community 151 - "keepalive_status.dart"
Cohesion: 0.15
Nodes (12): attempts, busy, checkedAt, failures, KeepaliveStatus, lastResult, lastRun, nextRun (+4 more)

### Community 153 - "dart:async"
Cohesion: 0.04
Nodes (40): bind, SseDecoder, b, batchBusy, batches, batchLoaded, batchPending, cookiePending (+32 more)

### Community 154 - ".patch"
Cohesion: 0.22
Nodes (7): _RelayHandler, _hash_key(), shared_transaction(), wrapped(), UserStore, _write(), SharedUsers

### Community 155 - "test_limits_web.cjs"
Cohesion: 0.07
Nodes (25): assert, c, calls, fs, html, limits, nodes, source (+17 more)

### Community 156 - "image_task.dart"
Cohesion: 0.22
Nodes (7): bytes, id, ImageTask, ImageTaskStatus, progress, status, terminal

### Community 157 - ".test_cancelled_proxy_retains_worker_reservation_at_each_wait"
Cohesion: 0.31
Nodes (7): get(), operation(), renew(), wait(), get(), invalidate(), proxy_context()

### Community 159 - "storage_usage_cubit.dart"
Cohesion: 0.18
Nodes (10): _attempt, bind, _connection, error, loading, refresh, repository, StorageUsageCubit (+2 more)

### Community 163 - "media_save_button_test.dart"
Cohesion: 0.22
Nodes (5): MediaSaveResult, calls, completer, main, save

### Community 164 - "../../../../core/errors/app_failure.dart"
Cohesion: 0.09
Nodes (16): _, accountCount, AccountImportDraft, _hasCookies, isBatch, label, parse, text (+8 more)

### Community 165 - "query_library.dart"
Cohesion: 0.22
Nodes (8): indexed, LibraryType, map, needle, newest, queryLibrary, search, type

### Community 166 - "account_import_test.dart"
Cohesion: 0.13
Nodes (12): act, batch, bloc, fail, failReload, import, list, loaded (+4 more)

### Community 167 - "text_prompt_cubit.dart"
Cohesion: 0.17
Nodes (11): clear, _current, edit, error, generate, maxLength, prompt, repository (+3 more)

### Community 170 - "video_bloc.dart"
Cohesion: 0.09
Nodes (35): _resumeVideo, _accept, admissionUncertain, busy, close, connection, duration, error (+27 more)

### Community 171 - "media_repository_impl.dart"
Cohesion: 0.17
Nodes (5): api, deleteBatch, deleteSingle, list, loadStorage

### Community 172 - "generation_task.dart"
Cohesion: 0.18
Nodes (10): createdAt, filename, GenerationStatus, id, kind, progress, prompt, protectedUri (+2 more)

### Community 174 - "test_reference_limits.py"
Cohesion: 0.15
Nodes (3): FakeJSONRequest, FakeMultipartRequest, FakeUpload

### Community 176 - "HistoryRecordStore"
Cohesion: 0.25
Nodes (7): HistoryRecordStore, read, write, SecureHistoryRecordStore, MemoryHistory, MemoryStatusHistoryStore, FixtureHistory

### Community 177 - "_http_exc"
Cohesion: 0.29
Nodes (4): _err_type(), _http_exc(), storage_quota_error(), _validation_exc()

### Community 178 - "secure_credential_store.dart"
Cohesion: 0.25
Nodes (5): delete, _key, read, storage, write

### Community 179 - "media_item.dart"
Cohesion: 0.25
Nodes (5): bytes, createdAt, isVideo, name, protectedUri

### Community 180 - "storage_usage.dart"
Cohesion: 0.29
Nodes (6): bytes, files, limitBytes, limitFiles, retentionDays, StorageUsage

### Community 181 - "RequestLimiter"
Cohesion: 0.11
Nodes (10): auth(), GenerationIdempotencyMiddleware, _idempotent_receipt(), resolve_model(), TenantRateMiddleware, Capacity, Conflict, GenerationLedger (+2 more)

### Community 183 - ".test_maintenance_waiting_gen_lock_and_keepalive_lock_recheck"
Cohesion: 0.38
Nodes (3): __aenter__(), __enter__(), invalidate()

### Community 185 - "CredentialStore"
Cohesion: 0.25
Nodes (7): CredentialStore, delete, read, write, SecureCredentialStore, MemoryCredentialStore, FixtureCredentials

### Community 186 - "chat_history_sheet.dart"
Cohesion: 0.33
Nodes (3): bloc, build, showChatHistory

### Community 188 - "List"
Cohesion: 0.09
Nodes (16): GenerationRecoveryCubit, build, GenerationRecoveryPanel, error, images, loading, move, pick (+8 more)

### Community 190 - "desktop_engine_failure.dart"
Cohesion: 0.29
Nodes (6): code, DesktopEngineFailure, DesktopEngineFailureCode, fromInstallProtocol, fromProtocol, message

### Community 191 - "StorageRepository"
Cohesion: 0.40
Nodes (3): loadStorage, StorageRepository, FixtureStorage

### Community 195 - "add_account"
Cohesion: 0.40
Nodes (4): AccountRequest, add_account(), parse_batch(), parse_cookie_text()

### Community 199 - "prompt_image_loader.dart"
Cohesion: 0.33
Nodes (3): load, maxBytes, PromptImageLoader

### Community 204 - "ConnectServer"
Cohesion: 0.40
Nodes (5): ConnectServer, Connect, UnusedConnect, Connect, Connect

## Knowledge Gaps
- **1205 isolated node(s):** `calls`, `cancelled`, `connection`, `history`, `reply` (+1200 more)
  These have ≤1 connection - possible missing edges. (Counts symbols only; 2011 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **60 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `MuseEngine` connect `MuseEngine` to `.ensure_page`, `app.py`, `MuseGenerationError`, `._attach_images`, `AccountProxyTests`, `browser_checks`, `Store`, `test_account_proxy.py`, `Store`, `._wait_attachment`, `._parse_quota`, `json`, `test_reference_media_hardening.py`, `.write_media`?**
  _High betweenness centrality (0.044) - this node is a cross-community bridge._
- **Are the 4 inferred relationships involving `Store` (e.g. with `AccountProxyTests` and `MediaBoundaryTests`) actually correct?**
  _`Store` has 4 INFERRED edges - model-reasoned connections that need verification._
- **What connects `calls`, `cancelled`, `connection` to the rest of the system?**
  _1205 weakly-connected nodes found - possible missing edges._
- **Should `test_admin_layout.py` be split into smaller, more focused modules?**
  _Cohesion score 0.0967741935483871 - nodes in this community are weakly interconnected._
- **Why does `Store` connect `Store` to `._write_accounts`, `app.py`, `images_edits`, `AccountProxyTests`, `test_account_proxy.py`, `Store`, `.test_cancelled_workers_ignore_untrusted_result_path`, `AccountCipher`, `json`, `test_reference_media_hardening.py`, `.write_media`?**
  _High betweenness centrality (0.043) - this node is a cross-community bridge._
- **Are the 3 inferred relationships involving `MuseEngine` (e.g. with `AccountProxyTests` and `MediaBoundaryTests`) actually correct?**
  _`MuseEngine` has 3 INFERRED edges - model-reasoned connections that need verification._
- **Should `os` be split into smaller, more focused modules?**
  _Cohesion score 0.10175763182238667 - nodes in this community are weakly interconnected._