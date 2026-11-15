import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:muse_app/core/presentation/collection_bloc.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';
import 'package:muse_app/features/media/domain/entities/media_item.dart';
import 'package:muse_app/features/media/domain/entities/media_delete_result.dart';
import 'package:muse_app/features/media/domain/repositories/media_repository.dart';
import 'package:muse_app/features/media/domain/usecases/load_media.dart';
import 'package:muse_app/features/media/presentation/bloc/media_bloc.dart';

const server = ServerConnection(baseUrl: 'https://one.test', apiKey: 'test');
const other = ServerConnection(baseUrl: 'https://two.test', apiKey: 'test');
const a = MediaItem(name: 'a.png', isVideo: false, bytes: 1);
const b = MediaItem(name: 'b.png', isVideo: false, bytes: 1);

class Repository implements MediaRepository {
  List<MediaItem> items = [a, b];
  int calls = 0;
  Completer<void>? pending;
  Object? failure;
  @override
  Future<List<MediaItem>> list(ServerConnection c) async =>
      c.baseUrl == other.baseUrl ? [b] : items;
  @override
  Future<void> deleteSingle(ServerConnection c, String name) async {
    calls++;
    await pending?.future;
    if (failure != null) throw failure!;
    items = [b];
  }

  @override
  Future<MediaDeleteResult> deleteBatch(
    ServerConnection c,
    List<String> names,
  ) async {
    await deleteSingle(c, names.first);
    return const MediaDeleteResult(removed: 1, errorCount: 1);
  }
}

Future<void> tick() => Future<void>.delayed(const Duration(milliseconds: 20));

class RefreshFailureRepository extends Repository {
  @override
  Future<List<MediaItem>> list(ServerConnection c) async {
    if (calls > 0) throw Exception('secret');
    return super.list(c);
  }
}

void main() {
  test(
    'failed reconciliation blocks another deletion until successful reload',
    () async {
      final repo = RefreshFailureRepository();
      final bloc = MediaBloc(LoadMedia(repo));
      addTearDown(bloc.close);
      bloc.add(CollectionLoaded(server));
      await tick();
      bloc.add(MediaDeleteRequested(server, ['a.png']));
      await tick();
      expect(bloc.state.notice, contains('1'));
      expect(bloc.state.error, contains('danh sách có thể đã cũ'));
      bloc.add(MediaDeleteRequested(server, ['b.png']));
      await tick();
      expect(repo.calls, 1);
      bloc.add(CollectionLoaded(server));
      await tick();
      bloc.add(MediaDeleteRequested(server, ['b.png']));
      await tick();
      expect(repo.calls, 1);
    },
  );
  test('batch reports partial failure without claiming every selection was removed', () async {
    final repo = Repository();
    final bloc = MediaBloc(LoadMedia(repo));
    addTearDown(bloc.close);
    bloc.add(CollectionLoaded(server));
    await tick();
    bloc.add(MediaDeleteRequested(server, ['a.png', 'b.png']));
    await tick();
    expect(bloc.state.notice, contains('1 tệp'));
    expect(bloc.state.error, contains('1'));
    expect(bloc.state.items, [b]);
  });
  test('duplicate deletion is guarded while pending', () async {
    final repo = Repository()..pending = Completer<void>();
    final bloc = MediaBloc(LoadMedia(repo));
    addTearDown(bloc.close);
    bloc.add(CollectionLoaded(server));
    await tick();
    bloc.add(MediaDeleteRequested(server, ['a.png']));
    await tick();
    bloc.add(MediaDeleteRequested(server, ['a.png']));
    await tick();
    expect(repo.calls, 1);
    repo.pending!.complete();
    await tick();
  });
  test('only names present in this server library can be deleted', () async {
    final repo = Repository();
    final bloc = MediaBloc(LoadMedia(repo));
    addTearDown(bloc.close);
    bloc.add(CollectionLoaded(server));
    await tick();
    bloc.add(MediaDeleteRequested(server, ['unknown.png']));
    await tick();
    bloc.add(MediaDeleteRequested(other, ['a.png']));
    await tick();
    expect(repo.calls, 0);
  });
  test('old deletion cannot overwrite a newly loaded server', () async {
    final repo = Repository()..pending = Completer<void>();
    final bloc = MediaBloc(LoadMedia(repo));
    addTearDown(bloc.close);
    bloc.add(CollectionLoaded(server));
    await tick();
    bloc.add(MediaDeleteRequested(server, ['a.png']));
    await tick();
    bloc.add(CollectionLoaded(other));
    await tick();
    repo.pending!.complete();
    await tick();
    expect(bloc.state.items, [b]);
    expect(bloc.state.notice, isNull);
  });
  test('deletion failure is sanitized and retains the library', () async {
    final repo = Repository()
      ..failure = Exception('Bearer secret /private/path');
    final bloc = MediaBloc(LoadMedia(repo));
    addTearDown(bloc.close);
    bloc.add(CollectionLoaded(server));
    await tick();
    bloc.add(MediaDeleteRequested(server, ['a.png']));
    await tick();
    expect(bloc.state.error, isNotNull);
    expect(bloc.state.error, isNot(contains('secret')));
    expect(bloc.state.items, [a, b]);
    expect(bloc.state.deleting, false);
  });
  test(
    'single deletion refreshes library and reports confirmed removal',
    () async {
      final repo = Repository();
      final bloc = MediaBloc(LoadMedia(repo));
      addTearDown(bloc.close);
      bloc.add(CollectionLoaded(server));
      await tick();
      bloc.add(MediaDeleteRequested(server, ['a.png']));
      await tick();
      expect(repo.calls, 1);
      expect(bloc.state.items.map((e) => e.name), ['b.png']);
      expect(bloc.state.notice, contains('1'));
      expect(bloc.state.deleting, false);
    },
  );
}
