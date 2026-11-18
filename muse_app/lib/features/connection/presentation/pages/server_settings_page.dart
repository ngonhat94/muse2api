import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/connection_permissions.dart';
import '../bloc/connection_bloc.dart';
import 'client_config_editor.dart';

/// Shared server configuration, independent of this device's login session.
class ServerSettingsPage extends StatelessWidget {
  const ServerSettingsPage({super.key});

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<ConnectionBloc, ServerConnectionState>(
        builder: (context, state) {
          final connection = state.connection;
          if (!canConfigureServer(connection)) return const SizedBox.shrink();
          final bloc = context.read<ConnectionBloc>();
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Cài đặt server',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Quản lý địa chỉ server dùng chung. Thay đổi này không đổi phiên đăng nhập hiện tại.',
                    ),
                    const SizedBox(height: 24),
                    if (bloc.clientConfig case final repository?)
                      ClientConfigEditor(
                        key: ObjectKey(connection),
                        connection: connection!,
                        repository: repository,
                        address: bloc.sharedAddress,
                      )
                    else
                      const Text('Cấu hình server chưa khả dụng.'),
                  ],
                ),
              ),
            ),
          );
        },
      );
}
