import 'dart:async';

import 'package:test/test.dart';
import 'package:muse_app/core/errors/app_failure.dart';
import 'package:muse_app/core/presentation/collection_bloc.dart';
import 'package:muse_app/features/accounts/domain/entities/muse_account.dart';
import 'package:muse_app/features/accounts/domain/repositories/account_repository.dart';
import 'package:muse_app/features/accounts/domain/usecases/manage_accounts.dart';
import 'package:muse_app/features/accounts/presentation/bloc/account_bloc.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';

const connection = ServerConnection(
  baseUrl: 'https://example.com',
  apiKey: 'key',
);

class FakeAccounts implements AccountRepository {
  bool fail = false;
  bool imported = false;
  Completer<String>? pending;
  @override
  Future<List<MuseAccount>> list(ServerConnection c) async => [
    const MuseAccount(id: 'a', label: 'A', enabled: true),
  ];
  @override
  Future<String> import(
    ServerConnection c,
    String label,
    String cookieHeader,
  ) async {
    imported = true;
    return 'Imported';
  }

  @override
  Future<String> act(
    ServerConnection c,
    String id,
    AccountAction action,
  ) async {
    if (pending != null) return pending!.future;
    if (fail) throw const AppFailure('Session unconfirmed');
    return 'Done';
  }
}

void main() {
  test('List refresh failure preserves last successful data', () async {
    var fail = false;
    final bloc = CollectionBloc<int>((_) async {
      if (fail) throw const AppFailure('Offline');
      return [1];
    });
    addTearDown(bloc.close);
    final first = bloc.stream.firstWhere((s) => !s.loading);
    bloc.add(CollectionLoaded(connection));
    await first;
    fail = true;
    final second = bloc.stream.firstWhere((s) => s.error != null);
    bloc.add(CollectionLoaded(connection));
    await second;
    expect(bloc.state.items, [1]);
  });
  test('Clearing lists drops late response from previous server', () async {
    final pending = Completer<List<int>>();
    final bloc = CollectionBloc<int>((_) => pending.future);
    addTearDown(bloc.close);
    final started = bloc.stream.firstWhere((s) => s.loading);
    bloc.add(CollectionLoaded(connection));
    await started;
    final cleared = bloc.stream.firstWhere((s) => !s.loading);
    bloc.add(CollectionCleared());
    await cleared;
    pending.complete([1]);
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.items, isEmpty);
  });
  test('Import refreshes account list and reports success for clearing cookie form', () async {
    final r = FakeAccounts();
    final bloc = AccountBloc(ManageAccounts(r));
    addTearDown(bloc.close);
    final listed = bloc.stream.firstWhere((s) => !s.busy && s.items.isNotEmpty);
    bloc.add(AccountsLoaded(connection));
    await listed;
    final done = bloc.stream.firstWhere((s) => s.imported);
    bloc.add(AccountImported(connection, 'A', 'hatch_sess=fixture'));
    await done;
    expect(bloc.state.items.single.id, 'a');
    expect(r.imported, true);
  });
  test(
    'Failed account test displays failure, not a successful status',
    () async {
      final r = FakeAccounts()..fail = true;
      final bloc = AccountBloc(ManageAccounts(r));
      addTearDown(bloc.close);
      final failed = bloc.stream.firstWhere((s) => s.error != null);
      bloc.add(AccountActed(connection, 'a', AccountAction.test));
      await failed;
      expect(bloc.state.message, isNull);
      expect(bloc.state.busy, false);
    },
  );
  test(
    'Account action cannot repopulate list after changing connection',
    () async {
      final r = FakeAccounts()..pending = Completer<String>();
      final bloc = AccountBloc(ManageAccounts(r));
      addTearDown(bloc.close);
      final started = bloc.stream.firstWhere((s) => s.busy);
      bloc.add(AccountActed(connection, 'a', AccountAction.quota));
      await started;
      final cleared = bloc.stream.firstWhere((s) => !s.busy);
      bloc.add(AccountsCleared());
      await cleared;
      r.pending!.complete('Done');
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.items, isEmpty);
      expect(bloc.state.message, isNull);
    },
  );
}
