import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/connection/presentation/bloc/connection_bloc.dart';
import '../domain/save_media.dart';
import '../errors/app_failure.dart';

class MediaSaveButton extends StatefulWidget {
  const MediaSaveButton({
    super.key,
    required this.source,
    this.saveMedia,
    this.isCurrent,
  });
  final MediaSaveSource source;
  final SaveMedia? saveMedia;
  final bool Function()? isCurrent;
  @override
  State<MediaSaveButton> createState() => _MediaSaveButtonState();
}

class _MediaSaveButtonState extends State<MediaSaveButton> {
  bool _busy = false;
  bool _cancelled = false;
  int _bytes = 0;
  int _version = 0;
  @override
  void didUpdateWidget(MediaSaveButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source.uri != widget.source.uri ||
        !identical(oldWidget.source.bytes, widget.source.bytes) ||
        oldWidget.source.connection != widget.source.connection) {
      _version++;
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.of(context);
    final source = widget.source;
    final generation = _version;
    final connectionBloc = widget.isCurrent == null
        ? context.read<ConnectionBloc>()
        : null;
    final connection = connectionBloc?.state.connection;
    bool current() =>
        mounted &&
        !_cancelled &&
        _version == generation &&
        (widget.isCurrent?.call() ??
            identical(connectionBloc?.state.connection, connection)) &&
        (source.connection == null ||
            (connection?.baseUrl == source.connection!.baseUrl &&
                connection?.apiKey == source.connection!.apiKey) ||
            widget.isCurrent != null);
    setState(() {
      _busy = true;
      _cancelled = false;
      _bytes = 0;
    });
    try {
      final result = await (widget.saveMedia ?? context.read<SaveMedia>()).save(
        source,
        isCurrent: current,
        onProgress: (bytes) {
          if (current()) setState(() => _bytes = bytes);
        },
      );
      if (current() && result == MediaSaveResult.saved) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Đã lưu media về máy.')),
        );
      }
    } catch (error) {
      if (current()) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              error is AppFailure
                  ? error.message
                  : 'Không lưu được media. Hãy thử lại.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _version++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final supported =
        widget.saveMedia != null ||
        (!kIsWeb &&
            [
              TargetPlatform.macOS,
              TargetPlatform.windows,
              TargetPlatform.linux,
            ].contains(defaultTargetPlatform));
    if (!supported) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Text(
          'Lưu trực tiếp hỗ trợ bản desktop. Dùng trình duyệt để lưu trên nền tảng này.',
        ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TextButton.icon(
          onPressed: _busy ? null : _save,
          icon: Icon(_busy ? Icons.hourglass_top : Icons.download_outlined),
          label: Text(
            _busy ? 'Đang lưu · ${(_bytes / 1024).floor()} KB' : 'Lưu về máy',
          ),
        ),
        if (_busy)
          TextButton(
            onPressed: () => setState(() => _cancelled = true),
            child: const Text('Hủy lưu'),
          ),
      ],
    );
  }
}
