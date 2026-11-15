import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/connection_bloc.dart';
import '../../../desktop/domain/repositories/desktop_engine_installer.dart';

/// Native desktop entry point. Engine details stay out of the primary flow.
class LocalEnginePanel extends StatelessWidget {
  const LocalEnginePanel({super.key, required this.state});
  final ServerConnectionState state;
  @override
  Widget build(BuildContext context) {
    final local = state.localMode;
    final busy = state.status == ConnectionStatus.connecting;
    final connected = state.connection?.isLocal == true;
    final theme = Theme.of(context);
    final installation = state.installation;
    final canInstall = context.read<ConnectionBloc>().supportsInstallation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.computer_outlined, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Dùng trên máy này',
                style: theme.textTheme.titleLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Nhập cookie Muse của bạn để trò chuyện, tạo ảnh và video. Không cần địa chỉ server hay API key.',
        ),
        const SizedBox(height: 12),
        Text(
          'Cookie và kết quả được lưu trong dữ liệu ứng dụng trên máy này. Cần Internet để kết nối Muse.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 20),
        if (local && state.error != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              state.error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (installation != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(switch (installation) {
              DesktopInstallStage.preparing => 'Đang chuẩn bị bộ cài…',
              DesktopInstallStage.dependencies =>
                'Đang tải và cài thành phần cần thiết…',
              DesktopInstallStage.browser => 'Đang tải trình duyệt đi kèm…',
              DesktopInstallStage.packaging => 'Đang tạo engine cho máy này…',
              DesktopInstallStage.verifying => 'Đang kiểm tra bản cài…',
              DesktopInstallStage.cancelling => 'Đang hủy cài đặt…',
            }),
          ),
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: installation == DesktopInstallStage.cancelling
                ? null
                : () => context.read<ConnectionBloc>().add(
                    DesktopInstallationCancelled(),
                  ),
            icon: const Icon(Icons.close),
            label: const Text('Hủy cài đặt'),
          ),
        ] else ...[
          FilledButton.icon(
            onPressed: busy
                ? null
                : () => context.read<ConnectionBloc>().add(
                    connected
                        ? ConnectionDisconnected()
                        : LocalConnectionRequested(),
                  ),
            icon: busy && local
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    connected
                        ? Icons.stop_circle_outlined
                        : Icons.play_arrow_rounded,
                  ),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                busy && local
                    ? 'Đang chuẩn bị Muse…'
                    : connected
                    ? 'Dừng phiên trên máy này'
                    : local && state.error != null
                    ? 'Khởi động lại'
                    : 'Bắt đầu trên máy này',
              ),
            ),
          ),
          if (busy && local)
            TextButton(
              onPressed: () =>
                  context.read<ConnectionBloc>().add(ConnectionDisconnected()),
              child: const Text('Hủy khởi động'),
            ),
          if (canInstall && !connected) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: busy || state.connection != null
                  ? null
                  : () => context.read<ConnectionBloc>().add(
                      DesktopInstallationRequested(),
                    ),
              icon: const Icon(Icons.download_outlined),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('Cài đặt engine'),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.connection != null
                  ? 'Ngắt kết nối hiện tại để cài engine trên máy này.'
                  : 'Cài một lần, cần Internet và Python 3.11 trở lên. App sẽ tự kết nối khi hoàn tất.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
        if (connected)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Muse đang chạy trên máy này. Bạn có thể thêm cookie ở mục Tài khoản.',
            ),
          ),
      ],
    );
  }
}
