import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';
import 'package:muse_app/features/status/domain/entities/server_status.dart';
import 'package:muse_app/features/status/domain/repositories/server_status_repository.dart';
import 'package:muse_app/features/status/domain/usecases/load_server_status.dart';
import 'package:muse_app/features/status/presentation/bloc/server_status_bloc.dart';

class PendingStatusRepository implements ServerStatusRepository {
  final calls = <Completer<ServerStatus>>[];
  @override
  Future<ServerStatus> load(ServerConnection connection) {
    final pending = Completer<ServerStatus>();
    calls.add(pending);
    return pending.future;
  }
}

void main() {
  const a = ServerConnection(baseUrl: 'https://a.test', apiKey: 'a');
  const b = ServerConnection(baseUrl: 'https://b.test', apiKey: 'b');
  late PendingStatusRepository repository;
  late ServerStatusBloc bloc;
  setUp(() {
    repository = PendingStatusRepository();
    bloc = ServerStatusBloc(LoadServerStatus(repository));
  });
  tearDown(() => bloc.close());
  test(
    'connection changes do not fetch; refresh requires a connection',
    () async {
      await bloc.refresh();
      bloc.connectionChanged(a);
      expect(repository.calls, isEmpty);
      expect(bloc.state.snapshot, isNull);
    },
  );
  test('duplicate refresh is ignored; same-server failure retains labeled stale snapshot', () async {
    bloc.connectionChanged(a);
    final first = bloc.refresh();
    await bloc.refresh();
    expect(repository.calls, hasLength(1));
    repository.calls[0].complete(const ServerStatus(mediaCount: 8));
    await first;
    expect(bloc.state.snapshot?.mediaCount, 8);
    expect(bloc.state.updatedAt, isNotNull);
    expect(bloc.state.stale, false);
    // An equivalent identity must not discard the current server snapshot.
    bloc.connectionChanged(
      const ServerConnection(baseUrl: 'https://a.test', apiKey: 'a'),
    );
    final refresh = bloc.refresh();
    repository.calls[1].completeError(Exception('private server detail'));
    await refresh;
    expect(bloc.state.snapshot?.mediaCount, 8);
    expect(bloc.state.stale, true);
    expect(bloc.state.error, isNot(contains('private')));
    expect(bloc.state.busy, false);
  });
  test(
    'server switch and disconnect invalidate late responses and clear data',
    () async {
      bloc.connectionChanged(a);
      final old = bloc.refresh();
      bloc.connectionChanged(b);
      expect(bloc.state.busy, false);
      final current = bloc.refresh();
      repository.calls[0].complete(const ServerStatus(mediaCount: 99));
      await old;
      expect(bloc.state.snapshot, isNull);
      expect(bloc.state.busy, true);
      repository.calls[1].complete(const ServerStatus(mediaCount: 2));
      await current;
      final pending = bloc.refresh();
      bloc.connectionChanged(null);
      repository.calls[2].completeError(Exception('late'));
      await pending;
      expect(bloc.state.snapshot, isNull);
      expect(bloc.state.error, isNull);
      expect(bloc.state.updatedAt, isNull);
    },
  );
  test(
    'key changes invalidate state even for the same URL and after reconnect',
    () async {
      bloc.connectionChanged(a);
      final pending = bloc.refresh();
      bloc.connectionChanged(null);
      bloc.connectionChanged(a);
      repository.calls[0].complete(const ServerStatus(mediaCount: 9));
      await pending;
      expect(bloc.state.snapshot, isNull);
      final next = bloc.refresh();
      bloc.connectionChanged(
        const ServerConnection(baseUrl: 'https://a.test', apiKey: 'new'),
      );
      repository.calls[1].complete(const ServerStatus(mediaCount: 10));
      await next;
      expect(bloc.state.snapshot, isNull);
    },
  );
  test('closed bloc ignores a pending response', () async {
    bloc.connectionChanged(a);
    final pending = bloc.refresh();
    await bloc.close();
    repository.calls.single.complete(const ServerStatus());
    await pending;
  });
}
