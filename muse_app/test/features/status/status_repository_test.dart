import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muse_app/core/network/json_api_client.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';
import 'package:muse_app/features/status/data/repositories/server_status_repository_impl.dart';

void main() {
  const connection = ServerConnection(
    baseUrl: 'https://example.test',
    apiKey: 'test',
  );
  test('status uses GET only and projects verified summary fields', () async {
    final requests = <http.Request>[];
    final repository = ServerStatusRepositoryImpl(
      JsonApiClient(
        () => MockClient((r) async {
          requests.add(r);
          return http.Response(
            jsonEncode({
              'browser_running': false,
              'media_count': 0,
              'stats': {
                'total': 7,
                'enabled': 5,
                'disabled': 2,
                'healthy': 3,
                'error': 1,
                'expiring': 2,
                'expired': 1,
              },
              'accounts': [
                {'cookies': 'secret'},
              ],
              'config': {'host': 'private'},
              'tasks': [
                {'prompt': 'private'},
              ],
              'essential_cookies': ['private'],
              'base_url': 'private',
            }),
            200,
          );
        }),
      ),
    );
    final status = await repository.load(connection);
    expect(requests.single.method, 'GET');
    expect(requests.single.url.path, '/admin/status');
    expect(requests.single.body, isEmpty);
    expect(status.browserRunning, false);
    expect(status.mediaCount, 0);
    expect(status.totalAccounts, 7);
    expect(status.enabledAccounts, 5);
    expect(status.disabledAccounts, 2);
    expect(status.healthyAccounts, 3);
    expect(status.errorAccounts, 1);
    expect(status.expiringAccounts, 2);
    expect(status.expiredAccounts, 1);
    expect(status.toString(), isNot(contains('private')));
    expect(status.toString(), isNot(contains('secret')));
  });
  test(
    'missing null or malformed fields are unknown, never inferred',
    () async {
      for (final payload in <Map<String, dynamic>>[
        {},
        {'browser_running': null, 'media_count': null, 'stats': null},
        {
          'browser_running': 'true',
          'media_count': -1,
          'stats': {'total': '7', 'enabled': 2.5, 'healthy': true, 'error': -2},
        },
        {'stats': []},
      ]) {
        final repository = ServerStatusRepositoryImpl(
          JsonApiClient(
            () => MockClient(
              (_) async => http.Response(jsonEncode(payload), 200),
            ),
          ),
        );
        final status = await repository.load(connection);
        expect(status.browserRunning, isNull);
        expect(status.mediaCount, isNull);
        expect(status.totalAccounts, isNull);
        expect(status.enabledAccounts, isNull);
        expect(status.healthyAccounts, isNull);
        expect(status.errorAccounts, isNull);
      }
    },
  );
  test(
    'unsupported and invalid JSON responses fail without success data',
    () async {
      for (final response in [
        http.Response('not JSON', 200),
        http.Response('[]', 200),
        http.Response('{"detail":"private"}', 404),
      ]) {
        final repository = ServerStatusRepositoryImpl(
          JsonApiClient(() => MockClient((_) async => response)),
        );
        await expectLater(repository.load(connection), throwsA(anything));
      }
    },
  );
}
