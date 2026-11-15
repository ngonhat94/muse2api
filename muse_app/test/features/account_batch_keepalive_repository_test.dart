import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muse_app/core/network/json_api_client.dart';
import 'package:muse_app/features/accounts/data/repositories/account_repository_impl.dart';

import 'account_keepalive_repository_test.dart' show server;

void main() {
  test('busy is not completion and malformed responses are uncertain without leaks', () async {
    for (final body in [
      {'status': 'busy', 'message': 'private-cookie'},
      <String, dynamic>{},
      {'status': 'ok'},
    ]) {
      var calls = 0;
      final repo = AccountRepositoryImpl(
        JsonApiClient(
          () => MockClient((_) async {
            calls++;
            return http.Response(jsonEncode(body), 200);
          }),
        ),
      );
      if (body['status'] == 'busy') {
        final result = await repo.keepaliveAll(server);
        expect(result.busy, true);
        expect(result.summary, isNull);
        expect(result.message, isNot(contains('thành công')));
      } else {
        await expectLater(
          repo.keepaliveAll(server),
          throwsA(predicate((e) => !e.toString().contains('private-cookie'))),
        );
      }
      expect(calls, 1);
    }
  });
  testWidgets('ten minute timeout is uncertain and does not retry', (t) async {
    var calls = 0;
    final pending = Completer<http.Response>();
    final repo = AccountRepositoryImpl(
      JsonApiClient(
        () => MockClient((_) {
          calls++;
          return pending.future;
        }),
      ),
    );
    Object? error;
    repo
        .keepaliveAll(server)
        .then(
          (_) {},
          onError: (Object e) {
            error = e;
          },
        );
    await t.pump(const Duration(minutes: 9));
    expect(error, isNull);
    await t.pump(const Duration(minutes: 2));
    expect(error.toString(), contains('Server có thể vẫn đang chạy'));
    expect(calls, 1);
    pending.complete(http.Response('{}', 200));
    await t.pump();
  });
  test(
    'missing, contradictory and malformed entries never manufacture successes',
    () async {
      final repo = AccountRepositoryImpl(
        JsonApiClient(
          () => MockClient(
            (_) async => http.Response(
              jsonEncode({
                'refreshed_count': 5,
                'refreshed': [
                  {'ok': true, 'busy': true},
                  {'ok': false},
                  null,
                  {'ok': 1},
                ],
                'skipped': [{}, {}, {}],
              }),
              200,
            ),
          ),
        ),
      );
      final s = (await repo.keepaliveAll(server)).summary!;
      expect(s.successes, 0);
      expect(s.failures, 1);
      expect(s.unknown, 4);
      expect(s.skipped, 3);
    },
  );
  test(
    'batch posts force query without body and counts attempts, not successes',
    () async {
      final requests = <http.Request>[];
      final repo = AccountRepositoryImpl(
        JsonApiClient(
          () => MockClient((r) async {
            requests.add(r);
            return http.Response(
              jsonEncode({
                'refreshed_count': 4,
                'refreshed': [
                  {'ok': true},
                  {'ok': false, 'busy': true},
                  {'ok': 'true'},
                ],
                'skipped_count': 2,
              }),
              200,
            );
          }),
        ),
      );
      final result = await repo.keepaliveAll(server);
      expect(requests.single.method, 'POST');
      expect(
        requests.single.url.toString(),
        'https://example.com/muse/admin/accounts/keepalive?force=true',
      );
      expect(requests.single.body, isEmpty);
      expect(result.summary!.attempts, 4);
      expect(result.summary!.successes, 1);
      expect(result.summary!.failures, 1);
      expect(result.summary!.unknown, 2);
      expect(result.summary!.skipped, 2);
    },
  );
}
