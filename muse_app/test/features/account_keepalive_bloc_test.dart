import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:muse_app/core/errors/app_failure.dart';
import 'package:muse_app/features/accounts/domain/entities/muse_account.dart';
import 'package:muse_app/features/accounts/domain/repositories/account_repository.dart';
import 'package:muse_app/features/accounts/domain/usecases/manage_accounts.dart';
import 'package:muse_app/features/accounts/presentation/bloc/account_bloc.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';

import 'account_keepalive_repository_test.dart' show server;

class KeepaliveRepo implements AccountRepository {
  int calls = 0, lists = 0;
  bool fail = false, reloadFails = false;
  Completer<String>? pending;
  List<MuseAccount> items = [
    const MuseAccount(id: 'a', label: 'A', enabled: true),
  ];
  @override
  Future<List<MuseAccount>> list(ServerConnection c) async {
    lists++;
    if (reloadFails) throw const AppFailure('private-reload');
    return items;
  }

  @override
  Future<String> act(
    ServerConnection c,
    String id,
    AccountAction action,
  ) async {
    calls++;
    if (fail) throw const AppFailure('Tài khoản đang bận.');
    return pending?.future ?? 'Đã duy trì phiên.';
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<void> tick() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

Future<AccountBloc> loaded(KeepaliveRepo r) async {
  final b = AccountBloc(ManageAccounts(r));
  b.add(AccountsLoaded(server));
  await tick();
  return b;
}

void main() {
  test('duplicates, removed accounts, stale connections and late results are ignored', () async {
    final r = KeepaliveRepo();
    final b = await loaded(r);
    addTearDown(b.close);
    b.add(AccountActed(server, 'removed', AccountAction.keepalive));
    await tick();
    b.add(
      AccountActed(
        const ServerConnection(
          baseUrl: 'https://other.example',
          apiKey: 'fixture',
        ),
        'a',
        AccountAction.keepalive,
      ),
    );
    await tick();
    expect(r.calls, 0);
    r.pending = Completer<String>();
    b.add(AccountActed(server, 'a', AccountAction.keepalive));
    b.add(AccountActed(server, 'a', AccountAction.keepalive));
    await tick();
    expect(r.calls, 1);
    b.add(AccountsCleared());
    await tick();
    r.pending!.complete('late success');
    await tick();
    expect(b.state.items, isEmpty);
    expect(b.state.message, isNull);
    expect(r.lists, 1);
  });
  test('business failure still reloads health; reload failure is separate from outcome', () async {
    final r = KeepaliveRepo()..fail = true;
    final b = await loaded(r);
    addTearDown(b.close);
    r.items = [
      const MuseAccount(id: 'a', label: 'A', enabled: true, healthy: false),
    ];
    b.add(AccountActed(server, 'a', AccountAction.keepalive));
    await tick();
    expect(r.lists, 2);
    expect(b.state.items.single.healthy, false);
    expect(b.state.error, contains('đang bận'));
    r.fail = false;
    r.reloadFails = true;
    b.add(AccountActed(server, 'a', AccountAction.keepalive));
    await tick();
    expect(b.state.message, 'Đã duy trì phiên.');
    expect(b.state.error, contains('Không tải lại được danh sách'));
    expect(b.state.error, isNot(contains('private-reload')));
  });
}
