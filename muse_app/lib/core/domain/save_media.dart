import 'dart:typed_data';

import '../errors/app_failure.dart';
import '../network/media_uri.dart';

import '../../features/media/domain/entities/media_name.dart';
import '../../features/connection/domain/entities/server_connection.dart';

enum MediaSaveResult { saved, cancelled }

class MediaSaveSource {
  const MediaSaveSource.remote(this.connection, this.uri) : bytes = null;
  const MediaSaveSource.image(this.bytes) : connection = null, uri = null;
  final ServerConnection? connection;
  final Uri? uri;
  final Uint8List? bytes;

  String get suggestedName {
    final address = uri;
    if (address == null) {
      if (bytes == null || bytes!.isEmpty) {
        throw const AppFailure('Không có dữ liệu ảnh để lưu.');
      }
      final data = bytes!;
      final extension =
          data.length >= 3 && data[0] == 255 && data[1] == 216 && data[2] == 255
          ? 'jpg'
          : data.length >= 12 &&
                String.fromCharCodes(data.take(4)) == 'RIFF' &&
                String.fromCharCodes(data.skip(8).take(4)) == 'WEBP'
          ? 'webp'
          : data.length >= 6 && String.fromCharCodes(data.take(3)) == 'GIF'
          ? 'gif'
          : data.length >= 8 &&
                data[0] == 137 &&
                String.fromCharCodes(data.skip(1).take(3)) == 'PNG'
          ? 'png'
          : null;
      if (extension == null) {
        throw const AppFailure('Định dạng ảnh chưa hỗ trợ lưu.');
      }
      return 'muse-image.$extension';
    }
    final server = connection;
    final name = address.pathSegments.isEmpty ? '' : address.pathSegments.last;
    if (server == null ||
        !['http', 'https'].contains(address.scheme) ||
        address.host.isEmpty ||
        address.userInfo.isNotEmpty ||
        address.hasFragment ||
        (server.apiKey.isNotEmpty && name.contains(server.apiKey)) ||
        !isDeletableMediaName(name) ||
        name.length > 180 ||
        !RegExp(
          r'^[a-zA-Z0-9_][a-zA-Z0-9_. -]*\.(png|jpg|jpeg|webp|gif|mp4|webm|mov)$',
          caseSensitive: false,
        ).hasMatch(name) ||
        address != protectedMediaUri(server, address.toString(), name)) {
      throw const AppFailure('Địa chỉ hoặc tên media không hợp lệ.');
    }
    return name;
  }
}

abstract interface class MediaSaver {
  Future<MediaSaveResult> save(
    MediaSaveSource source, {
    required bool Function() isCurrent,
    void Function(int)? onProgress,
  });
}

class SaveMedia {
  SaveMedia(this.saver);
  final MediaSaver saver;
  Future<MediaSaveResult> save(
    MediaSaveSource source, {
    required bool Function() isCurrent,
    void Function(int)? onProgress,
  }) => saver.save(source, isCurrent: isCurrent, onProgress: onProgress);
}
