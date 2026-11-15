import '../domain/save_library.dart';
import '../domain/save_media.dart';
import '../errors/app_failure.dart';

class UnsupportedLibrarySaver implements LibrarySaver {
  @override
  Future<List<LibrarySaveEntry>> save(
    List<MediaSaveSource> sources, {
    required bool Function() isCurrent,
    void Function(String, int)? onProgress,
  }) async {
    throw const AppFailure(
      'Lưu vào thư mục chỉ hỗ trợ macOS, Windows và Linux.',
    );
  }
}

LibrarySaver createLibrarySaver() => UnsupportedLibrarySaver();
