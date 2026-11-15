# Graph Report - muse_app  (2026-11-12)

## Corpus Check
- 217 files · ~60,810 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 64 file(s) not represented in the graph (top: (none) 12, .xcconfig 9, .plist 8)

## Summary
- 2121 nodes · 3450 edges · 142 communities (125 shown, 17 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS · INFERRED: 14 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `8a3dab9d`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- proxy_editor.dart
- dependencies.dart
- chat_history_repository_impl.dart
- manage_accounts.dart
- package:flutter_bloc/flutter_bloc.dart
- _AppShellState
- reference_cubit.dart
- AppDelegate
- shell.dart
- image_bloc.dart
- chat_history_test.dart
- dependencies
- dart:async
- my_application.cc
- connection_bloc.dart
- reference_image.dart
- video_bloc.dart
- reference_images_test.dart
- media_preview.dart
- desktop_engine_io.dart
- win32_window.cpp
- FlutterWindow
- desktop_engine_process_test.dart
- image_page.dart
- video_page.dart
- media_page.dart
- Win32Window
- keepalive_status_bloc.dart
- task_repository_impl.dart
- ../../../core/errors/app_failure.dart
- connection_repository_impl.dart
- utils.cpp
- _
- muse_account.dart
- package:test/test.dart
- proxy_repository_impl.dart
- restore_connection.dart
- video_bloc_test.dart
- desktop_connection_test.dart
- account_bloc.dart
- proxy_bloc.dart
- generate_image.dart
- chat_bloc_test.dart
- account_cookies_page_test.dart
- account_repository_impl.dart
- send_message.dart
- ../errors/app_failure.dart
- dashboard_preview.dart
- chat_bloc.dart
- keepalive_status.dart
- image_prompt_cubit.dart
- connection_local_data_source.dart
- manage_proxy.dart
- dart:convert
- manifest.json
- manage_chat_history.dart
- image_prompt_repository_test.dart
- generation_task_decoder.dart
- delete_media.dart
- list_header.dart
- .MessageHandler
- generation_workspace.dart
- media_delete_bloc_test.dart
- desktop_install_panel_test.dart
- StatefulWidget
- connection_repository.dart
- String?
- analysis_options.yaml
- account_import_test.dart
- chat_message.dart
- cookie_import_form.dart
- Point
- MainActivity.kt
- flutter_export_environment.sh
- desktop_engine_stub.dart
- account_batch_keepalive_bloc_test.dart
- load_server_status.dart
- account_batch_keepalive_page_test.dart
- app.dart
- account_page.dart
- _
- load_tasks.dart
- media_delete_page_test.dart
- image_prompt_page.dart
- desktop_engine_installer_io.dart
- server_status_bloc.dart
- package:flutter/material.dart
- AccountBloc
- DesktopEngine
- status_page_test.dart
- desktop_runtime_paths.dart
- media_save_button.dart
- task_bloc.dart
- reference_picker.dart
- ServerConnection
- secure_credential_store.dart
- media_repository_impl.dart
- ImageBloc
- task_delete_page_test.dart
- ServerStatusBloc
- package:flutter_test/flutter_test.dart
- pick_reference_images.dart
- chat_repository_impl.dart
- device_reference_file_source.dart
- CredentialStore
- HistoryRecordStore
- desktop_engine_failure.dart
- keepalive_status_page_test.dart
- media_delete_result.dart
- media_name.dart
- AccountRepository
- collection_bloc.dart
- server_status.dart
- ../../../connection/domain/entities/server_connection.dart
- media_bloc.dart
- State
- text_prompt_cubit.dart
- text_prompt_page.dart
- connection_bloc_test.dart
- media_save_test.dart
- save_media.dart
- generation_task.dart
- text_prompt_repository_impl.dart
- media_save_button_test.dart
- admin_bloc_test.dart
- account_quota_section.dart
- media_saver_stub.dart
- media_saver_io.dart
- DateTime?
- image_repository_impl.dart
- account_import_form_test.dart
- ConnectionRepository

## God Nodes (most connected - your core abstractions)
1. `ConnectionBloc` - 49 edges
2. `ChatBloc` - 23 edges
3. `_AppShellState` - 22 edges
4. `Win32Window` - 21 edges
5. `ServerConnection` - 21 edges
6. `_` - 20 edges
7. `AccountBloc` - 20 edges
8. `CollectionLoaded` - 16 edges
9. `TaskBloc` - 16 edges
10. `MediaBloc` - 15 edges

## Surprising Connections (you probably didn't know these)
- `session` --calls--> `ChatSessionChanged`  [EXTRACTED]
  test/features/chat_history_test.dart → lib/features/chat/presentation/bloc/chat_bloc.dart
- `talk` --calls--> `ChatSubmitted`  [EXTRACTED]
  test/features/chat_history_test.dart → lib/features/chat/presentation/bloc/chat_bloc.dart
- `main` --calls--> `ImageRequested`  [EXTRACTED]
  test/features/reference_images_test.dart → lib/features/images/presentation/bloc/image_bloc.dart
- `main` --references--> `ConnectionBloc`  [EXTRACTED]
  test/features/status/status_page_test.dart → lib/features/connection/presentation/bloc/connection_bloc.dart
- `MemoryCredentialStore` --implements--> `CredentialStore`  [EXTRACTED]
  test/support/memory_credential_store.dart → lib/core/storage/credential_store.dart

## Import Cycles
- None detected.

## Communities (142 total, 17 thin omitted)

### Community 0 - "proxy_editor.dart"
Cohesion: 0.10
Nodes (20): ManageProxy, account, build, _clearPassword, _configuration, connection, createState, didUpdateWidget (+12 more)

### Community 1 - "dependencies.dart"
Cohesion: 0.04
Nodes (20): chatHistory, connectionRepository, connectServer, desktopEngine, forgetConnection, generateImage, generateVideo, getImageTask (+12 more)

### Community 2 - "chat_history_repository_impl.dart"
Cohesion: 0.15
Nodes (8): delete, _key, list, _queue, _read, save, store, _write

### Community 3 - "manage_accounts.dart"
Cohesion: 0.12
Nodes (10): AccountAction, act, import, list, act, import, list, ManageAccounts (+2 more)

### Community 4 - "package:flutter_bloc/flutter_bloc.dart"
Cohesion: 0.09
Nodes (10): generate, main, requests, bytes, length, main, name, readAsBytes (+2 more)

### Community 5 - "_AppShellState"
Cohesion: 0.23
Nodes (19): AppShell, _AppShellState, _select, CollectionBloc, CollectionCleared, CollectionEvent, CollectionLoaded, CollectionPaused (+11 more)

### Community 6 - "reference_cubit.dart"
Cohesion: 0.18
Nodes (9): error, images, loading, move, pick, pickImages, ReferenceCubit, ReferenceState (+1 more)

### Community 7 - "AppDelegate"
Cohesion: 0.07
Nodes (11): Cocoa, Flutter, FlutterMacOS, AppDelegate, SceneDelegate, RunnerTests, AppDelegate, MainFlutterWindow (+3 more)

### Community 8 - "shell.dart"
Cohesion: 0.10
Nodes (10): build, _createImage, createState, _destinations, dispose, _imagePrompt, initState, _more (+2 more)

### Community 9 - "image_bloc.dart"
Cohesion: 0.09
Nodes (19): _accept, busy, close, connection, error, generate, generation, getTask (+11 more)

### Community 10 - "chat_history_test.dart"
Cohesion: 0.06
Nodes (26): cancelled, cancelling, completed, delete, deleted, deleting, fail, finished (+18 more)

### Community 11 - "dependencies"
Cohesion: 0.06
Nodes (30): enable-swift-package-manager, dependencies, bloc, crypto, cupertino_icons, desktop_drop, file_selector, flutter (+22 more)

### Community 12 - "dart:async"
Cohesion: 0.08
Nodes (18): bind, SseDecoder, act, b, calls, fail, items, list (+10 more)

### Community 13 - "my_application.cc"
Cohesion: 0.10
Nodes (13): main(), first_frame_cb(), my_application_activate(), my_application_class_init(), my_application_dispose(), my_application_init(), my_application_local_command_line(), my_application_new() (+5 more)

### Community 14 - "connection_bloc.dart"
Cohesion: 0.06
Nodes (50): address, apiKey, attempt, _cancelInstallation, close, connect, connection, ConnectionBloc (+42 more)

### Community 15 - "reference_image.dart"
Cohesion: 0.05
Nodes (33): accent, border, canvas, muted, raised, selected, StudioColors, StudioTheme (+25 more)

### Community 16 - "video_bloc.dart"
Cohesion: 0.11
Nodes (29): _resumeVideo, _accept, admissionUncertain, busy, close, connection, duration, error (+21 more)

### Community 17 - "reference_images_test.dart"
Cohesion: 0.07
Nodes (22): connection, create, failPoll, failPost, keys, pending, polls, posts (+14 more)

### Community 18 - "media_preview.dart"
Cohesion: 0.10
Nodes (16): build, connection, createState, didUpdateWidget, dispose, _failed, initState, _load (+8 more)

### Community 19 - "desktop_engine_io.dart"
Cohesion: 0.09
Nodes (20): cancelInstall, _connection, createDesktopEngine, dataDirectory, executable, _exits, _generation, install (+12 more)

### Community 20 - "win32_window.cpp"
Cohesion: 0.15
Nodes (8): EnableNonClientDpiScaling, Scale(), Win32Window::Win32Window(), WindowClassRegistrar, class_registered_, WindowClassRegistrar::GetWindowClass(), instance_, WindowClassRegistrar::UnregisterWindowClass()

### Community 21 - "FlutterWindow"
Cohesion: 0.11
Nodes (4): FlutterWindow, flutter_controller_, FlutterWindow::FlutterWindow(), project_

### Community 22 - "desktop_engine_process_test.dart"
Cohesion: 0.10
Nodes (17): announced, ChildProcess, errors, exitCode, exited, finish, handshake, input (+9 more)

### Community 23 - "image_page.dart"
Cohesion: 0.12
Nodes (13): build, createState, didUpdateWidget, dispose, _form, initialPrompt, initState, onConfigure (+5 more)

### Community 24 - "video_page.dart"
Cohesion: 0.12
Nodes (12): build, createState, dispose, _duration, _focus, _form, onConfigure, onTasks (+4 more)

### Community 25 - "media_page.dart"
Cohesion: 0.12
Nodes (12): build, _confirming, createState, _selected, _selectionConnection, build, _confirming, createState (+4 more)

### Community 26 - "Win32Window"
Cohesion: 0.15
Nodes (7): Size, height, width, Win32Window, child_content_, quit_on_close_, window_handle_

### Community 27 - "keepalive_status_bloc.dart"
Cohesion: 0.12
Nodes (14): KeepaliveStatus, busy, connection, error, KeepaliveStatusBloc, KeepaliveStatusState, refresh, repository (+6 more)

### Community 28 - "task_repository_impl.dart"
Cohesion: 0.10
Nodes (14): api, clear, delete, list, api, create, VideoRepositoryImpl, create (+6 more)

### Community 29 - "../../../core/errors/app_failure.dart"
Cohesion: 0.16
Nodes (5): streamReply, create, _request, fromJson, ImageTaskModel

### Community 30 - "connection_repository_impl.dart"
Cohesion: 0.14
Nodes (9): ConnectionRemoteDataSource, verify, forgetConnection, local, readSavedConnection, remote, saveConnection, savedAddress (+1 more)

### Community 31 - "utils.cpp"
Cohesion: 0.17
Nodes (4): wWinMain(), CreateAndAttachConsole(), GetCommandLineArguments(), Utf8FromUtf16()

### Community 32 - "_"
Cohesion: 0.13
Nodes (15): _, exitIp, hasPassword, normalizeServer, parse, passed, password, ProxyConfiguration (+7 more)

### Community 33 - "muse_account.dart"
Cohesion: 0.10
Nodes (17): enabled, expiresAt, extraExpires, extraLeft, extraRemaining, extraUsed, healthy, id (+9 more)

### Community 34 - "package:test/test.dart"
Cohesion: 0.08
Nodes (12): main, main, connection, main, server, body, close, closed (+4 more)

### Community 35 - "proxy_repository_impl.dart"
Cohesion: 0.15
Nodes (7): JsonApiClient, api, _json, save, test, api, load

### Community 36 - "restore_connection.dart"
Cohesion: 0.22
Nodes (6): call, repository, call, ForgetConnection, repository, RestoreConnection

### Community 37 - "video_bloc_test.dart"
Cohesion: 0.15
Nodes (9): connection, create, failPoll, failPost, makeBloc, pending, polls, posts (+1 more)

### Community 38 - "desktop_connection_test.dart"
Cohesion: 0.07
Nodes (28): cancelInstall, cancellation, cancellations, exits, fail, forgetConnection, install, installation (+20 more)

### Community 39 - "account_bloc.dart"
Cohesion: 0.10
Nodes (18): action, batchCompleted, _batchKeepalive, busy, connection, cookies, error, _generation (+10 more)

### Community 40 - "proxy_bloc.dart"
Cohesion: 0.17
Nodes (18): ProxyCheck, accountId, busy, check, configuration, connection, error, manage (+10 more)

### Community 41 - "generate_image.dart"
Cohesion: 0.17
Nodes (9): ImageRepositoryImpl, create, ImageRepository, call, GenerateImage, GetImageTask, repository, FakeImages (+1 more)

### Community 42 - "chat_bloc_test.dart"
Cohesion: 0.15
Nodes (7): calls, cancelled, connection, history, reply, streamReply, tick

### Community 43 - "account_cookies_page_test.dart"
Cohesion: 0.17
Nodes (6): call, main, noSuchMethod, main, main, main

### Community 44 - "account_repository_impl.dart"
Cohesion: 0.13
Nodes (11): act, api, implements, import, keepaliveAll, keepaliveStatus, list, _statusCount (+3 more)

### Community 45 - "send_message.dart"
Cohesion: 0.17
Nodes (9): ChatRepositoryImpl, ChatRepository, streamReply, call, repository, SendMessage, FakeChatRepository, DelayedCancellationReplies (+1 more)

### Community 46 - "../errors/app_failure.dart"
Cohesion: 0.29
Nodes (3): endpoint, mediaUri, storageFailure

### Community 47 - "dashboard_preview.dart"
Cohesion: 0.14
Nodes (8): main, main, delete, dependencies, main, read, value, write

### Community 48 - "chat_bloc.dart"
Cohesion: 0.05
Nodes (54): didChangeAppLifecycleState, ChatMessageModel, toJson, activeId, ChatBloc, ChatCleared, ChatEvent, ChatHistoryFlushed (+46 more)

### Community 49 - "keepalive_status.dart"
Cohesion: 0.15
Nodes (11): attempts, busy, checkedAt, failures, lastResult, lastRun, nextRun, running (+3 more)

### Community 50 - "image_prompt_cubit.dart"
Cohesion: 0.10
Nodes (17): generate, ImagePromptRepositoryImpl, timeout, generate, ImagePromptRepository, clear, _current, error (+9 more)

### Community 51 - "connection_local_data_source.dart"
Cohesion: 0.18
Nodes (8): address, _addressKey, ConnectionLocalDataSource, credentials, forgetConnection, preferences, readConnection, saveConnection

### Community 52 - "manage_proxy.dart"
Cohesion: 0.18
Nodes (8): ProxyRepositoryImpl, ProxyRepository, save, test, repository, save, test, Proxy

### Community 53 - "dart:convert"
Cohesion: 0.08
Nodes (20): apiError, request, main, main, server, main, server, fullQuota (+12 more)

### Community 54 - "manifest.json"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 55 - "manage_chat_history.dart"
Cohesion: 0.13
Nodes (12): ChatHistoryRepositoryImpl, ChatHistoryRepository, delete, list, save, delete, list, ManageChatHistory (+4 more)

### Community 56 - "image_prompt_repository_test.dart"
Cohesion: 0.11
Nodes (14): ClosingClient, close, closed, ClosingClient, image, main, send, calls (+6 more)

### Community 57 - "generation_task_decoder.dart"
Cohesion: 0.20
Nodes (8): created, decodeTask, filename, id, progress, result, status, url

### Community 58 - "delete_media.dart"
Cohesion: 0.13
Nodes (12): MediaRepositoryImpl, deleteBatch, deleteSingle, list, MediaRepository, call, DeleteMedia, repository (+4 more)

### Community 59 - "list_header.dart"
Cohesion: 0.20
Nodes (8): build, d, error, formatDate, loading, onRefresh, title, two

### Community 62 - "generation_workspace.dart"
Cohesion: 0.12
Nodes (14): MuseApp, build, busy, child, description, form, GenerationPreview, GenerationWorkspace (+6 more)

### Community 63 - "media_delete_bloc_test.dart"
Cohesion: 0.05
Nodes (31): ChatThread, id, messages, updatedAt, a, b, calls, deleteBatch (+23 more)

### Community 64 - "desktop_install_panel_test.dart"
Cohesion: 0.12
Nodes (11): app, calls, cancelInstall, install, main, noSuchMethod, pending, start (+3 more)

### Community 65 - "StatefulWidget"
Cohesion: 0.33
Nodes (5): _ProxyForm, ChatPage, ImagePage, MediaPage, VideoPage

### Community 66 - "connection_repository.dart"
Cohesion: 0.29
Nodes (5): forgetConnection, readSavedConnection, saveConnection, savedAddress, verify

### Community 67 - "String?"
Cohesion: 0.29
Nodes (4): delete, read, value, write

### Community 68 - "analysis_options.yaml"
Cohesion: 0.33
Nodes (5): analyzer, exclude, include, linter, rules

### Community 69 - "account_import_test.dart"
Cohesion: 0.14
Nodes (11): act, batch, bloc, fail, failReload, import, list, pending (+3 more)

### Community 70 - "chat_message.dart"
Cohesion: 0.40
Nodes (4): ChatMessage, content, MessageRole, role

### Community 71 - "cookie_import_form.dart"
Cohesion: 0.14
Nodes (12): build, busy, CookieImportForm, _CookieImportFormState, _cookies, createState, dispose, _focus (+4 more)

### Community 72 - "Point"
Cohesion: 0.50
Nodes (3): Point, x, y

### Community 81 - "desktop_engine_stub.dart"
Cohesion: 0.15
Nodes (9): createDesktopEngine, start, stop, supported, unexpectedExit, start, stop, supported (+1 more)

### Community 82 - "account_batch_keepalive_bloc_test.dart"
Cohesion: 0.08
Nodes (20): b, batchBusy, batches, batchLoaded, batchPending, cookiePending, keepaliveAll, KeepaliveRepo (+12 more)

### Community 83 - "load_server_status.dart"
Cohesion: 0.20
Nodes (7): ServerStatusRepositoryImpl, load, ServerStatusRepository, call, LoadServerStatus, repository, PendingStatusRepository

### Community 84 - "account_batch_keepalive_page_test.dart"
Cohesion: 0.15
Nodes (11): ensureVisible, keepaliveStatus, main, mount, open, pump, pumpAndSettle, pumpWidget (+3 more)

### Community 85 - "app.dart"
Cohesion: 0.11
Nodes (3): build, dependencies, AppDependencies

### Community 86 - "account_page.dart"
Cohesion: 0.17
Nodes (5): build, createState, initState, _keepaliveDialogOpen, _showImport

### Community 87 - "_"
Cohesion: 0.22
Nodes (9): _, accountCount, AccountImportDraft, _hasCookies, isBatch, label, parse, text (+1 more)

### Community 88 - "load_tasks.dart"
Cohesion: 0.17
Nodes (9): TaskRepositoryImpl, clear, delete, list, TaskRepository, call, LoadTasks, repository (+1 more)

### Community 89 - "media_delete_page_test.dart"
Cohesion: 0.15
Nodes (8): ConnectServer, Connect, UnusedConnect, call, Connect, mount, noSuchMethod, Connect

### Community 90 - "image_prompt_page.dart"
Cohesion: 0.14
Nodes (14): ImagePromptCubit, ImagePromptState, build, _copy, createState, _dragging, _drop, ImagePromptPage (+6 more)

### Community 91 - "desktop_engine_installer_io.dart"
Cohesion: 0.17
Nodes (9): cancelInstall, _generation, install, _installing, _process, _python, _setupRoot, sourceRoot (+1 more)

### Community 92 - "server_status_bloc.dart"
Cohesion: 0.17
Nodes (10): busy, connection, connectionChanged, error, _generation, load, refresh, snapshot (+2 more)

### Community 93 - "package:flutter/material.dart"
Cohesion: 0.18
Nodes (4): main, preferences, main, open

### Community 94 - "AccountBloc"
Cohesion: 0.19
Nodes (19): AccountActed, AccountBloc, AccountCookiesUpdated, AccountEvent, AccountImported, AccountsBatchKeepaliveRequested, AccountsCleared, AccountsLoaded (+11 more)

### Community 95 - "DesktopEngine"
Cohesion: 0.20
Nodes (11): ProcessDesktopInstaller, ProcessDesktopEngine, UnsupportedDesktopEngine, DesktopEngine, cancelInstall, DesktopEngineInstaller, DesktopInstallStage, install (+3 more)

### Community 96 - "status_page_test.dart"
Cohesion: 0.11
Nodes (10): a, b, bloc, calls, load, main, repository, read (+2 more)

### Community 97 - "desktop_runtime_paths.dart"
Cohesion: 0.20
Nodes (8): data, desktopDataDirectory, desktopResourceDirectory, env, home, installedRuntimeDirectory, parent, runtimeExecutable

### Community 98 - "media_save_button.dart"
Cohesion: 0.15
Nodes (14): SaveMedia, build, _busy, _bytes, _cancelled, createState, didUpdateWidget, dispose (+6 more)

### Community 99 - "task_bloc.dart"
Cohesion: 0.13
Nodes (13): close, connection, deleting, _generation, id, load, matches, _mutate (+5 more)

### Community 100 - "reference_picker.dart"
Cohesion: 0.22
Nodes (7): PickReferenceImages, build, enabled, onChanged, onLoadingChanged, ReferencePicker, video

### Community 101 - "ServerConnection"
Cohesion: 0.20
Nodes (8): apiKey, baseUrl, endpoint, headers, isLocal, parse, ServerConnection, toString

### Community 102 - "secure_credential_store.dart"
Cohesion: 0.13
Nodes (8): delete, _key, read, storage, write, read, storage, write

### Community 103 - "media_repository_impl.dart"
Cohesion: 0.22
Nodes (4): api, deleteBatch, deleteSingle, list

### Community 104 - "ImageBloc"
Cohesion: 0.44
Nodes (9): ImageBloc, ImageEvent, _ImagePolled, ImagePollingRetried, ImageRequested, ImagesCleared, ImageState, _ImagePageState (+1 more)

### Community 105 - "task_delete_page_test.dart"
Cohesion: 0.25
Nodes (3): call, mount, noSuchMethod

### Community 106 - "ServerStatusBloc"
Cohesion: 0.29
Nodes (5): ServerStatusBloc, ServerStatusState, build, ServerStatusPage, main

### Community 107 - "package:flutter_test/flutter_test.dart"
Cohesion: 0.15
Nodes (6): main, enhance, main, pending, requests, main

### Community 108 - "pick_reference_images.dart"
Cohesion: 0.25
Nodes (6): DeviceReferenceFileSource, call, ReferenceFileSource, select, source, FakeFiles

### Community 109 - "chat_repository_impl.dart"
Cohesion: 0.29
Nodes (3): ChatRemoteDataSource, remote, streamReply

### Community 111 - "CredentialStore"
Cohesion: 0.25
Nodes (7): CredentialStore, delete, read, write, SecureCredentialStore, MemoryCredentialStore, FixtureCredentials

### Community 112 - "HistoryRecordStore"
Cohesion: 0.25
Nodes (7): HistoryRecordStore, read, write, SecureHistoryRecordStore, MemoryHistory, MemoryStatusHistoryStore, FixtureHistory

### Community 113 - "desktop_engine_failure.dart"
Cohesion: 0.29
Nodes (6): code, DesktopEngineFailure, DesktopEngineFailureCode, fromInstallProtocol, fromProtocol, message

### Community 115 - "media_delete_result.dart"
Cohesion: 0.50
Nodes (3): errorCount, MediaDeleteResult, removed

### Community 118 - "AccountRepository"
Cohesion: 0.19
Nodes (12): AccountRepositoryImpl, AccountCookiesRepository, AccountRepository, BatchKeepaliveRepository, KeepaliveStatusRepository, BatchRepo, PageRepo, CookiesRepo (+4 more)

### Community 119 - "collection_bloc.dart"
Cohesion: 0.15
Nodes (11): close, CollectionState, connection, error, _generation, items, loading, poll (+3 more)

### Community 120 - "server_status.dart"
Cohesion: 0.17
Nodes (10): browserRunning, disabledAccounts, enabledAccounts, errorAccounts, expiredAccounts, expiringAccounts, healthyAccounts, mediaCount (+2 more)

### Community 121 - "../../../connection/domain/entities/server_connection.dart"
Cohesion: 0.18
Nodes (7): KeepaliveSummary, updateCookies, BatchKeepaliveResult, busy, keepaliveAll, summary, keepaliveStatus

### Community 122 - "media_bloc.dart"
Cohesion: 0.17
Nodes (9): close, connection, deleting, _generation, load, matches, names, notice (+1 more)

### Community 123 - "State"
Cohesion: 0.18
Nodes (10): build, _cookies, CookieUpdateDialog, _CookieUpdateDialogState, createState, dispose, _error, onSubmit (+2 more)

### Community 124 - "text_prompt_cubit.dart"
Cohesion: 0.17
Nodes (11): clear, _current, edit, error, generate, maxLength, prompt, repository (+3 more)

### Community 125 - "text_prompt_page.dart"
Cohesion: 0.21
Nodes (10): TextPromptCubit, TextPromptState, build, _controller, createState, dispose, _focus, initState (+2 more)

### Community 126 - "connection_bloc_test.dart"
Cohesion: 0.17
Nodes (9): credentials, forgetConnection, readSavedConnection, saveConnection, saved, savedAddress, tick, verification (+1 more)

### Community 127 - "media_save_test.dart"
Cohesion: 0.18
Nodes (6): AppFailure, message, toString, connection, main, valid

### Community 128 - "save_media.dart"
Cohesion: 0.18
Nodes (8): bytes, connection, image, MediaSaveSource, remote, save, saver, uri

### Community 129 - "generation_task.dart"
Cohesion: 0.18
Nodes (10): createdAt, filename, GenerationStatus, GenerationTask, id, kind, progress, prompt (+2 more)

### Community 130 - "text_prompt_repository_impl.dart"
Cohesion: 0.20
Nodes (6): enhance, TextPromptRepositoryImpl, timeout, enhance, TextPromptRepository, PendingPrompts

### Community 131 - "media_save_button_test.dart"
Cohesion: 0.22
Nodes (5): MediaSaveResult, calls, completer, main, save

### Community 132 - "admin_bloc_test.dart"
Cohesion: 0.22
Nodes (7): act, connection, fail, import, imported, list, pending

### Community 133 - "account_quota_section.dart"
Cohesion: 0.25
Nodes (6): MuseAccount, account, build, _percentage, _text, _usage

### Community 134 - "media_saver_stub.dart"
Cohesion: 0.25
Nodes (6): NativeMediaSaver, createMediaSaver, save, UnsupportedMediaSaver, MediaSaver, FakeSaver

### Community 135 - "media_saver_io.dart"
Cohesion: 0.29
Nodes (5): _busy, createMediaSaver, idleTimeout, _pick, save

### Community 136 - "DateTime?"
Cohesion: 0.29
Nodes (5): bytes, createdAt, isVideo, MediaItem, name

### Community 137 - "image_repository_impl.dart"
Cohesion: 0.33
Nodes (3): ImageRemoteDataSource, create, remote

### Community 140 - "ConnectionRepository"
Cohesion: 0.50
Nodes (4): ConnectionRepositoryImpl, ConnectionRepository, FakeConnectionRepository, SavedServer

## Knowledge Gaps
- **1058 isolated node(s):** `connection`, `uri`, `bytes`, `saver`, `remote` (+1053 more)
  These have ≤1 connection - possible missing edges. (Counts symbols only; 1357 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **17 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `ServerConnection` connect `ServerConnection` to `save_media.dart`, `proxy_editor.dart`, `image_bloc.dart`, `connection_bloc.dart`, `video_bloc.dart`, `media_preview.dart`, `desktop_engine_io.dart`, `media_page.dart`, `keepalive_status_bloc.dart`, `package:test/test.dart`, `desktop_connection_test.dart`, `account_bloc.dart`, `proxy_bloc.dart`, `chat_bloc.dart`, `server_status_bloc.dart`, `task_bloc.dart`, `collection_bloc.dart`, `media_bloc.dart`, `connection_bloc_test.dart`?**
  _High betweenness centrality (0.043) - this node is a cross-community bridge._
- **What connects `connection`, `uri`, `bytes` to the rest of the system?**
  _1058 weakly-connected nodes found - possible missing edges._
- **Should `proxy_editor.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.09523809523809523 - nodes in this community are weakly interconnected._
- **Why does `ConnectionBloc` connect `connection_bloc.dart` to `media_delete_page_test.dart`, `status_page_test.dart`, `media_save_button.dart`, `_AppShellState`, `shell.dart`, `ImageBloc`, `ServerStatusBloc`, `task_delete_page_test.dart`, `video_bloc.dart`, `chat_bloc.dart`, `account_page.dart`, `media_page.dart`, `AccountBloc`?**
  _High betweenness centrality (0.033) - this node is a cross-community bridge._
- **Should `dependencies.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.037037037037037035 - nodes in this community are weakly interconnected._
- **Why does `Win32Window` connect `Win32Window` to `Point`, `win32_window.cpp`, `FlutterWindow`, `.MessageHandler`, `flutter_window.h`?**
  _High betweenness centrality (0.027) - this node is a cross-community bridge._
- **Should `manage_accounts.dart` be split into smaller, more focused modules?**
  _Cohesion score 0.125 - nodes in this community are weakly interconnected._