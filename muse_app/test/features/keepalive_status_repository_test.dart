import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muse_app/core/network/json_api_client.dart';
import 'package:muse_app/features/accounts/data/repositories/account_repository_impl.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';

const server = ServerConnection(
  baseUrl: 'https://example.test/prefix',
  apiKey: 'fixture',
);
void main() {
  test('old and malformed responses stay unknown without retaining private payloads', () async {
    for (final body in [
      <String, dynamic>{},
      {
        'running': 'false',
        'last_run': 'yesterday',
        'next_run': -1,
        'last_result': 'private-cookie',
      },
      {'running': null, 'last_run': 1e100, 'next_run': [], 'last_result': null},
    ]) {
      final repo = AccountRepositoryImpl(
        JsonApiClient(
          () => MockClient((_) async => http.Response(jsonEncode(body), 200)),
        ),
      );
      final status = await repo.keepaliveStatus(server);
      expect(status.running, isNull);
      expect(status.lastRun, isNull);
      expect(status.nextRun, isNull);
      expect(status.lastResult, isNull);
      expect(status.toString(), isNot(contains('private-cookie')));
    }
  });
  test(
    'missing result entries leave all reported attempts unconfirmed',
    () async {
      for (final entries in [null, 'private-cookie']) {
        final repo = AccountRepositoryImpl(
          JsonApiClient(
            () => MockClient(
              (_) async => http.Response(
                jsonEncode({
                  'last_result': {
                    'refreshed_count': 4,
                    'refreshed': entries,
                    'skipped_count': 'bad',
                  },
                }),
                200,
              ),
            ),
          ),
        );
        final summary = (await repo.keepaliveStatus(server)).lastResult!;
        expect(summary.attempts, 4);
        expect(summary.successes, 0);
        expect(summary.failures, 0);
        expect(summary.unknown, 4);
        expect(summary.skipped, isNull);
      }
    },
  );
  test(
    'HTTP errors including old server 404 never leak server details or retry',
    () async {
      for (final code in [400, 401, 404, 500]) {
        var calls = 0;
        final repo = AccountRepositoryImpl(
          JsonApiClient(
            () => MockClient((_) async {
              calls++;
              return http.Response('{"detail":"private-cookie"}', code);
            }),
          ),
        );
        await expectLater(
          repo.keepaliveStatus(server),
          throwsA(predicate((e) => !e.toString().contains('private-cookie'))),
        );
        expect(calls, 1);
      }
    },
  );
  test('attempts are not successes: partial, busy and unknown results are distinct', () async {
    final repo = AccountRepositoryImpl(
      JsonApiClient(
        () => MockClient(
          (_) async => http.Response(
            jsonEncode({
              'running': true,
              'last_run': 1700000000,
              'next_run': 1700000900,
              'last_result': {
                'checked_at': 1700000000,
                'refreshed_count': 5,
                'skipped_count': 2,
                'refreshed': [
                  {'ok': true},
                  {'ok': false},
                  {'ok': false, 'busy': true},
                  {'ok': 'true'},
                ],
              },
            }),
            200,
          ),
        ),
      ),
    );
    final status = await repo.keepaliveStatus(server);
    expect(status.running, true);
    expect(status.lastRun!.millisecondsSinceEpoch, 1700000000000);
    expect(status.nextRun!.millisecondsSinceEpoch, 1700000900000);
    final summary = status.lastResult!;
    expect(summary.attempts, 5);
    expect(summary.successes, 1);
    expect(summary.failures, 2);
    expect(summary.busy, 1);
    expect(summary.unknown, 2);
    expect(summary.skipped, 2);
    expect(summary.checkedAt, status.lastRun);
  });
  test('status uses GET only and preserves initial null history', () async {
    final requests = <http.Request>[];
    final repo = AccountRepositoryImpl(
      JsonApiClient(
        () => MockClient((r) async {
          requests.add(r);
          return http.Response(
            jsonEncode({
              'running': false,
              'last_run': null,
              'next_run': null,
              'last_result': null,
            }),
            200,
          );
        }),
      ),
    );
    final status = await repo.keepaliveStatus(server);
    expect(status.running, false);
    expect(status.lastRun, isNull);
    expect(status.nextRun, isNull);
    expect(status.lastResult, isNull);
    expect(requests.single.method, 'GET');
    expect(requests.single.url.path, '/prefix/admin/keepalive/status');
    expect(requests.single.body, isEmpty);
  });
}
