import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/list_header.dart';
import '../../../connection/domain/entities/server_connection.dart';
import '../../domain/repositories/keepalive_status_repository.dart';
import '../bloc/keepalive_status_bloc.dart';
import '../bloc/account_bloc.dart';

class KeepaliveStatusSection extends StatelessWidget {
  const KeepaliveStatusSection({
    super.key,
    required this.repository,
    required this.connection,
    this.accounts,
  });
  final KeepaliveStatusRepository repository;
  final ServerConnection connection;
  final AccountBloc? accounts;

  @override
  Widget build(BuildContext context) => BlocProvider(
    key: ObjectKey(connection),
    create: (_) => KeepaliveStatusBloc(repository, connection),
    child: Builder(
      builder: (context) {
        final child = BlocBuilder<KeepaliveStatusBloc, KeepaliveStatusState>(
          builder: (context, state) {
            final status = state.status;
            final summary = status?.lastResult;
            String count(int? n) => n?.toString() ?? 'chưa rõ';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trạng thái duy trì phiên',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Chỉ đọc trạng thái server, không chạy duy trì phiên.',
                  ),
                  TextButton.icon(
                    onPressed: state.busy
                        ? null
                        : () => context.read<KeepaliveStatusBloc>().refresh(),
                    icon: const Icon(Icons.refresh),
                    label: Text(
                      state.busy ? 'Đang tải trạng thái…' : 'Tải trạng thái',
                    ),
                  ),
                  if (state.busy)
                    const LinearProgressIndicator(
                      semanticsLabel: 'Đang tải trạng thái duy trì phiên',
                    ),
                  if (state.error != null)
                    Text(
                      state.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  if (status == null)
                    const Text('Chưa tải trạng thái.')
                  else ...[
                    if (state.error != null || state.busy)
                      const Text('Dữ liệu cũ · chưa cập nhật.'),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        status.running == true
                            ? 'Đang chạy trên server'
                            : status.running == false
                            ? 'Không chạy tại thời điểm tải'
                            : 'Chưa rõ trạng thái chạy',
                      ),
                    ),
                    Text('Lần chạy gần nhất: ${formatDate(status.lastRun)}'),
                    Text('Lần tới (ước tính): ${formatDate(status.nextRun)}'),
                    const Text(
                      'Thời gian do server cung cấp, không bảo đảm lịch chạy.',
                    ),
                    const SizedBox(height: 8),
                    if (summary == null)
                      const Text('Chưa có kết quả đợt gần nhất.')
                    else ...[
                      Text(
                        'Kết quả đợt gần nhất · ${formatDate(summary.checkedAt)}',
                      ),
                      Text(
                        '${count(summary.attempts)} lượt thử · ${count(summary.skipped)} bỏ qua',
                      ),
                      Text(
                        '${summary.successes} thành công · ${summary.failures} thất bại (trong đó ${summary.busy} bận) · ${count(summary.unknown)} chưa xác định',
                      ),
                      const Text(
                        'Lượt thử không đồng nghĩa thành công. Kết quả này có thể thuộc đợt trước khi server đang chạy.',
                      ),
                    ],
                  ],
                ],
              ),
            );
          },
        );
        if (accounts == null) return child;
        return BlocListener<AccountBloc, AccountState>(
          bloc: accounts,
          listenWhen: (_, current) => current.batchCompleted,
          listener: (context, _) =>
              context.read<KeepaliveStatusBloc>().refresh(),
          child: child,
        );
      },
    ),
  );
}
