import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../connection/domain/entities/server_connection.dart';
import '../../domain/repositories/storage_repository.dart';
import '../bloc/storage_usage_cubit.dart';

class StorageUsagePanel extends StatefulWidget {
  const StorageUsagePanel({
    super.key,
    required this.connection,
    required this.repository,
  });
  final ServerConnection? connection;
  final StorageRepository? repository;
  @override
  State<StorageUsagePanel> createState() => _StorageUsagePanelState();
}

class _StorageUsagePanelState extends State<StorageUsagePanel> {
  StorageUsageCubit? _cubit;
  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _bind() {
    if (widget.repository != null) {
      _cubit ??= StorageUsageCubit(widget.repository!);
      _cubit!.bind(widget.connection);
    }
  }

  @override
  void didUpdateWidget(StorageUsagePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository)) {
      _cubit?.close();
      _cubit = null;
    }
    _bind();
  }

  @override
  void dispose() {
    _cubit?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connection = widget.connection;
    final allowed =
        connection != null &&
        (connection.principal?.can('media') ?? connection.isLocal);
    if (!allowed || _cubit == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Lưu trữ chưa khả dụng. Kết nối tài khoản có quyền media để xem.',
        ),
      );
    }
    return BlocBuilder<StorageUsageCubit, StorageUsageState>(
      key: ObjectKey(connection),
      bloc: _cubit,
      builder: (context, state) {
        final usage = state.usage;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lưu trữ của bạn trên server',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Text(
                'Độc lập với số dư Muse và thư mục tải xuống trên máy. Chỉ cập nhật khi bạn làm mới.',
              ),
              Semantics(
                liveRegion: true,
                child: Text(
                  state.loading
                      ? 'Đang tải lưu trữ…'
                      : state.error ??
                            (usage == null
                                ? 'Chưa tải lưu trữ; không có nghĩa là đã dùng 0.'
                                : '${usage.bytes} / ${usage.limitBytes} bytes · ${usage.files} / ${usage.limitFiles} tệp'),
                ),
              ),
              if (usage != null) ...[
                Text(
                  'Sau ${usage.retentionDays} ngày, media có thể được quản trị viên xét dọn. Không tự động xóa.',
                ),
                if (usage.bytes >= usage.limitBytes ||
                    usage.files >= usage.limitFiles)
                  const Text(
                    'Đã đầy hạn mức. Xóa media của bạn hoặc liên hệ quản trị viên; không tự động gửi lại tác vụ.',
                  ),
              ],
              OutlinedButton.icon(
                onPressed: state.loading ? null : _cubit!.refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Làm mới lưu trữ'),
              ),
            ],
          ),
        );
      },
    );
  }
}
