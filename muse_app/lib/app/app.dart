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

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/chat/presentation/bloc/chat_bloc.dart';
import '../features/connection/presentation/bloc/connection_bloc.dart';
import 'dependencies.dart';
import 'shell.dart';

class MuseApp extends StatelessWidget {
  const MuseApp({super.key, required this.dependencies});
  final AppDependencies dependencies;
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
          child: MultiBlocProvider(
            providers: [
              BlocProvider(
                create: (_) => GenerationRecoveryCubit(
                  dependencies.pendingGenerations,
                  dependencies.getImageTask,
                  dependencies.getVideoTask,
                ),
              ),
              BlocProvider(
                create: (_) =>
                    TextPromptCubit(dependencies.textPromptRepository),
              ),
              BlocProvider(
                create: (_) =>
                    ImagePromptCubit(dependencies.imagePromptRepository),
              ),
              BlocProvider(
                create: (_) => ConnectionBloc(
                  dependencies.connectServer,
                  restore: dependencies.restoreConnection,
                  clientConfig: dependencies.clientConfig,
                  forget: dependencies.forgetConnection,
                  desktop: dependencies.desktopEngine,
                  readLocalPreference: dependencies.readLocalPreference,
                  saveLocalPreference: dependencies.saveLocalPreference,
                )..add(ConnectionRestored()),
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
              BlocProvider(
                create: (_) => AccountBloc(dependencies.manageAccounts),
              ),
              BlocProvider(
                create: (_) => ImageBloc(
                  dependencies.generateImage,
                  dependencies.getImageTask,
                  pendingStore: dependencies.pendingGenerations,
                ),
              ),
            ],
            child: MaterialApp(
              title: 'Muse Studio',
              debugShowCheckedModeBanner: false,
              theme: StudioTheme.dark,
              home: AppShell(
                storageRepository: dependencies.storageRepository,
                savedAddress: dependencies.connectionRepository.savedAddress,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
