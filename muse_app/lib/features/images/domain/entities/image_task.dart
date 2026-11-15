import 'dart:typed_data';

enum ImageTaskStatus { queued, processing, completed, failed }

class ImageTask {
  const ImageTask({
    required this.id,
    required this.status,
    this.progress = 0,
    this.bytes,
  });
  final String id;
  final ImageTaskStatus status;
  final double progress;
  final Uint8List? bytes;
  bool get terminal =>
      status == ImageTaskStatus.completed || status == ImageTaskStatus.failed;
}
