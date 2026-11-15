import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muse_app/core/data/library_batch_saver_io.dart';
import 'package:muse_app/core/domain/save_media.dart';
import 'package:muse_app/core/domain/save_library.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';

void main() {
  test('mobile adapter refuses before folder picker', () async {
    var picked = false;
    final saver = NativeLibrarySaver(
      isDesktop: () => false,
      pickDirectory: () async {
        picked = true;
        return null;
      },
    );
    await expectLater(
      saver.save([], isCurrent: () => true),
      throwsA(isA<Exception>()),
    );
    expect(picked, false);
  });

  test('destination appearing during transfer is never replaced', () async {
    final dir = await Directory.systemTemp.createTemp('library-race-');
    addTearDown(() => dir.delete(recursive: true));
    final target = File('${dir.path}/race.mp4');
    const connection = ServerConnection(
      baseUrl: 'https://fixture.example',
      apiKey: 'fixture-key',
    );
    final saver = NativeLibrarySaver(
      pickDirectory: () async => dir.path,
      clientFactory: () => MockClient((_) async {
        await target.writeAsBytes([9]);
        return http.Response.bytes([1, 2, 3], 200);
      }),
    );
    final results = await saver.save([
      MediaSaveSource.remote(
        connection,
        connection.endpoint('/v1/media/race.mp4?cap=synthetic.capability'),
      ),
    ], isCurrent: () => true);
    expect(results.single.status, LibrarySaveStatus.failed);
    expect(await target.readAsBytes(), [9]);
    expect(dir.listSync().length, 1);
  });
  test('cancelled picker and duplicate call do not transfer', () async {
    final picker = Completer<String?>();
    var picks = 0;
    final saver = NativeLibrarySaver(
      pickDirectory: () {
        picks++;
        return picker.future;
      },
      clientFactory: () => throw StateError('no network'),
    );
    final first = saver.save([], isCurrent: () => true);
    expect(await saver.save([], isCurrent: () => true), isEmpty);
    picker.complete(null);
    expect(await first, isEmpty);
    expect(picks, 1);
  });
  test('unsafe path is rejected before picker', () async {
    var picked = false;
    const connection = ServerConnection(
      baseUrl: 'https://fixture.example',
      apiKey: 'key',
    );
    final saver = NativeLibrarySaver(
      pickDirectory: () async {
        picked = true;
        return null;
      },
    );
    await expectLater(
      saver.save([
        MediaSaveSource.remote(
          connection,
          Uri.parse('https://fixture.example/v1/media/a%252f.mp4'),
        ),
      ], isCurrent: () => true),
      throwsA(isA<Exception>()),
    );
    expect(picked, false);
  });
  test('real local batch preserves successes when cancellation interrupts next stream', () async {
    final dir = await Directory.systemTemp.createTemp('library-cancel-');
    addTearDown(() => dir.delete(recursive: true));
    final httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => httpServer.close(force: true));
    final connection = ServerConnection(
      baseUrl: 'http://127.0.0.1:${httpServer.port}/prefix',
      apiKey: 'fixture-key',
    );
    final requested = <String>[];
    httpServer.listen((request) async {
      requested.add(request.uri.pathSegments.last);
      expect(request.headers.value('authorization'), isNull);
      expect(request.headers.value('cookie'), isNull);
      request.response.contentLength = 4;
      request.response.add([1, 2, 3, 4]);
      await request.response.close();
    });
    var current = true;
    final saver = NativeLibrarySaver(pickDirectory: () async => dir.path);
    final results = await saver.save(
      [
        for (final name in ['a.mp4', 'b.mp4', 'c.mp4'])
          MediaSaveSource.remote(
            connection,
            connection.endpoint('/v1/media/$name?cap=synthetic.capability'),
          ),
      ],
      isCurrent: () => current,
      onProgress: (name, bytes) {
        if (name == 'b.mp4') current = false;
      },
    );
    expect(results.map((e) => e.status), [
      LibrarySaveStatus.saved,
      LibrarySaveStatus.cancelled,
      LibrarySaveStatus.cancelled,
    ]);
    expect(requested, ['a.mp4', 'b.mp4']);
    expect(await File('${dir.path}/a.mp4').readAsBytes(), [1, 2, 3, 4]);
    expect(dir.listSync().length, 1);
  });
  const server = ServerConnection(
    baseUrl: 'https://fixture.example/prefix',
    apiKey: 'fixture-key',
  );
  MediaSaveSource source(String name) => MediaSaveSource.remote(
    server,
    server.endpoint('/v1/media/$name?cap=synthetic.capability'),
  );
  test('one folder; sequential bytes, partial failure, collision skip and progress', () async {
    final dir = await Directory.systemTemp.createTemp('library-test-');
    addTearDown(() => dir.delete(recursive: true));
    await File('${dir.path}/exists.mp4').writeAsBytes([9]);
    var picks = 0;
    final requests = <String>[];
    final progress = <int>[];
    final saver = NativeLibrarySaver(
      pickDirectory: () async {
        picks++;
        return dir.path;
      },
      clientFactory: () => MockClient((request) async {
        requests.add(request.url.pathSegments.last);
        expect(request.headers['authorization'], isNull);
        expect(request.followRedirects, false);
        return http.Response.bytes([
          1,
          2,
          3,
        ], request.url.path.endsWith('bad.mp4') ? 500 : 200);
      }),
    );
    final results = await saver.save(
      [source('a.mp4'), source('bad.mp4'), source('exists.mp4')],
      isCurrent: () => true,
      onProgress: (_, bytes) => progress.add(bytes),
    );
    expect(picks, 1);
    expect(results.map((e) => e.status), [
      LibrarySaveStatus.saved,
      LibrarySaveStatus.failed,
      LibrarySaveStatus.skipped,
    ]);
    expect(requests, ['a.mp4', 'bad.mp4']);
    expect(await File('${dir.path}/a.mp4').readAsBytes(), [1, 2, 3]);
    expect(await File('${dir.path}/exists.mp4').readAsBytes(), [9]);
    expect(progress, contains(3));
    expect(dir.listSync().length, 2);
  });
}
