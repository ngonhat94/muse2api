import 'dart:async';

import 'package:muse_app/core/errors/app_failure.dart';
import 'package:muse_app/features/images/domain/entities/image_task.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';
import 'package:muse_app/features/videos/domain/usecases/generate_video.dart';
import 'package:muse_app/features/videos/presentation/bloc/video_bloc.dart';

import 'features/video_bloc_test.dart' show FakeVideos;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muse_app/core/storage/pending_generation_store.dart';
import 'package:muse_app/core/presentation/generation_recovery_cubit.dart';
import 'package:muse_app/features/images/domain/usecases/generate_image.dart';
import 'package:muse_app/features/images/presentation/bloc/image_bloc.dart';

import 'features/image_bloc_test.dart' show FakeImages, connection, waitFor;

class ControlledImages extends FakeImages {
  Completer<ImageTask>? read;
  Object? error;
  @override
  Future<ImageTask> get(ServerConnection c, String id) async {
    polls++;
    if (error != null) throw error!;
    if (read != null) return read!.future;
    return ImageTask(id: id, status: ImageTaskStatus.failed);
  }
}

void main() {
  test('manually resumed video is durable even while GET is offline', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = PendingGenerationStore(prefs);
    final repo = FakeVideos()..failPoll = true;
    final bloc = VideoBloc(
      GenerateVideo(repo),
      GetVideoTask(repo),
      pendingStore: store,
    );
    final offline = bloc.stream.firstWhere((s) => s.error != null);
    bloc.add(VideoResumed(connection, 'resume-v'));
    await offline;
    expect((await store.list(connection)).single.id, 'resume-v');
    expect(repo.posts, 0);
    await bloc.close();
  });
  test('mismatched returned ID retains saved task', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = PendingGenerationStore(prefs);
    await store.save(connection, 'image', 'expected');
    final repo = ControlledImages()..read = Completer<ImageTask>();
    final recovery = GenerationRecoveryCubit(store, GetImageTask(repo), null);
    final reading = recovery.connect(connection);
    await Future<void>.delayed(Duration.zero);
    repo.read!.complete(
      const ImageTask(id: 'WRONG', status: ImageTaskStatus.completed),
    );
    await reading;
    expect(recovery.state.single.status, 'unreachable');
    expect((await store.list(connection)).single.id, 'expected');
    await recovery.close();
  });
  test('storage failure keeps admitted ID in active image state instead of allowing duplicate POST', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = PendingGenerationStore(prefs);
    await store.save(connection, 'image', 'old');
    await prefs.setString(prefs.getKeys().single, '{malformed');
    final repo = FakeImages();
    final bloc = ImageBloc(
      GenerateImage(repo),
      GetImageTask(repo),
      pendingStore: store,
      pollInterval: const Duration(days: 1),
    );
    final error = waitFor(bloc, (s) => s.error != null);
    bloc.add(ImageRequested(connection, 'private', '1:1'));
    final result = await error;
    expect(result.task?.id, 'img1');
    bloc.add(ImageRequested(connection, 'private', '1:1'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(repo.posts, 1);
    await bloc.close();
  });
  test('video persists across close, recovery reconciles completed without another POST', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = PendingGenerationStore(prefs);
    final repo = FakeVideos();
    final bloc = VideoBloc(
      GenerateVideo(repo),
      GetVideoTask(repo),
      pendingStore: store,
      pollInterval: const Duration(days: 1),
    );
    final admitted = bloc.stream.firstWhere((s) => s.task != null);
    bloc.add(VideoRequested(connection, 'private', '16:9', 6));
    await admitted;
    expect((await store.list(connection)).single.id, 'v1');
    await bloc.close();
    final recovery = GenerationRecoveryCubit(
      PendingGenerationStore(prefs),
      GetImageTask(FakeImages()),
      GetVideoTask(repo),
    );
    await recovery.connect(connection);
    expect(recovery.state.single.video?.filename, 'a.mp4');
    expect(await store.list(connection), isEmpty);
    expect(repo.posts, 1);
    await recovery.close();
  });
  test('404 is unknown retained; confirmed failed removed; switch and dispose suppress stale reads', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = PendingGenerationStore(prefs);
    await store.save(connection, 'image', 'missing');
    final repo = ControlledImages()..error = const AppFailure('HTTP 404');
    final recovery = GenerationRecoveryCubit(store, GetImageTask(repo), null);
    await recovery.connect(connection);
    expect(recovery.state.single.status, 'unknown');
    await recovery.refresh();
    expect(recovery.state.single.status, 'unknown');
    expect((await store.list(connection)).single.id, 'missing');
    repo.error = null;
    await recovery.retry('image', 'missing');
    expect(recovery.state.single.status, 'failed');
    expect(await store.list(connection), isEmpty);
    await store.save(connection, 'image', 'late');
    repo.read = Completer<ImageTask>();
    final reading = recovery.connect(connection);
    await Future<void>.delayed(Duration.zero);
    await recovery.connect(
      const ServerConnection(baseUrl: 'https://other.example', apiKey: 'other'),
    );
    repo.read!.complete(
      const ImageTask(id: 'late', status: ImageTaskStatus.completed),
    );
    await reading;
    expect(recovery.state, isEmpty);
    await store.save(connection, 'image', 'dispose');
    repo.read = Completer<ImageTask>();
    final disposed = recovery.connect(connection);
    await Future<void>.delayed(Duration.zero);
    await recovery.close();
    repo.read!.complete(
      const ImageTask(id: 'dispose', status: ImageTaskStatus.queued),
    );
    await disposed;
    expect((await store.list(connection)).single.id, 'dispose');
  });
  test('admitted image persisted before polling, close/relaunch recovers by GET only, offline retained then terminal reconciled', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = PendingGenerationStore(prefs);
    final repo = FakeImages();
    final bloc = ImageBloc(
      GenerateImage(repo),
      GetImageTask(repo),
      pendingStore: store,
      pollInterval: const Duration(days: 1),
    );
    final admitted = waitFor(bloc, (s) => s.task != null);
    bloc.add(ImageRequested(connection, 'PRIVATE PROMPT', '1:1'));
    await admitted;
    expect((await store.list(connection)).single.id, 'img1');
    await bloc.close();
    repo.failPoll = true;
    final recovery = GenerationRecoveryCubit(
      PendingGenerationStore(prefs),
      GetImageTask(repo),
      null,
    );
    await recovery.connect(connection);
    expect(recovery.state.single.status, 'unreachable');
    expect((await store.list(connection)).single.id, 'img1');
    repo.failPoll = false;
    await recovery.retry('image', 'img1');
    expect(recovery.state.single.status, 'completed');
    expect(await store.list(connection), isEmpty);
    expect(repo.posts, 1);
    expect(repo.polls, 2);
    await recovery.close();
  });
}
