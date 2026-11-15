import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:muse_app/features/accounts/domain/entities/keepalive_status.dart';
import 'package:muse_app/features/accounts/domain/repositories/keepalive_status_repository.dart';
import 'package:muse_app/features/accounts/presentation/bloc/keepalive_status_bloc.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';

class StatusRepo implements KeepaliveStatusRepository {
  var calls = 0;
  Completer<KeepaliveStatus> pending = Completer();
  @override
  Future<KeepaliveStatus> keepaliveStatus(ServerConnection connection) {
    calls++;
    return pending.future;
  }
}

const server = ServerConnection(
  baseUrl: 'https://example.test',
  apiKey: 'fixture',
);
void main() {
  test('manual GET refresh starts empty, blocks duplicates, retains stale data on safe error', () async {
    final repo = StatusRepo();
    final bloc = KeepaliveStatusBloc(repo, server);
    addTearDown(bloc.close);
    expect(bloc.state.status, isNull);
    expect(repo.calls, 0);
    final first = bloc.refresh();
    expect(bloc.state.busy, true);
    await bloc.refresh();
    expect(repo.calls, 1);
    const status = KeepaliveStatus(running: true);
    repo.pending.complete(status);
    await first;
    expect(bloc.state.status, same(status));
    expect(bloc.state.busy, false);
    repo.pending = Completer();
    final retry = bloc.refresh();
    repo.pending.completeError(Exception('private-cookie'));
    await retry;
    expect(bloc.state.status, same(status));
    expect(bloc.state.error, isNot(contains('private-cookie')));
    expect(bloc.state.error, isNotNull);
  });
  test(
    'disposed connection discards late response and cannot refresh',
    () async {
      final repo = StatusRepo();
      final bloc = KeepaliveStatusBloc(repo, server);
      final pending = bloc.refresh();
      await bloc.close();
      repo.pending.complete(const KeepaliveStatus(running: true));
      await pending;
      await bloc.refresh();
      expect(repo.calls, 1);
      expect(bloc.state.status, isNull);
    },
  );
}
