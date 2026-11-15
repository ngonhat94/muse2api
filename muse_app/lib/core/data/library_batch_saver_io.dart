import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:http/http.dart' as http;

import '../errors/app_failure.dart';
import '../domain/save_media.dart';
import '../domain/save_library.dart';
import 'media_saver_io.dart';

class NativeLibrarySaver implements LibrarySaver {
  NativeLibrarySaver({
    Future<String?> Function()? pickDirectory,
    http.Client Function()? clientFactory,
    bool Function()? isDesktop,
  }) : pickDirectory =
           pickDirectory ??
           (() => getDirectoryPath(confirmButtonText: 'Lưu vào thư mục')),
       clientFactory = clientFactory ?? http.Client.new,
       isDesktop =
           isDesktop ??
           (() => Platform.isMacOS || Platform.isWindows || Platform.isLinux);
  final bool Function() isDesktop;
  final Future<String?> Function() pickDirectory;
  final http.Client Function() clientFactory;
  bool _busy = false;

  @override
  Future<List<LibrarySaveEntry>> save(
    List<MediaSaveSource> sources, {
    required bool Function() isCurrent,
    void Function(String, int)? onProgress,
  }) async {
    if (!isDesktop()) {
      throw const AppFailure(
        'Lưu vào thư mục chỉ hỗ trợ macOS, Windows và Linux.',
      );
    }
    final names = sources.map((source) => source.suggestedName).toList();
    if (_busy || !isCurrent()) return [];
    _busy = true;
    final results = <LibrarySaveEntry>[];
    try {
      final folder = await pickDirectory();
      if (folder == null) return [];
      final seen = <String>{};
      for (var i = 0; i < sources.length; i++) {
        final name = names[i];
        if (!isCurrent()) {
          results.add(LibrarySaveEntry(name, LibrarySaveStatus.cancelled));
          continue;
        }
        final target = File('$folder${Platform.pathSeparator}$name');
        if (!seen.add(name.toLowerCase()) ||
            await FileSystemEntity.type(target.path, followLinks: false) !=
                FileSystemEntityType.notFound) {
          results.add(LibrarySaveEntry(name, LibrarySaveStatus.skipped));
          continue;
        }
        try {
          final result =
              await NativeMediaSaver(
                pickPath: (_) async => target.path,
                clientFactory: clientFactory,
                replaceExisting: false,
              ).save(
                sources[i],
                isCurrent: isCurrent,
                onProgress: (bytes) => onProgress?.call(name, bytes),
              );
          results.add(
            LibrarySaveEntry(
              name,
              result == MediaSaveResult.saved
                  ? LibrarySaveStatus.saved
                  : LibrarySaveStatus.cancelled,
            ),
          );
        } catch (_) {
          results.add(LibrarySaveEntry(name, LibrarySaveStatus.failed));
        }
      }
      return results;
    } finally {
      _busy = false;
    }
  }
}

LibrarySaver createLibrarySaver() => NativeLibrarySaver();
