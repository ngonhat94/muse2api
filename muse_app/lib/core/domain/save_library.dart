import 'save_media.dart';

enum LibrarySaveStatus { saved, failed, skipped, cancelled }

class LibrarySaveEntry {
  const LibrarySaveEntry(this.name, this.status);
  final String name;
  final LibrarySaveStatus status;
}

abstract interface class LibrarySaver {
  Future<List<LibrarySaveEntry>> save(
    List<MediaSaveSource> sources, {
    required bool Function() isCurrent,
    void Function(String name, int bytes)? onProgress,
  });
}
