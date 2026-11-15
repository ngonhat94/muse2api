import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:muse_app/core/domain/generation_task.dart';
import 'package:muse_app/core/errors/app_failure.dart';
import 'package:muse_app/core/network/json_api_client.dart';
import 'package:muse_app/core/network/media_uri.dart';
import 'package:muse_app/features/videos/data/repositories/video_repository_impl.dart';
import 'package:muse_app/features/tasks/data/repositories/task_repository_impl.dart';
import 'package:muse_app/features/media/data/repositories/media_repository_impl.dart';
import 'package:muse_app/features/accounts/data/repositories/account_repository_impl.dart';
import 'package:muse_app/features/accounts/domain/repositories/account_repository.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';

const connection = ServerConnection(
  baseUrl: 'https://example.com/muse',
  apiKey: 'test-key',
);
JsonApiClient api(http.Response Function(http.Request) handler) =>
    JsonApiClient(
      () => MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer test-key');
        return handler(request);
      }),
    );
void main() {
  test('Video POST and polling use backend contract, normalizing completion aliases', () async {
    final calls = <String>[];
    final repository = VideoRepositoryImpl(
      api((request) {
        calls.add(request.method);
        if (request.method == 'POST') {
          expect(request.url.path, '/muse/v1/videos');
          expect(jsonDecode(request.body), {
            'model': 'muse-video',
            'prompt': 'Shiba',
            'size': '16:9',
            'duration': 6,
          });
          return http.Response('{"id":"v1","status":"queued"}', 200);
        }
        expect(request.url.path, '/muse/v1/videos/v1');
        return http.Response(
          '{"id":"v1","status":"succeeded","result":{"url":"/v1/media/movie.mp4?cap=fixture.capability","filename":"movie.mp4"}}',
          200,
        );
      }),
    );
    final queued = await repository.create(connection, 'Shiba', '16:9', 6);
    final done = await repository.get(connection, queued.id);
    expect(done.status, GenerationStatus.completed);
    expect(done.filename, 'movie.mp4');
    expect(
      done.protectedUri.toString(),
      'https://example.com/muse/v1/media/movie.mp4?cap=fixture.capability',
    );
    expect(calls, ['POST', 'GET']);
  });
  test('Task history and library parse server metadata without requesting upstream URLs', () async {
    final client = api((request) {
      if (request.url.path.endsWith('/tasks')) {
        expect(request.url.queryParameters['limit'], '100');
        return http.Response(
          '{"tasks":[{"id":"img1","kind":"image","status":"failed","prompt":"test","created_at":100}]}',
          200,
        );
      }
      return http.Response(
        '{"media":[{"name":"a.webp","url":"/v1/media/a.webp?cap=fixture.capability","kind":"image","bytes":1024,"mtime":100}]}',
        200,
      );
    });
    expect(
      (await TaskRepositoryImpl(client).list(connection)).single.status,
      GenerationStatus.failed,
    );
    final item = (await MediaRepositoryImpl(client).list(connection)).single;
    expect(item.name, 'a.webp');
    expect(item.bytes, 1024);
    expect(item.isVideo, false);
    expect(item.protectedUri?.queryParameters['cap'], 'fixture.capability');
  });
  test(
    'Accounts import, toggle, quota and delete map to explicit endpoints',
    () async {
      final paths = <String>[];
      final repository = AccountRepositoryImpl(
        api((request) {
          paths.add('${request.method} ${request.url.path}');
          if (request.url.path.endsWith('/accounts') &&
              request.method == 'POST') {
            expect(
              jsonDecode(request.body)['cookie_header'],
              'hatch_sess=fixture',
            );
            return http.Response('{"count":1,"essential_missing":[]}', 200);
          }
          if (request.method == 'PATCH') {
            expect(jsonDecode(request.body), {'enabled': false});
          }
          if (request.url.path.endsWith('/quota')) {
            return http.Response(
              '{"found":true,"weekly_used_pct":20,"checked_at":100}',
              200,
            );
          }
          return http.Response('{}', 200);
        }),
      );
      await repository.import(connection, 'My account', 'hatch_sess=fixture');
      await repository.act(connection, 'acc1', AccountAction.disable);
      await repository.act(connection, 'acc1', AccountAction.quota);
      await repository.act(connection, 'acc1', AccountAction.remove);
      expect(paths, [
        'POST /muse/admin/accounts',
        'PATCH /muse/admin/accounts/acc1',
        'POST /muse/admin/accounts/acc1/quota',
        'DELETE /muse/admin/accounts/acc1',
      ]);
    },
  );
  test('Account session test ok=false is never reported as success', () async {
    final repository = AccountRepositoryImpl(
      api((_) => http.Response('{"ok":false,"message":"sensitive"}', 200)),
    );
    await expectLater(
      repository.act(connection, 'acc', AccountAction.test),
      throwsA(isA<AppFailure>()),
    );
  });
  test('Cached quota preserves check time and unknown session state', () async {
    final repository = AccountRepositoryImpl(
      api(
        (_) => http.Response(
          '{"accounts":[{"id":"acc","label":"A","enabled":true,"ok":null,"quota":{"plan":"Free","weekly_used_pct":20,"checked_at":100}}]}',
          200,
        ),
      ),
    );
    final account = (await repository.list(connection)).single;
    expect(account.healthy, isNull);
    expect(account.weeklyUsed, 20);
    expect(account.quotaCheckedAt, isNotNull);
  });
  test(
    'Transport failure is sanitized and never retried automatically',
    () async {
      var calls = 0;
      final client = api((_) {
        calls++;
        return http.Response('test-key', 502);
      });
      await expectLater(
        client.request(connection, '/v1/videos', method: 'POST', body: {}),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.message,
            'message',
            isNot(contains('test-key')),
          ),
        ),
      );
      expect(calls, 1);
    },
  );
  test('Media references cannot escape server media path', () {
    for (final name in ['../file', 'a/b.mp4', 'a\\b.mp4', '']) {
      expect(() => mediaUri(connection, name), throwsA(isA<AppFailure>()));
    }
  });
}
