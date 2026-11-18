import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/server_connection.dart';
import '../../domain/repositories/client_config_repository.dart';
import '../bloc/client_config_cubit.dart';

class ClientConfigEditor extends StatefulWidget {
  const ClientConfigEditor({
    super.key,
    required this.connection,
    required this.repository,
    required this.address,
  });
  final ServerConnection connection;
  final ClientConfigRepository repository;
  final String address;
  @override
  State<ClientConfigEditor> createState() => _ClientConfigEditorState();
}

class _ClientConfigEditorState extends State<ClientConfigEditor> {
  late final controller = TextEditingController(text: widget.address);
  late final cubit = ClientConfigCubit(widget.repository, widget.connection);
  @override
  void dispose() {
    controller.dispose();
    cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<ClientConfigCubit, ClientConfigState>(
        bloc: cubit,
        builder: (context, state) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            const Text(
              'Cấu hình server dùng chung',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              enabled: !state.busy,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Địa chỉ server dùng chung',
                helperText:
                    'HTTPS, không kèm key hoặc /v1. Áp dụng cho mọi thiết bị.',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: state.busy ? null : () => cubit.save(controller.text),
              child: Text(state.busy ? 'Đang lưu…' : 'Lưu cấu hình chung'),
            ),
            if (state.message != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(state.message!),
              ),
          ],
        ),
      );
}
