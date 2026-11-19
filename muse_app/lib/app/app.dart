import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/accounts/domain/usecases/manage_proxy.dart';
import '../core/domain/pick_reference_images.dart';
import '../core/domain/save_media.dart';
import 'studio_theme.dart';
import '../core/presentation/generation_recovery_cubit.dart';
import '../features/image_prompt/presentation/image_prompt_cubit.dart';
import '../features/text_prompt/presentation/text_prompt_cubit.dart';
import '../features/status/presentation/bloc/server_status_bloc.dart';
import '../features/videos/presentation/bloc/video_bloc.dart';
import '../features/tasks/presentation/bloc/task_bloc.dart';
import '../features/media/presentation/bloc/media_bloc.dart';
import '../features/accounts/presentation/bloc/account_bloc.dart';
import '../features/images/presentation/bloc/image_bloc.dart';
import '../features/chat/presentation/bloc/chat_bloc.dart';
import '../features/connection/presentation/bloc/connection_bloc.dart';
import '../features/connection/presentation/pages/key_login_page.dart';
import 'dependencies.dart';
import 'shell.dart';

class MuseApp extends StatelessWidget {
  const MuseApp({
    super.key,
    required this.dependencies,
    this.requireKey = kIsWeb,
  });
  final AppDependencies dependencies;

  /// Explicit override allows the actual web boundary to be exercised on the VM.
  final bool requireKey;

  @override
  Widget build(
    BuildContext context,
  ) => RepositoryProvider<AppDependencies>.value(
    value: dependencies,
    child: RepositoryProvider<SaveMedia>.value(
      value: dependencies.saveMedia,
      child: RepositoryProvider<PickReferenceImages>.value(
        value: dependencies.pickReferenceImages,
        child: RepositoryProvider<ManageProxy>.value(
          value: dependencies.manageProxy,
          child: BlocProvider(
            create: (_) => ConnectionBloc(
              dependencies.connectServer,
              startRestoring: requireKey,
              restore: dependencies.restoreConnection,
              clientConfig: dependencies.clientConfig,
              forget: dependencies.forgetConnection,
              desktop: dependencies.desktopEngine,
              readLocalPreference: dependencies.readLocalPreference,
              saveLocalPreference: dependencies.saveLocalPreference,
              onSessionEnded: dependencies.endSession,
              onSessionStarting: dependencies.startSession,
            )..add(ConnectionRestored()),
            child: BlocBuilder<ConnectionBloc, ServerConnectionState>(
              builder: (context, state) {
                final authenticated =
                    !requireKey ||
                    (state.status == ConnectionStatus.connected &&
                        state.connection?.principal != null);
                return MaterialApp(
                  // Replacing the Navigator also removes dialogs/routes carrying
                  // secrets. Session-scoped providers below are disposed as well.
                  key: requireKey
                      ? ObjectKey(state.connection)
                      : ValueKey(context.read<ConnectionBloc>().logoutRevision),
                  title: 'Muse Studio',
                  debugShowCheckedModeBanner: false,
                  theme: StudioTheme.dark,
                  home: authenticated
                      ? _Session(dependencies: dependencies, web: requireKey)
                      : const KeyLoginPage(),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}

class _Session extends StatefulWidget {
  const _Session({required this.dependencies, required this.web});
  final AppDependencies dependencies;
  final bool web;

  @override
  State<_Session> createState() => _SessionState();
}

class _SessionState extends State<_Session> {
  AppDependencies get dependencies => widget.dependencies;
  bool get web => widget.web;
  void Function(Uri, String)? _rejected;

  @override
  void initState() {
    super.initState();
    if (!web) return;
    final bloc = context.read<ConnectionBloc>();
    final connection = bloc.state.connection;
    _rejected = (uri, authorization) {
      if (!mounted ||
          connection == null ||
          !identical(bloc.state.connection, connection) ||
          authorization != connection.headers['Authorization'] ||
          uri.origin != Uri.parse(connection.baseUrl).origin)
        return;
      bloc.add(ConnectionDisconnected());
    };
    dependencies.onCredentialRejected = _rejected;
  }

  @override
  void dispose() {
    if (identical(dependencies.onCredentialRejected, _rejected)) {
      dependencies.onCredentialRejected = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (_) => GenerationRecoveryCubit(
          dependencies.pendingGenerations,
          dependencies.getImageTask,
          dependencies.getVideoTask,
        ),
      ),
      BlocProvider(
        create: (_) => TextPromptCubit(dependencies.textPromptRepository),
      ),
      BlocProvider(
        create: (_) => ImagePromptCubit(dependencies.imagePromptRepository),
      ),
      BlocProvider(
        create: (_) => ChatBloc(
          dependencies.sendMessage,
          history: dependencies.chatHistory,
        ),
      ),
      BlocProvider(
        create: (_) => VideoBloc(
          dependencies.generateVideo,
          dependencies.getVideoTask,
          pendingStore: dependencies.pendingGenerations,
        ),
      ),
      BlocProvider(
        create: (_) => ServerStatusBloc(dependencies.loadServerStatus),
      ),
      BlocProvider(create: (_) => TaskBloc(dependencies.loadTasks)),
      BlocProvider(create: (_) => MediaBloc(dependencies.loadMedia)),
      BlocProvider(create: (_) => AccountBloc(dependencies.manageAccounts)),
      BlocProvider(
        create: (_) => ImageBloc(
          dependencies.generateImage,
          dependencies.getImageTask,
          pendingStore: dependencies.pendingGenerations,
        ),
      ),
    ],
    child: AppShell(
      storageRepository: dependencies.storageRepository,
      savedAddress: dependencies.connectionRepository.savedAddress,
      startConnected: web,
    ),
  );
}
