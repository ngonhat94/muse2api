import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../connection/domain/entities/server_connection.dart';
import '../../domain/repositories/admin_users_repository.dart';
import '../cubit/admin_users_cubit.dart';

// Scoped to the visible secret and connection: hiding the key or replacing the
// session disposes pending clipboard feedback along with this widget.
class _OneTimeApiKey extends StatefulWidget {
  const _OneTimeApiKey({super.key, required this.apiKey});

  final String apiKey;

  @override
  State<_OneTimeApiKey> createState() => _OneTimeApiKeyState();
}

class _OneTimeApiKeyState extends State<_OneTimeApiKey> {
  bool _copying = false;

  Future<void> _copy() async {
    if (_copying) return;
    setState(() => _copying = true);
    final key = widget.apiKey;
    var message = 'Đã sao chép API key';
    try {
      await Clipboard.setData(ClipboardData(text: key));
    } catch (_) {
      message =
          'Không thể sao chép API key. Hãy chọn key và sao chép thủ công.';
    }
    if (!mounted || widget.apiKey != key) return;
    setState(() => _copying = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: SelectableText(widget.apiKey)),
      const SizedBox(width: 8),
      IconButton(
        tooltip: 'Sao chép API key',
        onPressed: _copying ? null : _copy,
        icon: _copying
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.copy_outlined),
      ),
    ],
  );
}

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({
    super.key,
    required this.repository,
    required this.connection,
  });
  final AdminUsersRepository repository;
  final ServerConnection? connection;
  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  final _label = TextEditingController();
  late final AdminUsersCubit _cubit;
  @override
  void initState() {
    super.initState();
    _cubit = AdminUsersCubit(widget.repository)..connect(widget.connection);
  }

  @override
  void didUpdateWidget(covariant AdminUsersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.connection != widget.connection) {
      _label.clear();
      _cubit.connect(widget.connection);
    }
  }

  @override
  void dispose() {
    _cubit.close();
    _label.dispose();
    super.dispose();
  }

  Future<void> _action(AdminUser user, String action) async {
    final connection = widget.connection;
    if (action != 'enable') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            action == 'rotate'
                ? 'Đổi API key?'
                : action == 'disable'
                ? 'Tắt người dùng?'
                : 'Thu hồi API key?',
          ),
          content: Text(
            action == 'disable'
                ? 'Các yêu cầu của ${user.label} sẽ bị từ chối cho đến khi bật lại.'
                : 'Key hiện tại của ${user.label} sẽ mất hiệu lực. Không thể hoàn tác.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xác nhận'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true || connection != widget.connection) {
        return;
      }
    }
    if (!mounted ||
        connection != widget.connection ||
        !canManageUsers(connection)) {
      return;
    }
    switch (action) {
      case 'rotate':
        await _cubit.rotate(user);
      case 'disable':
      case 'enable':
        await _cubit.toggle(user);
      case 'revoke':
        await _cubit.revoke(user);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.connection == null) {
      return const Center(child: Text('Chưa kết nối server.'));
    }
    if (!canManageUsers(widget.connection)) {
      return const Center(
        child: Text('Bạn không có quyền quản lý người dùng.'),
      );
    }
    return BlocBuilder<AdminUsersCubit, AdminUsersState>(
      bloc: _cubit,
      builder: (context, state) {
        final busy = state.loading || state.mutating;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Người dùng & API key',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  onPressed: busy ? null : _cubit.load,
                  tooltip: 'Tải lại',
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'API key mới chỉ hiển thị một lần. Hãy lưu ngay khi tạo hoặc đổi key.',
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _label,
              enabled: !busy,
              decoration: const InputDecoration(labelText: 'Tên người dùng'),
              onSubmitted: busy ? null : (_) => _cubit.create(_label.text),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: busy ? null : () => _cubit.create(_label.text),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Tạo user & key'),
              ),
            ),
            if (busy) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
            ],
            if (state.oneTimeKey != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('LƯU KEY NGAY — chỉ hiển thị lần này:'),
                      const SizedBox(height: 8),
                      _OneTimeApiKey(
                        key: ObjectKey(widget.connection),
                        apiKey: state.oneTimeKey!,
                      ),
                      TextButton(
                        onPressed: _cubit.dismissKey,
                        child: const Text('Đã lưu, ẩn key'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (state.error != null) ...[
              const SizedBox(height: 16),
              Text(
                state.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            if (state.users.isEmpty && !state.loading)
              const Text('Chưa có người dùng nào.'),
            for (final user in state.users) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(user.label),
                subtitle: Text(
                  '${user.id} · ${user.enabled ? 'Đang bật' : 'Đã tắt'}',
                ),
                trailing: PopupMenuButton<String>(
                  enabled: !busy,
                  tooltip: 'Thao tác với ${user.label}',
                  onSelected: (action) => _action(user, action),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'rotate',
                      child: Text('Đổi key'),
                    ),
                    PopupMenuItem(
                      value: user.enabled ? 'disable' : 'enable',
                      child: Text(user.enabled ? 'Tắt' : 'Bật'),
                    ),
                    const PopupMenuItem(
                      value: 'revoke',
                      child: Text('Thu hồi'),
                    ),
                  ],
                ),
              ),
              const Divider(),
            ],
          ],
        );
      },
    );
  }
}
