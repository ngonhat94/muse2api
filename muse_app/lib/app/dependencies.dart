import '../features/admin/data/repositories/admin_users_repository_impl.dart';
import '../features/admin/domain/repositories/admin_users_repository.dart';
import '../features/status/data/repositories/server_status_repository_impl.dart';
import '../features/status/domain/usecases/load_server_status.dart';
import '../features/accounts/domain/usecases/manage_proxy.dart';
import '../features/accounts/data/repositories/proxy_repository_impl.dart';
import '../features/chat/data/datasources/history_record_store.dart';
import '../features/chat/data/datasources/secure_history_record_store.dart';
import '../features/chat/data/repositories/chat_history_repository_impl.dart';
import '../features/chat/domain/usecases/manage_chat_history.dart';
import '../core/data/device_reference_file_source.dart';
import '../core/data/media_saver_factory.dart';
import '../core/domain/save_media.dart';
import '../core/domain/pick_reference_images.dart';
import '../core/network/json_api_client.dart';
import '../features/videos/data/repositories/video_repository_impl.dart';
import '../features/videos/domain/usecases/generate_video.dart';
import '../features/tasks/data/repositories/task_repository_impl.dart';
import '../features/tasks/domain/usecases/load_tasks.dart';
import '../features/media/data/repositories/media_repository_impl.dart';
import '../features/media/domain/usecases/load_media.dart';
import '../features/media/domain/repositories/storage_repository.dart';
import '../features/accounts/data/repositories/account_repository_impl.dart';
import '../features/accounts/domain/usecases/manage_accounts.dart';
import '../core/storage/credential_store.dart';
import '../core/storage/secure_credential_store.dart';
import '../features/connection/domain/usecases/restore_connection.dart';
import '../features/images/data/datasources/image_remote_data_source.dart';
import '../features/images/data/repositories/image_repository_impl.dart';
import '../features/images/domain/usecases/generate_image.dart';

import 'package:http/http.dart' as http;

import '../features/image_prompt/data/image_prompt_repository_impl.dart';
import '../features/text_prompt/data/text_prompt_repository_impl.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/storage/pending_generation_store.dart';

import '../features/desktop/data/desktop_engine_factory.dart';
import '../features/desktop/domain/repositories/desktop_engine.dart';

import '../features/chat/data/datasources/chat_remote_data_source.dart';
import '../features/chat/data/repositories/chat_repository_impl.dart';
import '../features/chat/domain/usecases/send_message.dart';
import '../features/connection/data/datasources/connection_local_data_source.dart';
import '../features/connection/data/datasources/connection_remote_data_source.dart';
import '../features/connection/data/repositories/connection_repository_impl.dart';
import '../features/connection/domain/usecases/connect_server.dart';

/// Composition root: concrete adapters are wired here, never inside a BLoC.
class AppDependencies {
  AppDependencies(
    SharedPreferences preferences, {
    http.Client Function()? clientFactory,
    CredentialStore? credentialStore,
    HistoryRecordStore? historyStore,
    DesktopEngine? localEngine,
  }) {
    pendingGenerations = PendingGenerationStore(preferences);
    desktopEngine = localEngine ?? createDesktopEngine();
    readLocalPreference = () async => preferences.getBool('desktop_local_mode');
    saveLocalPreference = (value) async {
      await preferences.setBool('desktop_local_mode', value);
    };
    final factory = clientFactory ?? http.Client.new;
    final api = JsonApiClient(factory);
    adminUsers = AdminUsersRepositoryImpl(api);
    loadServerStatus = LoadServerStatus(ServerStatusRepositoryImpl(api));
    manageProxy = ManageProxy(ProxyRepositoryImpl(api));
    chatHistory = ManageChatHistory(
      ChatHistoryRepositoryImpl(
        historyStore ?? const SecureHistoryRecordStore(),
      ),
    );
    final videos = VideoRepositoryImpl(api);
    generateVideo = GenerateVideo(videos);
    getVideoTask = GetVideoTask(videos);
    loadTasks = LoadTasks(TaskRepositoryImpl(api));
    final media = MediaRepositoryImpl(api);
    loadMedia = LoadMedia(media);
    storageRepository = media;
    manageAccounts = ManageAccounts(AccountRepositoryImpl(api));
    final images = ImageRepositoryImpl(ImageRemoteDataSource(factory));
    generateImage = GenerateImage(images);
    getImageTask = GetImageTask(images);
    connectionRepository = ConnectionRepositoryImpl(
      ConnectionRemoteDataSource(factory),
      ConnectionLocalDataSource(
        preferences,
        credentialStore ?? const SecureCredentialStore(),
      ),
    );
    connectServer = ConnectServer(connectionRepository);
    restoreConnection = RestoreConnection(connectionRepository);
    forgetConnection = ForgetConnection(connectionRepository);
    sendMessage = SendMessage(
      ChatRepositoryImpl(ChatRemoteDataSource(factory)),
    );
  }
  // Intentionally separate from the Muse transport factory.
  final imagePromptRepository = ImagePromptRepositoryImpl(http.Client.new);
  final textPromptRepository = TextPromptRepositoryImpl(http.Client.new);
  final saveMedia = SaveMedia(createMediaSaver());
  final pickReferenceImages = const PickReferenceImages(
    DeviceReferenceFileSource(),
  );
  late final PendingGenerationStore pendingGenerations;
  late final AdminUsersRepository adminUsers;
  late final ConnectionRepositoryImpl connectionRepository;
  late final DesktopEngine desktopEngine;
  late final Future<bool?> Function() readLocalPreference;
  late final Future<void> Function(bool) saveLocalPreference;
  late final ConnectServer connectServer;
  late final RestoreConnection restoreConnection;
  late final ForgetConnection forgetConnection;
  late final SendMessage sendMessage;
  late final GenerateImage generateImage;
  late final GetImageTask getImageTask;
  late final GenerateVideo generateVideo;
  late final GetVideoTask getVideoTask;
  late final LoadTasks loadTasks;
  late final LoadMedia loadMedia;
  late final StorageRepository storageRepository;
  late final ManageAccounts manageAccounts;
  late final ManageProxy manageProxy;
  late final LoadServerStatus loadServerStatus;
  late final ManageChatHistory chatHistory;
}
