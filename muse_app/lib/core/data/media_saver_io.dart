import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:http/http.dart' as http;

import '../domain/save_media.dart';
import '../errors/app_failure.dart';

class NativeMediaSaver implements MediaSaver {
  NativeMediaSaver({
    Future<String?> Function(String)? pickPath,
    http.Client Function()? clientFactory,
    this.idleTimeout = const Duration(seconds: 30),
    this.replaceExisting = true,
    this.beforePublish,
  }) : pickPath = pickPath ?? _pick,
       clientFactory = clientFactory ?? http.Client.new;
  final Future<String?> Function(String) pickPath;
  final http.Client Function() clientFactory;
  final Duration idleTimeout;
  final bool replaceExisting;
  final Future<void> Function()? beforePublish;
  bool _busy = false;
  static Future<String?> _pick(String name) async => (await getSaveLocation(
    suggestedName: name,
    confirmButtonText: 'Lưu',
  ))?.path;

  @override
  Future<MediaSaveResult> save(
    MediaSaveSource source, {
    required bool Function() isCurrent,
    void Function(int)? onProgress,
  }) async {
    if (_busy || !isCurrent()) return MediaSaveResult.cancelled;
    final name = source.suggestedName;
    _busy = true;
    http.Client? client;
    Directory? staging;
    RandomAccessFile? output;
    Timer? cancelWatch;
    Timer? deadline;
    var timedOut = false;
    try {
      final path = await pickPath(name);
      if (path == null || !isCurrent()) return MediaSaveResult.cancelled;
      final target = File(path);
      // A private sibling directory keeps staging on the destination filesystem.
      // The final rename replaces only after all bytes have been flushed.
      staging = await target.parent.createTemp('.muse-save-');
      final partial = File('${staging.path}/content');
      output = await partial.open(mode: FileMode.write);
      var count = 0;
      if (source.bytes != null) {
        if (!isCurrent()) return MediaSaveResult.cancelled;
        await output.writeFrom(source.bytes!);
        count = source.bytes!.length;
        onProgress?.call(count);
      } else {
        client = clientFactory();
        cancelWatch = Timer.periodic(const Duration(milliseconds: 100), (_) {
          if (!isCurrent()) client?.close();
        });
        deadline = Timer(const Duration(minutes: 20), () {
          timedOut = true;
          client?.close();
        });
        // The URL carries a short-lived resource capability, never the API key.
        // Do not follow redirects (including same-origin redirects).
        final response = await client
            .send(http.Request('GET', source.uri!)..followRedirects = false)
            .timeout(idleTimeout);
        if (response.statusCode != 200) {
          throw const AppFailure(
            'Không tải được media. Kiểm tra server và thử lại.',
          );
        }
        await for (final chunk in response.stream.timeout(idleTimeout)) {
          if (!isCurrent()) return MediaSaveResult.cancelled;
          if (timedOut) throw TimeoutException('save');
          await output.writeFrom(chunk);
          count += chunk.length;
          onProgress?.call(count);
        }
        if (count == 0 ||
            (response.contentLength != null &&
                response.contentLength != count)) {
          throw const AppFailure('Media tải chưa đầy đủ. Hãy thử lại.');
        }
      }
      await output.flush();
      await output.close();
      output = null;
      if (!isCurrent()) return MediaSaveResult.cancelled;
      if (timedOut) throw TimeoutException('save');
      if (!replaceExisting &&
          await FileSystemEntity.type(target.path, followLinks: false) !=
              FileSystemEntityType.notFound) {
        throw const AppFailure('Tệp đích đã tồn tại.');
      }
      await beforePublish?.call();
      if (replaceExisting) {
        await partial.rename(target.path);
      } else {
        // POSIX link(2) publishes the fully flushed inode atomically and fails
        // if *any* destination entry exists (including dangling symlinks).
        // Use the platform utility without a shell, PATH lookup or -f. Never
        // fall back to rename/copy: unsupported platforms/filesystems fail closed.
        final executable = Platform.isMacOS
            ? '/bin/link'
            : Platform.isLinux
            ? '/usr/bin/link'
            : null;
        if (executable == null) {
          throw const FileSystemException('No safe publish');
        }
        final result = await Process.run(executable, [
          partial.absolute.path,
          target.absolute.path,
        ]);
        if (result.exitCode != 0) {
          throw const FileSystemException('No safe publish');
        }
        // Only the private staging name is removed in finally, never target.
      }
      return MediaSaveResult.saved;
    } catch (_) {
      if (!isCurrent()) return MediaSaveResult.cancelled;
      throw const AppFailure(
        'Không lưu được media. Kiểm tra mạng, quyền ghi và dung lượng rồi thử lại.',
      );
    } finally {
      cancelWatch?.cancel();
      deadline?.cancel();
      client?.close();
      try {
        await output?.close();
      } catch (_) {
        /* best-effort cleanup */
      }
      try {
        await staging?.delete(recursive: true);
      } catch (_) {
        /* destination may be disconnected */
      }
      _busy = false;
    }
  }
}

MediaSaver createMediaSaver() => NativeMediaSaver();
