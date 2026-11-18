import '../../../../app/studio_theme.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/connection_bloc.dart';
import 'local_engine_panel.dart';
import 'client_config_editor.dart';
import '../../domain/repositories/client_config_repository.dart';

class ConnectionPage extends StatefulWidget {
  const ConnectionPage({super.key, this.savedAddress});
  final String? savedAddress;
  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  final _key = TextEditingController();
  bool _obscure = true;
  bool _bootstrapAdmin = false;
  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<ConnectionBloc, ServerConnectionState>(
    listener: (context, state) {
      final saved = state.savedConnection;
      if (saved != null && state.error == null) {
        final bloc = context.read<ConnectionBloc>();
        _key.text =
            saved.baseUrl ==
                (_bootstrapAdmin ? bootstrapServerUrl : bloc.sharedAddress)
            ? saved.apiKey
            : '';
      } else if (state.status == ConnectionStatus.disconnected &&
          state.error == null) {
        _key.clear();
      }
    },
    builder: (context, state) {
      final bloc = context.read<ConnectionBloc>();
      final busy =
          state.status == ConnectionStatus.connecting || bloc.loadingConfig;
      final connected =
          state.status == ConnectionStatus.connected && !state.localMode;
      final localAvailable = context.read<ConnectionBloc>().supportsLocal;
      final remotePanel = Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    connected ? Icons.check_circle_outline : Icons.dns_outlined,
                    color: connected ? Colors.tealAccent : Colors.white60,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      connected ? 'Đã kết nối' : 'Đăng nhập server',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Địa chỉ server',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SelectableText(
                state.connection?.baseUrl ??
                    (_bootstrapAdmin ? bootstrapServerUrl : bloc.sharedAddress),
              ),
              if (!connected && bloc.sharedAddress != bootstrapServerUrl)
                CheckboxListTile(
                  value: _bootstrapAdmin,
                  onChanged: busy
                      ? null
                      : (value) => setState(() {
                          _bootstrapAdmin = value == true;
                          _key.clear();
                        }),
                  title: const Text('Quản trị cấu hình tại server bootstrap'),
                ),
              const Text(
                'Server do quản trị viên cấu hình. Bạn chỉ cần nhập API key.',
              ),
              const SizedBox(height: 20),
              if (!connected)
                TextField(
                  controller: _key,
                  enabled: !busy,
                  obscureText: _obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  onSubmitted: (_) {
                    if (!busy) _connect(context);
                  },
                  decoration: InputDecoration(
                    labelText: 'API key',
                    hintText: 'm2a_…',
                    prefixIcon: const Icon(Icons.key_outlined),
                    suffixIcon: IconButton(
                      tooltip: _obscure ? 'Hiện API key' : 'Ẩn API key',
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                ),
              if (!state.localMode && state.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    state.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (connected && state.connection?.principal != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Semantics(
                    label: state.connection!.isAdmin
                        ? 'Quyền quản trị viên'
                        : 'Quyền người dùng riêng',
                    child: Row(
                      children: [
                        Icon(
                          state.connection!.isAdmin
                              ? Icons.admin_panel_settings_outlined
                              : Icons.person_outline,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.connection!.isAdmin
                                ? 'Quản trị viên · có quyền cấu hình toàn server'
                                : 'Người dùng · chỉ thấy tài khoản, tác vụ và media của bạn',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (connected &&
                  state.connection?.principal?.isAdmin == true &&
                  state.connection?.principal?.can('global_settings') == true &&
                  bloc.clientConfig != null)
                ClientConfigEditor(
                  key: ObjectKey(state.connection),
                  connection: state.connection!,
                  repository: bloc.clientConfig!,
                  address: bloc.sharedAddress,
                ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: busy || state.connection?.isLocal == true
                    ? null
                    : () {
                        if (connected) {
                          context.read<ConnectionBloc>().add(
                            ConnectionDisconnected(),
                          );
                        } else {
                          _connect(context);
                        }
                      },
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        connected ? Icons.logout : Icons.arrow_forward_rounded,
                      ),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    busy
                        ? 'Đang kiểm tra…'
                        : connected
                        ? 'Ngắt kết nối'
                        : 'Kiểm tra và kết nối',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (state.savedConnection != null)
                TextButton.icon(
                  onPressed: busy || state.connection?.isLocal == true
                      ? null
                      : () => context.read<ConnectionBloc>().add(
                          ConnectionForgotten(),
                        ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Quên API key đã lưu'),
                ),
              const Text(
                'Ứng dụng nhớ API key trên thiết bị, chỉ tự kết nối lại khi địa chỉ không đổi. '
                'Ngắt kết nối vẫn giữ key; chọn Quên API key để xóa.',
                style: TextStyle(
                  color: StudioColors.muted,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 580),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kết nối Muse của bạn',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  localAvailable
                      ? 'Chọn nơi xử lý tác vụ Muse của bạn.'
                      : 'Kết nối đến server muse2api để bắt đầu trò chuyện.',
                  style: TextStyle(color: Colors.white60, height: 1.6),
                ),
                const SizedBox(height: 28),
                if (localAvailable) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: LocalEnginePanel(state: state),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                if (localAvailable)
                  ExpansionTile(
                    key: ValueKey(connected),
                    initiallyExpanded: connected,
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Dùng server riêng'),
                    subtitle: const Text(
                      'Giữ cấu hình server và API key đã lưu',
                    ),
                    children: [remotePanel],
                  )
                else
                  remotePanel,
              ],
            ),
          ),
        ),
      );
    },
  );
  void _connect(BuildContext context) {
    final bloc = context.read<ConnectionBloc>();
    if (bloc.state.connection?.isLocal == true ||
        bloc.state.status == ConnectionStatus.connecting) {
      return;
    }
    if (bloc.loadingConfig) return;
    bloc.add(
      ConnectionRequested(
        _bootstrapAdmin ? bootstrapServerUrl : bloc.sharedAddress,
        _key.text,
      ),
    );
  }
}
