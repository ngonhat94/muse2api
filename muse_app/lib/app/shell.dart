import 'studio_theme.dart';
import '../features/connection/domain/entities/connection_permissions.dart';
import 'dependencies.dart';
import '../features/admin/domain/repositories/admin_users_repository.dart';
import '../core/presentation/generation_recovery_cubit.dart';
import '../core/presentation/generation_recovery_panel.dart';
import '../features/text_prompt/presentation/text_prompt_page.dart';
import '../features/image_prompt/presentation/image_prompt_page.dart';
import '../features/status/presentation/bloc/server_status_bloc.dart';
import '../features/status/presentation/pages/server_status_page.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/presentation/collection_bloc.dart';
import '../features/accounts/presentation/bloc/account_bloc.dart';
import '../features/accounts/presentation/pages/account_page.dart';
import '../features/chat/presentation/bloc/chat_bloc.dart';
import '../features/chat/presentation/pages/chat_page.dart';
import '../features/connection/presentation/bloc/connection_bloc.dart';
import '../features/connection/presentation/pages/connection_page.dart';
import '../features/images/presentation/bloc/image_bloc.dart';
import '../features/images/presentation/pages/image_page.dart';
import '../features/videos/presentation/bloc/video_bloc.dart';
import '../features/videos/presentation/pages/video_page.dart';
import '../features/tasks/presentation/bloc/task_bloc.dart';
import '../features/tasks/presentation/pages/task_page.dart';
import '../features/media/presentation/bloc/media_bloc.dart';
import '../features/media/domain/repositories/storage_repository.dart';
import '../features/media/presentation/pages/media_page.dart';
import '../features/admin/presentation/pages/admin_users_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    this.savedAddress,
    this.storageRepository,
    this.startConnected = false,
  });
  final bool startConnected;
  final StorageRepository? storageRepository;
  final String? savedAddress;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.startConnected) {
      _selected = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final connection = context.read<ConnectionBloc>().state.connection;
        context.read<GenerationRecoveryCubit>().connect(connection);
        context.read<ServerStatusBloc>().connectionChanged(connection);
        context.read<ChatBloc>().add(ChatSessionChanged(connection));
      });
    }
  }

  @override
  void dispose() {
    _imagePrompt.dispose();
    _videoPrompt.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      context.read<ChatBloc>().add(ChatHistoryFlushed());
    }
  }

  int _selected = 6;
  final _imagePrompt = TextEditingController();
  final _videoPrompt = TextEditingController();
  static const _destinations = [
    (Icons.chat_bubble_outline_rounded, 'Trò chuyện'),
    (Icons.image_outlined, 'Tạo ảnh'),
    (Icons.movie_outlined, 'Tạo video'),
    (Icons.checklist_rounded, 'Tác vụ'),
    (Icons.photo_library_outlined, 'Thư viện'),
    (Icons.people_outline, 'Tài khoản'),
    (Icons.dns_outlined, 'Kết nối Muse'),
    (Icons.monitor_heart_outlined, 'Trạng thái server'),
    (Icons.image_search_outlined, 'Ảnh thành prompt'),
    (Icons.auto_fix_high_outlined, 'Văn bản thành prompt'),
    (Icons.admin_panel_settings_outlined, 'Người dùng & API key'),
  ];
  bool _canSelect(int index) {
    final bloc = context.read<ConnectionBloc>();
    if (index == 6) {
      return canShowConnectionTools(
        bloc.state.connection,
        supportsLocal: bloc.supportsLocal,
      );
    }
    if (index == 7) return canConfigureServer(bloc.state.connection);
    if (index == 10) return canManageUsers(bloc.state.connection);
    return true;
  }

  void _select(int index) {
    if (!_canSelect(index)) {
      return;
    }
    context.read<TaskBloc>().add(CollectionPaused());
    setState(() => _selected = index);
    final connection = context.read<ConnectionBloc>().state.connection;
    if (connection == null) return;
    if (index == 3) {
      context.read<GenerationRecoveryCubit>().connect(connection);
      context.read<TaskBloc>().add(CollectionLoaded(connection, poll: true));
    }
    if (index == 4) context.read<MediaBloc>().add(CollectionLoaded(connection));
    if (index == 5) context.read<AccountBloc>().add(AccountsLoaded(connection));
  }

  void _createImage(String prompt) => _handoff(prompt, false);
  void _createVideo(String prompt) => _handoff(prompt, true);
  Future<void> _handoff(String prompt, bool video) async {
    final controller = video ? _videoPrompt : _imagePrompt;
    final previous = controller.text;
    if (previous.isNotEmpty && previous != prompt) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Thay mô tả hiện tại?'),
          content: const Text(
            'Chỉ thay mô tả. Ảnh tham chiếu và tùy chọn khác được giữ nguyên. Không tự gửi yêu cầu tạo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Giữ mô tả'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Thay mô tả'),
            ),
          ],
        ),
      );
      if (!mounted || replace != true || controller.text != previous) return;
    }
    if (!mounted) return;
    controller.text = prompt;
    _select(video ? 2 : 1);
  }

  void _resumeVideo(String id) {
    final connection = context.read<ConnectionBloc>().state.connection;
    if (connection == null) return;
    _select(2);
    context.read<VideoBloc>().add(VideoResumed(connection, id));
  }

  bool _confirmingLogout = false;
  Future<void> _logout() async {
    final bloc = context.read<ConnectionBloc>();
    final connection = bloc.state.connection;
    if (_confirmingLogout || connection == null || connection.isLocal) return;
    _confirmingLogout = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đăng xuất khỏi Muse Studio?'),
        content: const Text(
          'API key đã lưu trên thiết bị này sẽ bị xóa. Nội dung chưa lưu sẽ mất. '
          'Tác vụ đang chạy trên server vẫn tiếp tục; đăng xuất không thu hồi API key.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
    _confirmingLogout = false;
    if (!mounted ||
        confirmed != true ||
        !identical(bloc.state.connection, connection)) {
      return;
    }
    bloc.add(LogoutRequested());
  }

  Widget _logoutButton() => ListTile(
    leading: const Icon(Icons.logout_rounded),
    title: const Text('Đăng xuất'),
    onTap: _logout,
  );

  void _more() => showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (context.read<ConnectionBloc>().state.connection
                case final connection? when !connection.isLocal) ...[
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Đăng xuất'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _logout();
                },
              ),
              const Divider(),
            ],
            for (var i = 3; i < _destinations.length; i++)
              if (_canSelect(i))
                ListTile(
                  leading: Icon(_destinations[i].$1),
                  title: Text(_destinations[i].$2),
                  selected: _selected == i,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _select(i);
                  },
                ),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(
    BuildContext context,
  ) => BlocListener<ConnectionBloc, ServerConnectionState>(
    listenWhen: (previous, current) =>
        previous.connection != current.connection,
    listener: (context, state) {
      context.read<GenerationRecoveryCubit>().connect(state.connection);
      context.read<ServerStatusBloc>().connectionChanged(state.connection);
      context.read<ChatBloc>().add(ChatSessionChanged(state.connection));
      context.read<ImageBloc>().add(ImagesCleared(connectionChanged: true));
      context.read<VideoBloc>().add(VideosCleared());
      context.read<TaskBloc>().add(CollectionCleared());
      context.read<MediaBloc>().add(CollectionCleared());
      context.read<AccountBloc>().add(AccountsCleared());
      setState(
        () => _selected = state.connection == null
            ? 6
            : state.connection!.isLocal
            ? 5
            : 0,
      );
      if (state.connection?.isLocal == true) {
        context.read<AccountBloc>().add(AccountsLoaded(state.connection!));
      }
    },
    child: LayoutBuilder(
      builder: (context, constraints) {
        context.watch<ConnectionBloc>();
        final wide = constraints.maxWidth >= 800;
        final selected = _canSelect(_selected) ? _selected : 0;
        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                if (wide)
                  SizedBox(
                    width: 248,
                    child: Material(
                      color: StudioColors.surface,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(20, 28, 16, 28),
                            child: Row(
                              children: [
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: StudioColors.selected,
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(10),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.all(10),
                                    child: Icon(
                                      Icons.hub_outlined,
                                      color: StudioColors.accent,
                                      size: 24,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Muse Studio',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(),
                          const SizedBox(height: 16),
                          Expanded(
                            child: ListView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              children: [
                                for (var i = 0; i < _destinations.length; i++)
                                  if (_canSelect(i))
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      child: ListTile(
                                        selected: _selected == i,
                                        selectedTileColor:
                                            StudioColors.selected,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        leading: Icon(_destinations[i].$1),
                                        title: Text(_destinations[i].$2),
                                        onTap: () => _select(i),
                                      ),
                                    ),
                              ],
                            ),
                          ),
                          if (context.read<ConnectionBloc>().state.connection
                              case final connection? when !connection.isLocal)
                            _logoutButton(),
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Không gian sáng tạo của bạn',
                              style: TextStyle(
                                color: StudioColors.muted,
                                height: 1.7,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (wide) const VerticalDivider(width: 1),
                Expanded(
                  child: IndexedStack(
                    index: selected,
                    children: [
                      ChatPage(
                        onConfigure: () => _select(6),
                        onCreateImage: _createImage,
                      ),
                      ImagePage(
                        key: ValueKey(
                          context.read<ConnectionBloc>().state.connection,
                        ),
                        promptController: _imagePrompt,
                        onConfigure: () => _select(6),
                      ),
                      VideoPage(
                        key: ValueKey(
                          context.read<ConnectionBloc>().state.connection,
                        ),
                        onConfigure: () => _select(6),
                        onTasks: () => _select(3),
                        promptController: _videoPrompt,
                      ),
                      Column(
                        children: [
                          const GenerationRecoveryPanel(),
                          Expanded(
                            child: TaskPage(onResumeVideo: _resumeVideo),
                          ),
                        ],
                      ),
                      MediaPage(storageRepository: widget.storageRepository),
                      AccountPage(
                        key: ValueKey(
                          context.read<ConnectionBloc>().state.connection,
                        ),
                      ),
                      if (_selected == 6 && _canSelect(6))
                        ConnectionPage(savedAddress: widget.savedAddress)
                      else
                        const SizedBox.shrink(),
                      if (_selected == 7 && _canSelect(7))
                        const ServerStatusPage()
                      else
                        const SizedBox.shrink(),
                      ImagePromptPage(
                        onCreateImage: _createImage,
                        onCreateVideo: _createVideo,
                      ),
                      TextPromptPage(
                        onCreateImage: _createImage,
                        onCreateVideo: _createVideo,
                      ),
                      if (_selected == 10 && _canSelect(10))
                        AdminUsersPage(
                          key: ValueKey(
                            context.read<ConnectionBloc>().state.connection,
                          ),
                          repository: context
                              .read<AppDependencies>()
                              .adminUsers,
                          connection: context
                              .read<ConnectionBloc>()
                              .state
                              .connection,
                        )
                      else
                        const SizedBox.shrink(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: _selected < 3 ? _selected : 3,
                  onDestinationSelected: (index) =>
                      index < 3 ? _select(index) : _more(),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.chat_bubble_outline),
                      label: 'Chat',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.image_outlined),
                      label: 'Ảnh',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.movie_outlined),
                      label: 'Video',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.menu),
                      label: 'Thêm',
                    ),
                  ],
                ),
        );
      },
    ),
  );
}
