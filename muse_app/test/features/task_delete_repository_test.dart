import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muse_app/core/network/json_api_client.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';
import 'package:muse_app/features/tasks/data/repositories/task_repository_impl.dart';

const server = ServerConnection(
  baseUrl: 'https://example.test',
  apiKey: 'test',
);
void main() {
  for (final payload in ['{}', '{"deleted":false}']) {
    test('rejects unconfirmed delete $payload', () async {
      final repo = TaskRepositoryImpl(
        JsonApiClient(
          () => MockClient((_) async => http.Response(payload, 200)),
        ),
      );
      await expectLater(repo.delete(server, 'a'), throwsFormatException);
    });
  }
  for (final payload in ['{}', '{"removed":-1}', '{"removed":"2"}']) {
    test('rejects malformed clear count $payload', () async {
      final repo = TaskRepositoryImpl(
        JsonApiClient(
          () => MockClient((_) async => http.Response(payload, 200)),
        ),
      );
      await expectLater(repo.clear(server), throwsFormatException);
    });
  }
  test('clear explicitly keeps zero and returns confirmed count', () async {
    final repo = TaskRepositoryImpl(
      JsonApiClient(
        () => MockClient((r) async {
          expect(r.method, 'POST');
          expect(r.url.path, '/admin/tasks/clear');
          expect(jsonDecode(r.body), {'keep': 0});
          return http.Response('{"removed":3}', 200);
        }),
      ),
    );
    expect(await (repo as dynamic).clear(server), 3);
  });
  test(
    'delete encodes task ID as one path segment and validates acknowledgement',
    () async {
      final repo = TaskRepositoryImpl(
        JsonApiClient(
          () => MockClient((r) async {
            expect(r.method, 'DELETE');
            expect(r.url.pathSegments.last, 'a/b?x');
            return http.Response('{"deleted":true}', 200);
          }),
        ),
      );
      await (repo as dynamic).delete(server, 'a/b?x');
    },
  );
}
