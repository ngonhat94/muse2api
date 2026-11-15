import 'dart:typed_data';
import 'dart:ui' as ui;

import '../../../core/errors/app_failure.dart';
import '../../../core/domain/reference_image.dart';

class PromptImageLoader {
  const PromptImageLoader();
  static const maxBytes = 10 * 1024 * 1024;
  Future<ReferenceImage> load(String name, Uint8List bytes) async {
    if (bytes.length > maxBytes) {
      throw const AppFailure('Ảnh vượt 10 MiB. Chọn tệp nhỏ hơn.');
    }
    final image = ReferenceImage.fromBytes(name, bytes);
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(image.bytes);
      try {
        final descriptor = await ui.ImageDescriptor.encoded(buffer);
        try {
          final codec = await descriptor.instantiateCodec(
            targetWidth: 600,
            targetHeight: 600,
          );
          try {
            final frame = await codec.getNextFrame();
            frame.image.dispose();
          } finally {
            codec.dispose();
          }
        } finally {
          descriptor.dispose();
        }
      } finally {
        buffer.dispose();
      }
    } catch (_) {
      throw const AppFailure(
        'Không đọc được ảnh. Chọn PNG, JPEG, WebP hoặc GIF hợp lệ.',
      );
    }
    return image;
  }
}
