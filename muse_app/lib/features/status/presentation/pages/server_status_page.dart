import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/studio_theme.dart';
import '../bloc/server_status_bloc.dart';

class ServerStatusPage extends StatelessWidget {
  const ServerStatusPage({super.key});

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<ServerStatusBloc, ServerStatusState>(
    builder: (context, state) {
      final snapshot = state.snapshot;
      final updatedAt = state.updatedAt?.toLocal();
      String count(int? value) => value?.toString() ?? 'Chưa rõ';
      Widget heading(String text) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 12),
        child: Semantics(
          header: true,
          child: Text(text, style: Theme.of(context).textTheme.titleLarge),
        ),
      );
      Widget field(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: MergeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: StudioColors.muted)),
              const SizedBox(height: 4),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      );
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Trạng thái server',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Ảnh chụp tại lần tải gần nhất, không phải giám sát trực tiếp. Chỉ đọc; không thay đổi server.',
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: state.connection == null || state.busy
                      ? null
                      : context.read<ServerStatusBloc>().refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tải trạng thái server'),
                ),
              ),
              if (state.busy) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(
                  semanticsLabel: 'Đang tải trạng thái server',
                ),
              ],
              const SizedBox(height: 16),
              if (state.connection == null)
                const Text('Kết nối server để xem trạng thái.')
              else if (snapshot == null && state.error == null && !state.busy)
                const Text('Chưa tải trạng thái.'),
              if (state.error != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    state.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (snapshot != null) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(
                    '${state.stale ? 'Dữ liệu cũ · Lần tải thành công' : 'Lần tải thành công'}: $updatedAt',
                    style: const TextStyle(color: StudioColors.muted),
                  ),
                ),
                heading('Trình duyệt và lưu trữ'),
                field(
                  'Tiến trình trình duyệt',
                  switch (snapshot.browserRunning) {
                    true => 'Đang chạy tại thời điểm tải',
                    false => 'Không chạy tại thời điểm tải',
                    null => 'Chưa rõ',
                  },
                ),
                const Text(
                  'Tiến trình đang chạy không xác nhận khả năng tạo nội dung.',
                  style: TextStyle(color: StudioColors.muted),
                ),
                field('Mục trong thư mục media', count(snapshot.mediaCount)),
                heading('Tổng hợp tài khoản'),
                const Text(
                  'Theo thống kê server. Trạng thái kiểm tra đã lưu không bảo đảm phiên hiện tại còn hoạt động.',
                  style: TextStyle(color: StudioColors.muted),
                ),
                field('Tổng tài khoản', count(snapshot.totalAccounts)),
                field('Đang bật', count(snapshot.enabledAccounts)),
                field('Đã tắt', count(snapshot.disabledAccounts)),
                field(
                  'Đang bật · kiểm tra đã lưu thành công',
                  count(snapshot.healthyAccounts),
                ),
                field(
                  'Đang bật · kiểm tra đã lưu lỗi',
                  count(snapshot.errorAccounts),
                ),
                field(
                  'Đang bật · hết hạn trong dưới 3 ngày (gồm đã hết hạn)',
                  count(snapshot.expiringAccounts),
                ),
                field('Đang bật · đã hết hạn', count(snapshot.expiredAccounts)),
                const SizedBox(height: 16),
                const Text(
                  'Chưa rõ: server không cung cấp giá trị hợp lệ. Không hiển thị cấu hình, cookie hoặc chi tiết tài khoản.',
                  style: TextStyle(color: StudioColors.muted),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}
