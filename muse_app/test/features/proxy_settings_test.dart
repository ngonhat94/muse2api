import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:muse_app/core/errors/app_failure.dart';
import 'package:muse_app/core/network/json_api_client.dart';
import 'package:muse_app/features/accounts/domain/entities/account_proxy.dart';
import 'package:muse_app/features/accounts/domain/usecases/manage_proxy.dart';
import 'package:muse_app/features/accounts/data/repositories/proxy_repository_impl.dart';
import 'package:muse_app/features/accounts/presentation/bloc/proxy_bloc.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';

const connection = ServerConnection(
  baseUrl: 'https://example.com/muse',
  apiKey: 'fixture',
);
void main() {
  test(
    'Normalizes supported protocols, default ports and IPv6 exactly as backend',
    () {
      expect(
        ProxyConfiguration.normalizeServer('http://host/'),
        'http://host:80',
      );
      expect(
        ProxyConfiguration.normalizeServer('socks5://host'),
        'socks5://host:1080',
      );
      expect(
        ProxyConfiguration.normalizeServer('socks5h://[::1]:1081'),
        'socks5h://[::1]:1081',
      );
      for (final raw in [
        'https://host:80',
        'http://user:password@host:80',
        'http://host/a',
        'http://host?secret=yes',
        'http://host:70000',
        'invalid',
      ]) {
        expect(
          () => ProxyConfiguration.normalizeServer(raw),
          throwsA(isA<AppFailure>()),
        );
      }
    },
  );
  test('Blank password preserves only matching saved identity; explicit clear sends empty password', () {
    const saved = SavedAccountProxy(
      server: 'http://host:80',
      username: 'user',
      hasPassword: true,
    );
    expect(
      ProxyConfiguration.parse(
        'http://host',
        'user',
        '',
        previous: saved,
      ).password,
      isNull,
    );
    expect(
      () => ProxyConfiguration.parse(
        'http://newhost',
        'user',
        '',
        previous: saved,
      ),
      throwsA(isA<AppFailure>()),
    );
    expect(
      () => ProxyConfiguration.parse(
        'http://host',
        'newuser',
        '',
        previous: saved,
      ),
      throwsA(isA<AppFailure>()),
    );
    expect(
      ProxyConfiguration.parse(
        'http://host',
        'user',
        '',
        previous: saved,
        clearPassword: true,
      ).password,
      '',
    );
    expect(
      ProxyConfiguration.parse('socks5://host', 'user', 'secret').toString(),
      isNot(contains('secret')),
    );
  });
  test('Invalid credentials fail before a request can be sent', () {
    expect(
      () => ProxyConfiguration.parse('http://host', 'name:bad', 'secret'),
      throwsA(isA<AppFailure>()),
    );
    expect(
      () => ProxyConfiguration.parse('http://host', 'user', '日本'),
      throwsA(isA<AppFailure>()),
    );
  });
  test('Proxy patch omits preserved password, explicit removal is null and test never saves', () async {
    final requests = <http.Request>[];
    final repo = ProxyRepositoryImpl(
      JsonApiClient(
        () => MockClient((request) async {
          requests.add(request);
          return http.Response(
            '{"ok":true,"proxy_reachable":true,"session_ok":true,"exit_ip":"203.0.113.1"}',
            200,
          );
        }),
      ),
    );
    final proxy = ProxyConfiguration.parse(
      'http://host',
      'user',
      '',
      previous: const SavedAccountProxy(
        server: 'http://host:80',
        username: 'user',
        hasPassword: true,
      ),
    );
    await repo.save(connection, 'acc', proxy);
    expect(
      (jsonDecode(requests.first.body)['proxy'] as Map).containsKey('password'),
      false,
    );
    await repo.save(connection, 'acc', null);
    expect(jsonDecode(requests[1].body), {'proxy': null});
    final result = await repo.test(connection, 'acc', proxy);
    expect(result.passed, true);
    expect(requests.last.method, 'POST');
    expect(requests.last.url.path, '/muse/admin/accounts/acc/proxy/test');
    expect(requests.where((r) => r.method == 'PATCH').length, 2);
  });
  test(
    'Reachable proxy without confirmed Muse session is not a pass',
    () async {
      final repo = ProxyRepositoryImpl(
        JsonApiClient(
          () => MockClient(
            (_) async => http.Response(
              '{"ok":false,"proxy_reachable":true,"session_ok":false}',
              200,
            ),
          ),
        ),
      );
      final result = await repo.test(
        connection,
        'acc',
        ProxyConfiguration.parse('http://host', '', ''),
      );
      expect(result.reachable, true);
      expect(result.passed, false);
    },
  );
  test('Editing invalidates previous test result', () async {
    final repo = ProxyRepositoryImpl(
      JsonApiClient(
        () => MockClient(
          (_) async => http.Response(
            '{"ok":true,"proxy_reachable":true,"session_ok":true}',
            200,
          ),
        ),
      ),
    );
    final bloc = ProxyBloc(ManageProxy(repo), connection, 'acc');
    addTearDown(bloc.close);
    final checked = bloc.stream.firstWhere((s) => s.check != null);
    bloc.add(
      ProxyTestRequested(ProxyConfiguration.parse('http://host', '', '')),
    );
    await checked;
    final changed = bloc.stream.firstWhere((s) => s.check == null && !s.busy);
    bloc.add(ProxyEdited());
    await changed;
    expect(bloc.state.check, isNull);
  });
  test('Busy account errors do not report a successful save', () async {
    final repo = ProxyRepositoryImpl(
      JsonApiClient(
        () => MockClient((_) async => http.Response('{"detail":"busy"}', 409)),
      ),
    );
    final bloc = ProxyBloc(ManageProxy(repo), connection, 'acc');
    addTearDown(bloc.close);
    final failed = bloc.stream.firstWhere((s) => s.error != null);
    bloc.add(ProxySaved(ProxyConfiguration.parse('http://host', '', '')));
    await failed;
    expect(bloc.state.saved, false);
    expect(bloc.state.busy, false);
  });
}
