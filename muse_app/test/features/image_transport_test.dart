import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:muse_app/core/errors/app_failure.dart';
import 'package:muse_app/features/images/data/datasources/image_remote_data_source.dart';
import 'package:muse_app/features/images/data/models/image_task_model.dart';
import 'package:muse_app/features/images/domain/entities/image_task.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';

const connection = ServerConnection(
  baseUrl: 'https://example.com/muse',
  apiKey: 'secret',
);
void main() {
  test(
    'Creates once with idempotency and polls until image bytes are returned',
    () async {
      final requests = <http.Request>[];
      final source = ImageRemoteDataSource(
        () => MockClient((request) async {
          requests.add(request);
          expect(request.headers['Authorization'], 'Bearer secret');
          if (request.method == 'POST') {
            final body = jsonDecode(request.body);
            expect(body['response_format'], 'b64_json');
            expect(body['size'], '16:9');
            expect(body['model'], 'muse-image');
            expect(request.headers['Idempotency-Key'], 'stable-key');
            return http.Response('{"id":"img1","status":"queued"}', 202);
          }
          return http.Response(
            jsonEncode({
              'id': 'img1',
              'status': 'completed',
              'data': [
                {
                  'b64_json': base64Encode([137, 80, 78, 71]),
                },
              ],
            }),
            200,
          );
        }),
      );
      final queued = await source.create(
        connection,
        'Shiba',
        '16:9',
        'stable-key',
      );
      expect(queued.status, ImageTaskStatus.queued);
      final done = await source.get(connection, queued.id);
      expect(done.bytes, [137, 80, 78, 71]);
      expect(done.progress, 100);
      expect(requests.map((r) => r.method), ['POST', 'GET']);
      expect(
        requests.last.url.toString(),
        'https://example.com/muse/v1/images/tasks/img1',
      );
    },
  );
  test(
    'Completed without bytes is an error, not an empty successful preview',
    () {
      expect(
        () => ImageTaskModel.fromJson({
          'id': '1',
          'status': 'completed',
          'data': [],
        }),
        throwsA(isA<AppFailure>()),
      );
    },
  );
  test(
    'Failed task preserves failure state without exposing upstream errors',
    () {
      final task = ImageTaskModel.fromJson({
        'id': '1',
        'status': 'failed',
        'error': 'secret',
      });
      expect(task.status, ImageTaskStatus.failed);
      expect(task.bytes, isNull);
    },
  );
  test('HTTP failures do not leak key or raw upstream response', () async {
    final source = ImageRemoteDataSource(
      () => MockClient((_) async => http.Response('secret', 401)),
    );
    await expectLater(
      source.create(connection, 'Shiba', '1:1', 'key'),
      throwsA(
        isA<AppFailure>().having(
          (e) => e.message,
          'message',
          isNot(contains('secret')),
        ),
      ),
    );
  });
}
