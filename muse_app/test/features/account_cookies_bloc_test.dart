import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:muse_app/core/errors/app_failure.dart';
import 'package:muse_app/features/accounts/domain/entities/muse_account.dart';
import 'package:muse_app/features/accounts/domain/repositories/account_repository.dart';
import 'package:muse_app/features/accounts/domain/repositories/account_cookies_repository.dart';
import 'package:muse_app/features/accounts/domain/usecases/manage_accounts.dart';
import 'package:muse_app/features/accounts/presentation/bloc/account_bloc.dart';

import 'account_cookies_repository_test.dart' show server;

import 'package:muse_app/features/connection/domain/entities/server_connection.dart';

class CookiesRepo implements AccountRepository, AccountCookiesRepository {
  int calls = 0;
  Completer<String>? pending;
  bool fail = false;
  @override
  Future<List<MuseAccount>> list(ServerConnection c) async => [
    const MuseAccount(id: 'a', label: 'A', enabled: true),
  ];
  @override
  Future<String> updateCookies(
    ServerConnection c,
    String id,
    String cookies,
  ) async {
    calls++;
    if (fail) throw const AppFailure('secret-cookie');
    return pending?.future ?? 'Updated';
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<void> tick() => Future<void>.delayed(Duration.zero);
Future<AccountBloc> loaded(CookiesRepo r) async {
  final bloc = AccountBloc(ManageAccounts(r));
  bloc.add(AccountsLoaded(server));
  await tick();
  await tick();
  return bloc;
}

void main() {
  test('cookie updates ignore duplicate and stale operations and drop late success', () async {
    final r = CookiesRepo()..pending = Completer<String>();
    final b = await loaded(r);
    addTearDown(b.close);
    b.add(AccountCookiesUpdated(server, 'a', 'x=y'));
    b.add(AccountCookiesUpdated(server, 'a', 'x=y'));
    await tick();
    expect(r.calls, 1);
    b.add(AccountsCleared());
    await tick();
    b.add(AccountCookiesUpdated(server, 'a', 'x=y'));
    await tick();
    expect(r.calls, 1);
    r.pending!.complete('Updated');
    await tick();
    await tick();
    expect(b.state.message, isNull);
    expect(b.state.items, isEmpty);
  });
  test(
    'cookie update refreshes list and does not retain event credentials',
    () async {
      final r = CookiesRepo();
      final b = await loaded(r);
      addTearDown(b.close);
      final event = AccountCookiesUpdated(server, 'a', 'secret-cookie');
      expect(event.toString(), isNot(contains('secret-cookie')));
      b.add(event);
      await tick();
      await tick();
      expect(r.calls, 1);
      expect(event.cookies, isEmpty);
      expect(b.state.message, 'Updated');
      expect(b.state.items.single.id, 'a');
      expect(b.state.busy, false);
    },
  );
  test(
    'same URL with a different connection cannot update stale account',
    () async {
      final r = CookiesRepo();
      final b = await loaded(r);
      addTearDown(b.close);
      b.add(
        AccountCookiesUpdated(
          ServerConnection(baseUrl: server.baseUrl, apiKey: 'other-fixture'),
          'a',
          'x=y',
        ),
      );
      await tick();
      await tick();
      expect(r.calls, 0);
    },
  );
  test('cookie failures are sanitized and preserve accounts', () async {
    final r = CookiesRepo()..fail = true;
    final b = await loaded(r);
    addTearDown(b.close);
    b.add(AccountCookiesUpdated(server, 'a', 'secret-cookie'));
    await tick();
    await tick();
    expect(b.state.error, isNotNull);
    expect(b.state.error, isNot(contains('secret-cookie')));
    expect(b.state.items.single.id, 'a');
    expect(b.state.message, isNull);
  });
}
