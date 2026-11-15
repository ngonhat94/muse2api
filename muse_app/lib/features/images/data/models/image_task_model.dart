import 'dart:convert';

import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/image_task.dart';

class ImageTaskModel {
  static ImageTask fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! String || id.isEmpty) {
      throw const AppFailure('Server không trả về mã tác vụ ảnh.');
    }
    final status = switch (json['status']) {
      'queued' => ImageTaskStatus.queued,
      'processing' => ImageTaskStatus.processing,
      'completed' => ImageTaskStatus.completed,
      'failed' => ImageTaskStatus.failed,
      _ => throw const AppFailure('Trạng thái tác vụ ảnh không hợp lệ.'),
    };
    final progress = json['progress'];
    if (status != ImageTaskStatus.completed) {
      return ImageTask(
        id: id,
        status: status,
        progress: progress is num ? progress.toDouble().clamp(0, 100) : 0,
      );
    }
    final data = json['data'];
    final encoded = data is List && data.isNotEmpty && data.first is Map
        ? data.first['b64_json']
        : null;
    if (encoded is! String || encoded.isEmpty) {
      throw const AppFailure(
        'Tác vụ đã xong nhưng server chưa trả về dữ liệu ảnh. Thử kiểm tra lại tác vụ.',
      );
    }
    try {
      final bytes = base64Decode(encoded);
      if (bytes.isEmpty) throw const FormatException();
      return ImageTask(id: id, status: status, progress: 100, bytes: bytes);
    } on FormatException {
      throw const AppFailure('Dữ liệu ảnh server trả về không hợp lệ.');
    }
  }
}
