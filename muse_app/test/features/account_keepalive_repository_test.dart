import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muse_app/core/network/json_api_client.dart';
import 'package:muse_app/features/accounts/data/repositories/account_repository_impl.dart';
import 'package:muse_app/features/accounts/domain/repositories/account_repository.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';

const server = ServerConnection(
  baseUrl: 'https://example.com/muse',
  apiKey: 'fixture',
);
void main() {
  test('HTTP failure does not expose upstream details or retry', () async {
    var calls = 0;
    final repo = AccountRepositoryImpl(
      JsonApiClient(
        () => MockClient((_) async {
          calls++;
          return http.Response('{"detail":"private-cookie"}', 400);
        }),
      ),
    );
    await expectLater(
      repo.act(server, 'a', AccountAction.keepalive),
      throwsA(predicate((e) => !e.toString().contains('private-cookie'))),
    );
    expect(calls, 1);
  });
  test('business failures, busy and malformed responses are not success or leaked errors', () async {
    for (final body in [
      {'ok': false, 'id': 'a', 'busy': true, 'error': 'private-cookie'},
      {'ok': false, 'id': 'a', 'error': 'private-cookie'},
      {'ok': true, 'id': 'other'},
      <String, dynamic>{},
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
      await expectLater(
        repo.act(server, 'a', AccountAction.keepalive),
        throwsA(predicate((e) => !e.toString().contains('private-cookie'))),
      );
      expect(calls, 1);
    }
  });
  test(
    'false or missing wake acknowledgement cannot claim workspace wake',
    () async {
      for (final wake in [false, null]) {
        final repo = AccountRepositoryImpl(
          JsonApiClient(
            () => MockClient(
              (_) async => http.Response(
                jsonEncode({
                  'ok': true,
                  'id': 'a',
                  'wake_ok': wake,
                  'vm_state': 'RUNNING',
                }),
                200,
              ),
            ),
          ),
        );
        final message = await repo.act(server, 'a', AccountAction.keepalive);
        expect(message, contains('chưa xác nhận đánh thức workspace'));
        expect(message, isNot(contains('đã xác nhận đánh thức workspace')));
      }
    },
  );
  testWidgets('keepalive has a 150 second timeout and never retries', (
    t,
  ) async {
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
    repo.act(server, 'a', AccountAction.keepalive).catchError((Object e) {
      error = e;
      return '';
    });
    await t.pump(const Duration(seconds: 149));
    expect(error, isNull);
    await t.pump(const Duration(seconds: 2));
    expect(error, isNotNull);
    expect(calls, 1);
    pending.complete(http.Response('{}', 200));
    await t.pump();
  });
  test('keepalive sends one encoded per-account POST without body', () async {
    final requests = <http.Request>[];
    final repo = AccountRepositoryImpl(
      JsonApiClient(
        () => MockClient((r) async {
          requests.add(r);
          return http.Response(
            jsonEncode({
              'ok': true,
              'id': ' a/b?#',
              'wake_ok': true,
              'vm_state': 'RUNNING',
            }),
            200,
          );
        }),
      ),
    );
    final message = await repo.act(server, ' a/b?#', AccountAction.keepalive);
    expect(
      requests.single.url.toString(),
      'https://example.com/muse/admin/accounts/%20a%2Fb%3F%23/keepalive',
    );
    expect(requests.single.method, 'POST');
    expect(requests.single.body, isEmpty);
    expect(message, contains('đã xác nhận đánh thức workspace'));
    expect(message, contains('Quota vẫn là dữ liệu lưu đệm'));
  });
}
