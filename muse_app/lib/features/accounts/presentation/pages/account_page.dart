import '../../../../app/studio_theme.dart';
import 'cookie_import_form.dart';
import 'keepalive_status_section.dart';
import '../../domain/repositories/batch_keepalive_repository.dart';
import '../../domain/repositories/keepalive_status_repository.dart';
import 'proxy_editor.dart';
import 'cookie_update_dialog.dart';
import 'account_quota_section.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/list_header.dart';
import '../../../connection/domain/entities/server_connection.dart';
import '../../../connection/presentation/bloc/connection_bloc.dart';
import '../../domain/repositories/account_repository.dart';
import '../bloc/account_bloc.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool _showImport = false;
  @override
  void initState() {
    super.initState();
    _showImport =
        context.read<ConnectionBloc>().state.connection?.isLocal == true;
  }

  Future<void> _updateCookies(ServerConnection connection, String id) async {
    final accounts = context.read<AccountBloc>();
    final connections = context.read<ConnectionBloc>();
    var invalidated = false;
    final subscription = connections.stream.listen((state) {
      if (!identical(state.connection, connection)) invalidated = true;
    });
    try {
      await showDialog<void>(
        context: context,
        builder: (_) => CookieUpdateDialog(
          isCurrent: () =>
              mounted &&
              !invalidated &&
              identical(connections.state.connection, connection) &&
              !accounts.state.busy &&
              accounts.state.items.any((a) => a.id == id),
          onSubmit: (cookies) =>
              accounts.add(AccountCookiesUpdated(connection, id, cookies)),
        ),
      );
    } finally {
      await subscription.cancel();
    }
  }

  bool _keepaliveDialogOpen = false;

  Future<void> _keepalive(ServerConnection connection, String? id) async {
    if (_keepaliveDialogOpen) return;
    final accounts = context.read<AccountBloc>();
    final connections = context.read<ConnectionBloc>();
    if (accounts.state.busy ||
        (id != null && !accounts.state.items.any((a) => a.id == id))) {
      return;
    }
    _keepaliveDialogOpen = true;
    var invalidated = false;
    var submitted = false;
    final connectionSubscription = connections.stream.listen((state) {
      if (!identical(state.connection, connection)) invalidated = true;
    });
    final accountSubscription = accounts.stream.listen((state) {
      if (state.busy || (id != null && !state.items.any((a) => a.id == id))) {
        invalidated = true;
      }
    });
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          scrollable: true,
          title: Text(
            id == null ? 'Duy trì phiên hàng loạt?' : 'Duy trì phiên?',
          ),
          content: Text(
            id == null
                ? 'Việc chọn các tài khoản đang bật là chính sách server; cấu hình server có thể bao gồm cả tài khoản đã tắt. Server dùng cookie và proxy đã lưu (hoặc kết nối trực tiếp nếu không có proxy). Thao tác có thể đánh thức workspace và mất nhiều thời gian. Không bảo đảm kéo dài phiên; không cập nhật quota. Chỉ gửi một lần, không tự thử lại.'
                : 'Server sẽ dùng cookie và proxy đã lưu của tài khoản (hoặc kết nối trực tiếp nếu không có proxy) để làm mới phiên. Thao tác có thể đánh thức workspace. Không thay cookie thủ công và không cập nhật quota; quota vẫn là dữ liệu lưu đệm.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                if (submitted) return;
                submitted = true;
                if (mounted &&
                    !invalidated &&
                    identical(connections.state.connection, connection) &&
                    !accounts.state.busy &&
                    (id == null ||
                        accounts.state.items.any((a) => a.id == id))) {
                  accounts.add(
                    id == null
                        ? AccountsBatchKeepaliveRequested(connection)
                        : AccountActed(connection, id, AccountAction.keepalive),
                  );
                }
                Navigator.pop(dialogContext);
              },
              child: Text(
                id == null ? 'Chạy đợt duy trì phiên' : 'Duy trì phiên',
              ),
            ),
          ],
        ),
      );
    } finally {
      _keepaliveDialogOpen = false;
      await connectionSubscription.cancel();
      await accountSubscription.cancel();
    }
  }

  Future<void> _remove(ServerConnection connection, String id) async {
    final bloc = context.read<AccountBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa tài khoản?'),
        content: const Text('Tài khoản sẽ bị xóa khỏi pool trên server.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true &&
        mounted &&
        context.read<ConnectionBloc>().state.connection == connection) {
      bloc.add(AccountActed(connection, id, AccountAction.remove));
    }
  }

  @override
  Widget build(BuildContext context) => BlocConsumer<AccountBloc, AccountState>(
    listener: (context, state) {
      if (state.imported) {
        setState(() => _showImport = false);
      }
    },
    builder: (context, state) {
      final connection = context.watch<ConnectionBloc>().state.connection;
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          ListHeader(
            title: 'Tài khoản Muse',
            loading: state.busy,
            error: state.error,
            onRefresh: connection == null
                ? null
                : () => context.read<AccountBloc>().add(
                    AccountsLoaded(connection),
                  ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 4, bottom: 20),
            child: Text(
              'Quản lý pool tài khoản, phiên và quota lưu đệm.',
              style: TextStyle(color: StudioColors.muted),
            ),
          ),
          const Divider(),
          const SizedBox(height: 20),
          if (state.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Wrap(
                spacing: 24,
                runSpacing: 8,
                children: [
                  Text('${state.items.length} tài khoản'),
                  Text(
                    '${state.items.where((a) => a.enabled).length} đang bật',
                  ),
                  Text(
                    '${state.items.where((a) => a.healthy == true).length} phiên đã xác nhận',
                    style: const TextStyle(color: StudioColors.muted),
                  ),
                ],
              ),
            ),
          if (state.message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                state.message!,
                style: const TextStyle(color: StudioColors.success),
              ),
            ),
          if (connection == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Kết nối server để quản lý tài khoản.'),
            )
          else ...[
            if (context.read<AccountBloc>().manage.repository
                is BatchKeepaliveRepository)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: state.busy
                      ? null
                      : () => _keepalive(connection, null),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Duy trì phiên hàng loạt'),
                ),
              ),
            if (context.read<AccountBloc>().manage.repository
                is KeepaliveStatusRepository)
              KeepaliveStatusSection(
                key: ObjectKey(connection),
                accounts: context.read<AccountBloc>(),
                connection: connection,
                repository:
                    context.read<AccountBloc>().manage.repository
                        as KeepaliveStatusRepository,
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: state.busy
                    ? null
                    : () => setState(() => _showImport = !_showImport),
                icon: const Icon(Icons.person_add_outlined),
                label: const Text('Nhập tài khoản'),
              ),
            ),
            if (_showImport)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: CookieImportForm(
                    key: ValueKey(connection),
                    busy: state.busy,
                    localMode: connection.isLocal,
                    onSubmit: (label, cookies) {
                      if (!identical(
                            context.read<ConnectionBloc>().state.connection,
                            connection,
                          ) ||
                          context.read<AccountBloc>().state.busy) {
                        return;
                      }
                      context.read<AccountBloc>().add(
                        AccountImported(connection, label, cookies),
                      );
                    },
                  ),
                ),
              ),
            if (state.items.isEmpty && !state.busy)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Chưa có tài khoản trong pool.'),
              ),
            for (final account in state.items)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                account.label,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Semantics(
                              label: 'Bật tài khoản ${account.label}',
                              child: Switch(
                                value: account.enabled,
                                onChanged: state.busy
                                    ? null
                                    : (enabled) =>
                                          context.read<AccountBloc>().add(
                                            AccountActed(
                                              connection,
                                              account.id,
                                              enabled
                                                  ? AccountAction.enable
                                                  : AccountAction.disable,
                                            ),
                                          ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          account.healthy == true
                              ? 'Phiên đã xác nhận'
                              : account.healthy == false
                              ? 'Cần kiểm tra phiên'
                              : 'Chưa kiểm tra',
                          style: TextStyle(
                            color: account.healthy == true
                                ? StudioColors.success
                                : StudioColors.muted,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Hết hạn dự kiến: ${formatDate(account.expiresAt)}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: StudioColors.muted,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text('Proxy tài khoản'),
                          subtitle: Text(
                            account.proxy?.server ?? 'Kết nối trực tiếp',
                          ),
                          children: [
                            ProxyEditor(
                              account: account,
                              connection: connection,
                              enabled: !state.busy,
                              onSaved: () => context.read<AccountBloc>().add(
                                AccountsLoaded(connection),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton.icon(
                              onPressed: state.busy
                                  ? null
                                  : () => context.read<AccountBloc>().add(
                                      AccountActed(
                                        connection,
                                        account.id,
                                        AccountAction.test,
                                      ),
                                    ),
                              icon: const Icon(Icons.verified_user_outlined),
                              label: const Text('Kiểm tra phiên'),
                            ),
                            TextButton.icon(
                              onPressed: state.busy
                                  ? null
                                  : () => context.read<AccountBloc>().add(
                                      AccountActed(
                                        connection,
                                        account.id,
                                        AccountAction.quota,
                                      ),
                                    ),
                              icon: const Icon(Icons.data_usage),
                              label: const Text('Quota'),
                            ),
                            TextButton.icon(
                              onPressed: state.busy
                                  ? null
                                  : () => _keepalive(connection, account.id),
                              icon: const Icon(Icons.sync_outlined),
                              label: const Text('Duy trì phiên'),
                            ),
                            TextButton.icon(
                              onPressed: state.busy
                                  ? null
                                  : () =>
                                        _updateCookies(connection, account.id),
                              icon: const Icon(Icons.cookie_outlined),
                              label: const Text('Cập nhật cookie'),
                            ),
                            TextButton.icon(
                              onPressed: state.busy
                                  ? null
                                  : () => _remove(connection, account.id),
                              style: TextButton.styleFrom(
                                foregroundColor: Theme.of(context)
                                    .colorScheme
                                    .error,
                              ),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Xóa'),
                            ),
                          ],
                        ),
                        AccountQuotaSection(account: account),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ],
      );
    },
  );
}
