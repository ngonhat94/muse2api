import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muse_app/core/network/json_api_client.dart';
import 'package:muse_app/features/videos/data/repositories/video_repository_impl.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';

void main() {
  test(
    'video same-key manual retry sends identical body and no hidden POST',
    () async {
      final requests = <http.Request>[];
      final api = JsonApiClient(
        () => MockClient((request) async {
          requests.add(request);
          if (requests.length == 1) throw Exception('response lost');
          return http.Response(
            jsonEncode({'id': 'task_fixture', 'status': 'queued'}),
            200,
          );
        }),
      );
      final repository = VideoRepositoryImpl(api);
      const connection = ServerConnection(
        baseUrl: 'https://example.com',
        apiKey: 'synthetic',
      );
      await expectLater(
        repository.create(
          connection,
          'private fixture',
          '16:9',
          6,
          requestKey: 'same-intent',
        ),
        throwsA(anything),
      );
      expect(requests, hasLength(1));
      final task = await repository.create(
        connection,
        'private fixture',
        '16:9',
        6,
        requestKey: 'same-intent',
      );
      expect(task.id, 'task_fixture');
      expect(requests, hasLength(2));
      expect(requests[0].headers['Idempotency-Key'], 'same-intent');
      expect(requests[1].headers['Idempotency-Key'], 'same-intent');
      expect(requests[0].body, requests[1].body);
    },
  );
}
