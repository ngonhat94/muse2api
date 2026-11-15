import '../domain/save_media.dart';
import '../errors/app_failure.dart';

class UnsupportedMediaSaver implements MediaSaver {
  @override
  Future<MediaSaveResult> save(
    MediaSaveSource source, {
    required bool Function() isCurrent,
    void Function(int)? onProgress,
  }) async {
    throw const AppFailure(
      'Lưu trực tiếp hiện hỗ trợ bản desktop. Trên web, hãy mở media bằng trình duyệt để lưu.',
    );
  }
}

MediaSaver createMediaSaver() => UnsupportedMediaSaver();
