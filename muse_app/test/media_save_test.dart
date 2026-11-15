import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muse_app/core/data/media_saver_io.dart';
import 'package:muse_app/core/domain/save_media.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';

void main() {
  test('credential-like media name is rejected before native dialog', () async {
    const connection = ServerConnection(
      baseUrl: 'https://fixture.example',
      apiKey: 'fixture-secret',
    );
    var picked = false;
    final saver = NativeMediaSaver(
      pickPath: (_) async {
        picked = true;
        return null;
      },
    );
    await expectLater(
      saver.save(
        MediaSaveSource.remote(
          connection,
          connection.endpoint('/v1/media/fixture-secret.mp4'),
        ),
        isCurrent: () => true,
      ),
      throwsA(isA<Exception>()),
    );
    expect(picked, false);
  });
  test(
    'real local HTTP streams exact bytes with capability but no key or cookies',
    () async {
      final dir = await Directory.systemTemp.createTemp('muse-save-test-');
      addTearDown(() => dir.delete(recursive: true));
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final bytes = List<int>.generate(131072, (i) => i % 256);
      var requests = 0;
      server.listen((request) async {
        requests++;
        expect(
          request.uri.toString(),
          '/prefix/v1/media/fixture.mp4?cap=synthetic.capability',
        );
        expect(request.headers.value('authorization'), isNull);
        expect(request.headers.value('cookie'), isNull);
        request.response.contentLength = bytes.length;
        request.response.add(bytes.sublist(0, 65536));
        await request.response.flush();
        request.response.add(bytes.sublist(65536));
        await request.response.close();
      });
      final connection = ServerConnection(
        baseUrl: 'http://127.0.0.1:${server.port}/prefix',
        apiKey: 'fixture-secret',
      );
      final saver = NativeMediaSaver(
        pickPath: (_) async => '${dir.path}/fixture.mp4',
      );
      expect(
        await saver.save(
          MediaSaveSource.remote(
            connection,
            connection.endpoint(
              '/v1/media/fixture.mp4?cap=synthetic.capability',
            ),
          ),
          isCurrent: () => true,
        ),
        MediaSaveResult.saved,
      );
      expect(await File('${dir.path}/fixture.mp4').readAsBytes(), bytes);
      expect(requests, 1);
    },
  );
  test('generated PNG saves identical bytes and safe extension', () async {
    final dir = await Directory.systemTemp.createTemp('muse-save-test-');
    addTearDown(() => dir.delete(recursive: true));
    final bytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 255, 0]);
    final saver = NativeMediaSaver(
      pickPath: (name) async {
        expect(name, 'muse-image.png');
        return '${dir.path}/image.png';
      },
      clientFactory: () => throw StateError('no network'),
    );
    expect(
      await saver.save(MediaSaveSource.image(bytes), isCurrent: () => true),
      MediaSaveResult.saved,
    );
    expect(await File('${dir.path}/image.png').readAsBytes(), bytes);
  });
  test('stale response never replaces existing destination', () async {
    final dir = await Directory.systemTemp.createTemp('muse-save-test-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/video.mp4');
    await file.writeAsBytes([7]);
    var current = true;
    final saver = NativeMediaSaver(
      pickPath: (_) async => file.path,
      clientFactory: () => MockClient((_) async {
        current = false;
        return http.Response.bytes([1, 2, 3], 200);
      }),
    );
    final source = MediaSaveSource.remote(
      const ServerConnection(
        baseUrl: 'https://fixture.example',
        apiKey: 'secret',
      ),
      Uri.parse(
        'https://fixture.example/v1/media/a.mp4?cap=synthetic.capability',
      ),
    );
    expect(
      await saver.save(source, isCurrent: () => current),
      MediaSaveResult.cancelled,
    );
    expect(await file.readAsBytes(), [7]);
    expect(dir.listSync().length, 1);
  });
  test(
    'idle stream timeout preserves destination and removes staging',
    () async {
      final dir = await Directory.systemTemp.createTemp('muse-save-test-');
      addTearDown(() => dir.delete(recursive: true));
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        request.response.bufferOutput = false;
        request.response.add([1]);
        await request.response.flush();
      });
      final file = File('${dir.path}/video.mp4');
      await file.writeAsBytes([7]);
      final connection = ServerConnection(
        baseUrl: 'http://127.0.0.1:${server.port}',
        apiKey: 'fixture-secret',
      );
      final saver = NativeMediaSaver(
        pickPath: (_) async => file.path,
        idleTimeout: const Duration(milliseconds: 100),
      );
      await expectLater(
        saver.save(
          MediaSaveSource.remote(
            connection,
            connection.endpoint('/v1/media/a.mp4?cap=synthetic.capability'),
          ),
          isCurrent: () => true,
        ),
        throwsA(isA<Exception>()),
      );
      expect(await file.readAsBytes(), [7]);
      expect(dir.listSync().length, 1);
    },
  );
  test('duplicate call while picker pending is cancelled', () async {
    final picker = Completer<String?>();
    var calls = 0;
    final saver = NativeMediaSaver(
      pickPath: (_) {
        calls++;
        return picker.future;
      },
    );
    final source = MediaSaveSource.image(
      Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
    );
    final first = saver.save(source, isCurrent: () => true);
    expect(
      await saver.save(source, isCurrent: () => true),
      MediaSaveResult.cancelled,
    );
    picker.complete(null);
    expect(await first, MediaSaveResult.cancelled);
    expect(calls, 1);
  });

  const connection = ServerConnection(
    baseUrl: 'https://fixture.example/prefix',
    apiKey: 'fixture-secret',
  );
  final valid = MediaSaveSource.remote(
    connection,
    Uri.parse(
      'https://fixture.example/prefix/v1/media/movie.mp4?cap=synthetic.capability',
    ),
  );
  for (final address in [
    'https://evil.example/v1/media/a.mp4',
    'https://fixture.example/prefix/v1/media/../a.mp4',
    'https://fixture.example/prefix/v1/media/a%252f.mp4',
    'https://fixture.example/prefix/v1/media/a.mp4?key=fixture-secret',
    'file:///a.mp4',
    'https://fixture.example/prefix/v1/media/a.exe',
    'https://user@fixture.example/prefix/v1/media/a.mp4',
  ]) {
    test('rejects unsafe media URL before picker: $address', () async {
      var picked = false;
      final saver = NativeMediaSaver(
        pickPath: (_) async {
          picked = true;
          return null;
        },
        clientFactory: () => throw StateError('network must not run'),
      );
      await expectLater(
        saver.save(
          MediaSaveSource.remote(
            connection,
            address.contains('?')
                ? Uri.parse(address)
                : Uri.parse('$address?cap=synthetic.capability'),
          ),
          isCurrent: () => true,
        ),
        throwsA(isA<Exception>()),
      );
      expect(picked, false);
    });
  }
  for (final status in [302, 401, 404, 500]) {
    test('HTTP $status preserves existing file and cleans staging', () async {
      final dir = await Directory.systemTemp.createTemp('muse-save-test-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/chosen.mp4');
      await file.writeAsBytes([7, 8]);
      final saver = NativeMediaSaver(
        pickPath: (_) async => file.path,
        clientFactory: () =>
            MockClient((_) async => http.Response('fixture-secret', status)),
      );
      await expectLater(
        saver.save(valid, isCurrent: () => true),
        throwsA(isA<Exception>()),
      );
      expect(await file.readAsBytes(), [7, 8]);
      expect(dir.listSync().length, 1);
    });
  }
  test('cancel picker performs no network or disk writes', () async {
    final saver = NativeMediaSaver(
      pickPath: (_) async => null,
      clientFactory: () => throw StateError('network must not run'),
    );
    expect(
      await saver.save(valid, isCurrent: () => true),
      MediaSaveResult.cancelled,
    );
  });
  test('stale picker result is discarded before network and writes', () async {
    var current = true;
    final saver = NativeMediaSaver(
      pickPath: (_) async {
        current = false;
        return '/not-written.mp4';
      },
      clientFactory: () => throw StateError('network must not run'),
    );
    expect(
      await saver.save(valid, isCurrent: () => current),
      MediaSaveResult.cancelled,
    );
  });

  test(
    'saves original streamed video bytes without credentials or redirects',
    () async {
      final dir = await Directory.systemTemp.createTemp('muse-save-test-');
      addTearDown(() => dir.delete(recursive: true));
      final target = '${dir.path}/chosen.mp4';
      const connection = ServerConnection(
        baseUrl: 'https://fixture.example/prefix',
        apiKey: 'fixture-secret',
      );
      final source = MediaSaveSource.remote(
        connection,
        Uri.parse(
          'https://fixture.example/prefix/v1/media/movie.mp4?cap=synthetic.capability',
        ),
      );
      final saver = SaveMedia(
        NativeMediaSaver(
          pickPath: (name) async {
            expect(name, 'movie.mp4');
            return target;
          },
          clientFactory: () => MockClient((request) async {
            expect(request.url, source.uri);
            expect(request.headers.containsKey('authorization'), false);
            expect(request.followRedirects, false);
            return http.Response.bytes([0, 255, 1, 128, 17], 200);
          }),
        ),
      );
      expect(
        await saver.save(source, isCurrent: () => true),
        MediaSaveResult.saved,
      );
      expect(await File(target).readAsBytes(), [0, 255, 1, 128, 17]);
      expect(dir.listSync().length, 1);
    },
  );
}
