import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../errors/app_failure.dart';

class ReferenceImage {
  ReferenceImage._(this.name, this.mime, Uint8List bytes)
    : bytes = Uint8List.fromList(bytes).asUnmodifiableView(),
      fingerprint = sha256.convert(bytes).toString();
  final String name;
  final String mime;
  final Uint8List bytes;
  final String fingerprint;
  static const maxFiles = 10;
  static const maxFileBytes = 40 * 1024 * 1024;
  static const maxTotalBytes = 100 * 1024 * 1024;
  factory ReferenceImage.fromBytes(String name, Uint8List bytes) {
    if (bytes.isEmpty) throw AppFailure('$name: tệp trống. Chọn ảnh khác.');
    if (bytes.length > maxFileBytes) {
      throw AppFailure('$name: ảnh vượt 40 MiB. Chọn tệp nhỏ hơn.');
    }
    bool starts(List<int> header) =>
        bytes.length >= header.length &&
        List.generate(
          header.length,
          (i) => bytes[i] == header[i],
        ).every((v) => v);
    final mime = starts([137, 80, 78, 71, 13, 10, 26, 10])
        ? 'image/png'
        : starts([255, 216, 255])
        ? 'image/jpeg'
        : starts([71, 73, 70, 56, 55, 97]) || starts([71, 73, 70, 56, 57, 97])
        ? 'image/gif'
        : bytes.length >= 12 &&
              starts([82, 73, 70, 70]) &&
              bytes[8] == 87 &&
              bytes[9] == 69 &&
              bytes[10] == 66 &&
              bytes[11] == 80
        ? 'image/webp'
        : null;
    if (mime == null) {
      throw AppFailure(
        '$name: định dạng không được hỗ trợ. Dùng PNG, JPEG, WebP hoặc GIF.',
      );
    }
    return ReferenceImage._(name, mime, bytes);
  }
  static void validate(List<ReferenceImage> images) {
    if (images.length > maxFiles) {
      throw const AppFailure(
        'Tối đa 10 ảnh tham chiếu. Xóa bớt ảnh trước khi thêm.',
      );
    }
    if (images.fold<int>(0, (n, image) => n + image.bytes.length) >
        maxTotalBytes) {
      throw const AppFailure(
        'Tổng ảnh vượt 100 MiB. Xóa bớt ảnh hoặc chọn tệp nhỏ hơn.',
      );
    }
  }
}
