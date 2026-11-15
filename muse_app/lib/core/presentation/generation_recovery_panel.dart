import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'generation_recovery_cubit.dart';

class GenerationRecoveryPanel extends StatelessWidget {
  const GenerationRecoveryPanel({super.key});
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<GenerationRecoveryCubit, List<RecoveryEntry>>(
    builder: (context, entries) => ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 260),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Khôi phục tác vụ đã lưu',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Text(
              'Chỉ đọc trạng thái khi kết nối hoặc bấm Kiểm tra. Không gửi lại yêu cầu tạo. Đóng ứng dụng không hủy tác vụ trên server.',
            ),
            if (entries.isEmpty)
              const Text('Chưa có tác vụ đã lưu cho kết nối này.'),
            for (final entry in entries)
              ListTile(
                title: Text('${entry.kind} ${entry.id}'),
                subtitle: Text(switch (entry.status) {
                  'completed' => 'Đã hoàn tất · xem kết quả trong Thư viện',
                  'failed' => 'Server xác nhận tạo thất bại',
                  'unknown' => 'Không tìm thấy bản ghi (HTTP 404); có thể đã bị xóa. Chưa xác định kết quả tạo.',
                  'unreachable' => 'Chưa đọc được trạng thái. Mã tác vụ vẫn được giữ; kiểm tra kết nối/quyền rồi thử lại.',
                  'checking' => 'Đang đọc trạng thái…',
                  'storage_error' =>
                    'Không đọc được dữ liệu đã lưu; dữ liệu cũ chưa bị ghi đè.',
                  _ => 'Đang chờ hoặc đang tạo · bấm Kiểm tra để cập nhật',
                }),
                trailing: entry.id.isEmpty
                    ? null
                    : TextButton(
                        onPressed: entry.status == 'checking'
                            ? null
                            : () => context
                                  .read<GenerationRecoveryCubit>()
                                  .retry(entry.kind, entry.id),
                        child: const Text('Kiểm tra'),
                      ),
              ),
          ],
        ),
      ),
    ),
  );
}
