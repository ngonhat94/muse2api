import 'package:flutter/foundation.dart';

import '../../features/connection/domain/entities/server_connection.dart';
import '../domain/save_media.dart';
import 'media_save_button.dart';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

Future<void> openMedia(BuildContext context, Uri uri) async {
  try {
    if (!await launchUrl(uri, mode: LaunchMode.platformDefault) &&
        context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Không mở được media.')));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Không mở được media.')));
    }
  }
}

void showMediaPreview(
  BuildContext context,
  Uri uri,
  bool video, {
  ServerConnection? connection,
}) => showDialog<void>(
  context: context,
  builder: (_) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
              MediaPreview(uri: uri, video: video, connection: connection),
            ],
          ),
        ),
      ),
    ),
  ),
);

class MediaPreview extends StatefulWidget {
  const MediaPreview({
    super.key,
    required this.uri,
    required this.video,
    this.connection,
  });
  final ServerConnection? connection;
  final Uri uri;
  final bool video;
  @override
  State<MediaPreview> createState() => _MediaPreviewState();
}

class _MediaPreviewState extends State<MediaPreview> {
  VideoPlayerController? _player;
  bool _failed = false;
  bool get _supported =>
      kIsWeb ||
      ![
        TargetPlatform.windows,
        TargetPlatform.linux,
      ].contains(defaultTargetPlatform);
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(MediaPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri != widget.uri || oldWidget.video != widget.video) {
      _player?.dispose();
      _player = null;
      _failed = false;
      _load();
    }
  }

  Future<void> _load() async {
    if (!widget.video || !_supported) return;
    final player = VideoPlayerController.networkUrl(widget.uri);
    _player = player;
    try {
      await player.initialize();
      if (mounted && _player == player) setState(() {});
    } catch (_) {
      if (mounted && _player == player) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (!widget.video)
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(
            widget.uri.toString(),
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) => progress == null
                ? child
                : const Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
            errorBuilder: (_, _, _) => const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Không tải được ảnh. Thử mở bằng trình duyệt.'),
            ),
          ),
        )
      else if (!_supported || _failed)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text('Mở video bằng trình duyệt để xem trên thiết bị này.'),
        )
      else if (_player?.value.isInitialized != true)
        const Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        )
      else ...[
        AspectRatio(
          aspectRatio: _player!.value.aspectRatio,
          child: VideoPlayer(_player!),
        ),
        VideoProgressIndicator(_player!, allowScrubbing: true),
        IconButton(
          tooltip: 'Phát / tạm dừng',
          icon: Icon(_player!.value.isPlaying ? Icons.pause : Icons.play_arrow),
          onPressed: () {
            _player!.value.isPlaying ? _player!.pause() : _player!.play();
            setState(() {});
          },
        ),
      ],
      if (widget.connection != null)
        MediaSaveButton(
          source: MediaSaveSource.remote(widget.connection!, widget.uri),
        ),
      TextButton.icon(
        onPressed: () => openMedia(context, widget.uri),
        icon: const Icon(Icons.open_in_new),
        label: const Text('Mở bằng trình duyệt'),
      ),
    ],
  );
}
