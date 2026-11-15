import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muse_app/core/network/json_api_client.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';
import 'package:muse_app/features/media/data/repositories/media_repository_impl.dart';

void main() {
  const connection = ServerConnection(
    baseUrl: 'https://example.test',
    apiKey: 'test',
  );
  test(
    'batch deletion preserves removed count and sanitizes partial errors',
    () async {
      final repo = MediaRepositoryImpl(
        JsonApiClient(
          () => MockClient((request) async {
            expect(request.method, 'POST');
            expect(request.url.path, '/admin/media/delete');
            expect(jsonDecode(request.body), {
              'names': ['a.png', 'b.png'],
            });
            return http.Response(
              jsonEncode({
                'removed': 1,
                'errors': ['b.png: /private/secret'],
              }),
              200,
            );
          }),
        ),
      );
      final result = await repo.deleteBatch(connection, ['a.png', 'b.png']);
      expect(result.removed, 1);
      expect(result.errorCount, 1);
      expect(result.toString(), isNot(contains('/private')));
    },
  );
  test('unsafe filenames are rejected without HTTP', () async {
    var calls = 0;
    final repo = MediaRepositoryImpl(
      JsonApiClient(
        () => MockClient((_) async {
          calls++;
          return http.Response('{}', 200);
        }),
      ),
    );
    for (final name in ['../a', 'a/b', r'a\b', 'https://evil/a', '', 'a%2fb']) {
      await expectLater(repo.deleteSingle(connection, name), throwsA(anything));
      await expectLater(
        repo.deleteBatch(connection, [name]),
        throwsA(anything),
      );
    }
    expect(calls, 0);
  });
  test(
    'single deletion encodes a library filename as one path segment',
    () async {
      final repo = MediaRepositoryImpl(
        JsonApiClient(
          () => MockClient((request) async {
            expect(request.method, 'DELETE');
            expect(request.url.pathSegments, ['admin', 'media', 'a #?.png']);
            return http.Response(
              jsonEncode({'status': 'ok', 'deleted': 'a #?.png'}),
              200,
            );
          }),
        ),
      );
      await repo.deleteSingle(connection, 'a #?.png');
    },
  );
}
