import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muse_app/core/network/json_api_client.dart';
import 'package:muse_app/features/accounts/data/repositories/account_repository_impl.dart';
import 'package:muse_app/features/accounts/domain/usecases/manage_accounts.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';

const server = ServerConnection(
  baseUrl: 'https://example.com/muse',
  apiKey: 'fixture',
);
void main() {
  test(
    'invalid acknowledgements and server errors never expose response secrets',
    () async {
      for (final body in [
        '{}',
        '{"ok":false}',
        '{"ok":true,"id":"other","cookie_count":1}',
        '{"ok":true,"id":"a","cookie_count":0}',
        '{"ok":true,"id":"a","cookie_count":1.5}',
        '{"detail":"hatch_sess=secret"}',
      ]) {
        final repo = AccountRepositoryImpl(
          JsonApiClient(
            () => MockClient(
              (_) async =>
                  http.Response(body, body.contains('detail') ? 400 : 200),
            ),
          ),
        );
        await expectLater(
          repo.updateCookies(server, 'a', 'x=y'),
          throwsA(predicate((e) => !e.toString().contains('secret'))),
        );
      }
    },
  );
  test('empty input and missing account id cannot send requests', () async {
    var calls = 0;
    final manage = ManageAccounts(
      AccountRepositoryImpl(
        JsonApiClient(
          () => MockClient((_) async {
            calls++;
            return http.Response('{}', 200);
          }),
        ),
      ),
    );
    await expectLater(
      manage.updateCookies(server, 'a', '  '),
      throwsA(anything),
    );
    await expectLater(
      manage.updateCookies(server, '', 'x=y'),
      throwsA(anything),
    );
    expect(calls, 0);
  });
  test('cookie update posts only replacement cookie header and validates acknowledgement', () async {
    final requests = <http.Request>[];
    final manage = ManageAccounts(
      AccountRepositoryImpl(
        JsonApiClient(
          () => MockClient((request) async {
            requests.add(request);
            return http.Response(
              '{"ok":true,"id":"a/b","cookie_count":2,"expires_at":null}',
              200,
            );
          }),
        ),
      ),
    );
    final message = await manage.updateCookies(
      server,
      'a/b',
      '  hatch_sess=fixture; other=value  ',
    );
    expect(requests.single.method, 'POST');
    expect(
      requests.single.url.toString(),
      'https://example.com/muse/admin/accounts/a%2Fb/cookies',
    );
    expect(jsonDecode(requests.single.body), {
      'cookie_header': 'hatch_sess=fixture; other=value',
    });
    expect(message, contains('chưa được xác nhận'));
    expect(message, isNot(contains('fixture')));
  });
}
