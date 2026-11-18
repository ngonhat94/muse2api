import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/extension_download.dart';
import '../../../connection/domain/entities/server_connection.dart';
import '../../../connection/presentation/bloc/connection_bloc.dart';
import '../bloc/extension_download_cubit.dart';

class ExtensionDownloadButton extends StatefulWidget {
  const ExtensionDownloadButton({
    super.key,
    required this.connection,
    required this.repository,
    required this.saver,
  });
  final ServerConnection connection;
  final ExtensionDownload repository;
  final ExtensionZipSaver saver;
  @override
  State<ExtensionDownloadButton> createState() =>
      _ExtensionDownloadButtonState();
}

class _ExtensionDownloadButtonState extends State<ExtensionDownloadButton> {
  late final cubit = ExtensionDownloadCubit(widget.repository);
  StreamSubscription<ServerConnectionState>? subscription;
  bool invalidated = false;
  bool get current =>
      mounted &&
      !invalidated &&
      identical(
        context.read<ConnectionBloc>().state.connection,
        widget.connection,
      );
  @override
  void initState() {
    super.initState();
    subscription = context.read<ConnectionBloc>().stream.listen((state) {
      if (!identical(state.connection, widget.connection)) {
        invalidated = true;
        cubit.reset();
      }
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    cubit.close();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<ExtensionDownloadCubit, ExtensionDownloadState>(
    bloc: cubit,
    builder: (context, state) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilledButton.icon(
          onPressed: state.busy || !widget.saver.supported || !current
              ? null
              : () async {
                  if (state.bytes != null) {
                    try {
                      if (current) widget.saver.save(state.bytes!);
                    } catch (_) {
                      if (current) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Trình duyệt không lưu được ZIP. Hãy thử lại.',
                            ),
                          ),
                        );
                      }
                    }
                  } else {
                    await cubit.load(widget.connection, () => current);
                  }
                },
          icon: const Icon(Icons.download_outlined),
          label: Text(
            state.busy
                ? 'Đang tải extension…'
                : state.bytes != null
                ? 'Lưu muse2api-extension.zip'
                : 'Tải extension ZIP',
          ),
        ),
        if (state.bytes != null)
          const Text('ZIP đã sẵn sàng. Bấm Lưu để tải bằng trình duyệt.'),
        if (!widget.saver.supported)
          const Text(
            'Mở Muse Studio trên Chrome/Edge máy tính để tải và cài extension.',
          ),
        if (state.message != null)
          Semantics(liveRegion: true, child: Text(state.message!)),
      ],
    ),
  );
}
