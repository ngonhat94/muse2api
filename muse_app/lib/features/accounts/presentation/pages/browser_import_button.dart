import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/repositories/browser_account_import.dart';
import '../../../connection/domain/entities/server_connection.dart';
import '../../../connection/presentation/bloc/connection_bloc.dart';
import '../bloc/account_bloc.dart';
import '../bloc/browser_import_cubit.dart';

class BrowserImportButton extends StatefulWidget {
  const BrowserImportButton({
    super.key,
    required this.bridge,
    required this.connection,
    this.disabled = false,
  });
  final BrowserAccountImport bridge;
  final ServerConnection connection;
  final bool disabled;
  @override
  State<BrowserImportButton> createState() => _BrowserImportButtonState();
}

class _BrowserImportButtonState extends State<BrowserImportButton> {
  late final BrowserImportCubit cubit;
  StreamSubscription<ServerConnectionState>? subscription;
  bool invalidated = false;
  @override
  void initState() {
    super.initState();
    cubit = BrowserImportCubit(widget.bridge);
    subscription = context.read<ConnectionBloc>().stream.listen((state) {
      if (!identical(state.connection, widget.connection)) {
        invalidated = true;
        cubit.reset();
      }
    });
  }

  bool get current =>
      mounted &&
      !invalidated &&
      identical(
        context.read<ConnectionBloc>().state.connection,
        widget.connection,
      );
  @override
  void dispose() {
    subscription?.cancel();
    cubit.close();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<BrowserImportCubit, BrowserImportState>(
    bloc: cubit,
    listener: (context, state) {
      if (state.imported && current)
        context.read<AccountBloc>().add(AccountsLoaded(widget.connection));
    },
    builder: (context, state) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: state.busy || widget.disabled
              ? null
              : () => cubit.run(widget.connection, () => current),
          icon: const Icon(Icons.extension_outlined),
          label: Text(
            state.busy
                ? 'Đang nhập từ trình duyệt…'
                : 'Nhập tài khoản từ trình duyệt',
          ),
        ),
        if (state.busy)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          ),
        if (state.message != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Semantics(
              liveRegion: true,
              child: Text(
                state.message!,
                softWrap: true,
                maxLines: null,
                overflow: TextOverflow.visible,
              ),
            ),
          ),
        if (state.message != null &&
            widget.bridge.capability ==
                BrowserImportCapability.unsupportedOrigin)
          TextButton.icon(
            onPressed: () async {
              try {
                await launchUrl(
                  Uri.parse(approvedBrowserImportOrigin),
                  webOnlyWindowName: '_blank',
                );
              } catch (_) {
                // The selectable URL remains available if opening is blocked.
              }
            },
            icon: const Icon(Icons.open_in_new),
            label: const Text(
              'Mở Muse Studio được hỗ trợ (tab mới)',
              softWrap: true,
              maxLines: null,
              overflow: TextOverflow.visible,
            ),
          ),
        if (state.message != null && !widget.bridge.supported)
          const SelectableText(approvedBrowserImportOriginsLabel),
        if (state.message != null)
          const Text(
            'Xem tab Get Cookies để tải/cài extension hoặc chọn Nhập tài khoản để nhập thủ công.',
          ),
        const Text(
          'Chrome/Edge desktop · Extension 1.1.1 · Cần xác nhận từng lần. Cookie không đi qua trang web.',
        ),
        const SizedBox(height: 12),
      ],
    ),
  );
}
