import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:muse_app/core/domain/generation_task.dart';
import 'package:muse_app/core/presentation/collection_bloc.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';
import 'package:muse_app/features/tasks/domain/repositories/task_repository.dart';
import 'package:muse_app/features/tasks/domain/usecases/load_tasks.dart';
import 'package:muse_app/features/tasks/presentation/bloc/task_bloc.dart';

const server = ServerConnection(baseUrl: 'https://one.test', apiKey: 'test');
const other = ServerConnection(baseUrl: 'https://two.test', apiKey: 'test');
const a = GenerationTask(
  id: 'a',
  kind: 'video',
  status: GenerationStatus.processing,
);
const b = GenerationTask(
  id: 'b',
  kind: 'image',
  status: GenerationStatus.completed,
);

class Repository implements TaskRepository {
  List<GenerationTask> items = [a, b];
  int calls = 0;
  int lists = 0;
  Completer<void>? pending;
  Object? failure;
  bool refreshFails = false;
  @override
  Future<List<GenerationTask>> list(ServerConnection c) async {
    lists++;
    if (refreshFails && calls > 0) throw Exception('secret');
    return c.baseUrl == other.baseUrl ? [b] : items;
  }

  @override
  Future<void> delete(ServerConnection c, String id) async {
    calls++;
    await pending?.future;
    if (failure != null) throw failure!;
    items = items.where((e) => e.id != id).toList();
  }

  @override
  Future<void> cancel(ServerConnection c, String id) async {
    calls++;
    items = items.where((e) => e.id != id).toList();
  }

  @override
  Future<int> clear(ServerConnection c) async {
    await delete(c, 'a');
    items = [];
    return 2;
  }
}

Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 20));
void main() {
  test('poll refreshes until paused and load failure is safe', () async {
    final repo = Repository();
    final bloc = TaskBloc(LoadTasks(repo));
    addTearDown(bloc.close);
    bloc.add(CollectionLoaded(server, poll: true));
    await tick();
    await Future<void>.delayed(const Duration(milliseconds: 5100));
    expect(repo.lists, 2);
    bloc.add(CollectionPaused());
    await tick();
    repo.refreshFails = true;
    repo.calls = 1;
    bloc.add(CollectionLoaded(server));
    await tick();
    expect(bloc.state.items, [a, b]);
    expect(bloc.state.loading, false);
    expect(bloc.state.error, isNotNull);
    expect(bloc.state.error, isNot(contains('secret')));
  });
  test('clear uses backend count and refreshes all task states', () async {
    final repo = Repository();
    final bloc = TaskBloc(LoadTasks(repo));
    addTearDown(bloc.close);
    bloc.add(CollectionLoaded(server));
    await tick();
    bloc.add(TaskClearRequested(server));
    await tick();
    expect(repo.calls, 1);
    expect(repo.lists, 2);
    expect(bloc.state.items, isEmpty);
    expect(bloc.state.notice, contains('2'));
  });
  test(
    'failed refresh preserves acknowledged deletion and blocks stale mutations',
    () async {
      final repo = Repository()..refreshFails = true;
      final bloc = TaskBloc(LoadTasks(repo));
      addTearDown(bloc.close);
      bloc.add(CollectionLoaded(server));
      await tick();
      bloc.add(TaskDeleteRequested(server, 'a'));
      await tick();
      expect(bloc.state.stale, true);
      expect(bloc.state.notice, contains('1'));
      expect(bloc.state.error, isNot(contains('secret')));
      bloc.add(TaskDeleteRequested(server, 'b'));
      await tick();
      expect(repo.calls, 1);
      repo.refreshFails = false;
      bloc.add(CollectionLoaded(server));
      await tick();
      expect(bloc.state.stale, false);
    },
  );
  test('failed deletion is sanitized and keeps data', () async {
    final repo = Repository()..failure = Exception('Bearer secret /private');
    final bloc = TaskBloc(LoadTasks(repo));
    addTearDown(bloc.close);
    bloc.add(CollectionLoaded(server));
    await tick();
    bloc.add(TaskDeleteRequested(server, 'a'));
    await tick();
    expect(bloc.state.error, isNotNull);
    expect(bloc.state.error, isNot(contains('secret')));
    expect(bloc.state.items, [a, b]);
    expect(bloc.state.deleting, false);
  });
  test(
    'old deletion cannot overwrite new server and stale requests cannot mutate',
    () async {
      final repo = Repository()..pending = Completer<void>();
      final bloc = TaskBloc(LoadTasks(repo));
      addTearDown(bloc.close);
      bloc.add(CollectionLoaded(server));
      await tick();
      bloc.add(TaskDeleteRequested(other, 'a'));
      await tick();
      expect(repo.calls, 0);
      bloc.add(TaskDeleteRequested(server, 'unknown'));
      await tick();
      expect(repo.calls, 0);
      bloc.add(TaskDeleteRequested(server, 'a'));
      await tick();
      bloc.add(CollectionLoaded(other));
      await tick();
      repo.pending!.complete();
      await tick();
      expect(bloc.state.items, [b]);
      expect(bloc.state.notice, isNull);
      bloc.add(CollectionCleared());
      await tick();
      bloc.add(TaskDeleteRequested(other, 'b'));
      await tick();
      expect(repo.calls, 1);
      expect(bloc.state.items, isEmpty);
    },
  );
  test(
    'duplicate delete and overlapping clear are guarded while pending',
    () async {
      final repo = Repository()..pending = Completer<void>();
      final bloc = TaskBloc(LoadTasks(repo));
      addTearDown(bloc.close);
      bloc.add(CollectionLoaded(server));
      await tick();
      bloc.add(TaskDeleteRequested(server, 'a'));
      await tick();
      bloc.add(TaskDeleteRequested(server, 'a'));
      await tick();
      bloc.add(TaskClearRequested(server));
      await tick();
      expect(repo.calls, 1);
      repo.pending!.complete();
      await tick();
    },
  );
  test('delete active task refreshes confirmed server list', () async {
    final repo = Repository();
    final bloc = TaskBloc(LoadTasks(repo));
    addTearDown(bloc.close);
    bloc.add(CollectionLoaded(server));
    await tick();
    bloc.add(TaskDeleteRequested(server, 'a'));
    await tick();
    expect(repo.calls, 1);
    expect(bloc.state.items, [b]);
    expect(bloc.state.notice, contains('1'));
    expect(bloc.state.deleting, false);
  });
}
