import 'package:muse_app/core/domain/reference_image.dart';

import 'dart:async';

import 'package:test/test.dart';
import 'package:muse_app/core/domain/generation_task.dart';
import 'package:muse_app/core/errors/app_failure.dart';
import 'package:muse_app/features/videos/domain/repositories/video_repository.dart';
import 'package:muse_app/features/videos/domain/usecases/generate_video.dart';
import 'package:muse_app/features/videos/presentation/bloc/video_bloc.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';

const connection = ServerConnection(
  baseUrl: 'https://example.com',
  apiKey: 'key',
);

class FakeVideos implements VideoRepository {
  final keys = <String?>[];
  int posts = 0;
  int polls = 0;
  bool failPost = false;
  bool failPoll = false;
  Completer<GenerationTask>? pending;
  @override
  Future<GenerationTask> create(
    ServerConnection c,
    String p,
    String r,
    int d, {
    String? requestKey,
    List<ReferenceImage> references = const [],
  }) async {
    keys.add(requestKey);
    posts++;
    if (failPost) throw const AppFailure('Offline');
    if (pending != null) return pending!.future;
    return const GenerationTask(
      id: 'v1',
      kind: 'video',
      status: GenerationStatus.queued,
    );
  }

  @override
  Future<GenerationTask> get(ServerConnection c, String id) async {
    polls++;
    if (failPoll) throw const AppFailure('Offline');
    return GenerationTask(
      id: id,
      kind: 'video',
      status: GenerationStatus.completed,
      filename: 'a.mp4',
    );
  }
}

Future<VideoState> waitFor(VideoBloc bloc, bool Function(VideoState) f) =>
    bloc.stream.firstWhere(f).timeout(const Duration(seconds: 2));
VideoBloc makeBloc(FakeVideos r) => VideoBloc(
  GenerateVideo(r),
  GetVideoTask(r),
  pollInterval: const Duration(milliseconds: 5),
);
void main() {
  test(
    'Video admission has an opaque key even when response is lost',
    () async {
      final r = FakeVideos()..failPost = true;
      final bloc = makeBloc(r);
      addTearDown(bloc.close);
      final failed = waitFor(bloc, (s) => s.admissionUncertain);
      bloc.add(VideoRequested(connection, 'Shiba', '16:9', 6));
      await failed;
      expect(r.keys, hasLength(1));
      expect(r.keys.single, matches(RegExp(r'^[0-9a-f]{48}$')));
    },
  );
  test(
    'Manual uncertain retry reuses key; clearing creates a new intent',
    () async {
      final r = FakeVideos()..failPost = true;
      final bloc = makeBloc(r);
      addTearDown(bloc.close);
      var failed = waitFor(bloc, (s) => s.admissionUncertain);
      bloc.add(VideoRequested(connection, 'Shiba', '16:9', 6));
      await failed;
      failed = waitFor(bloc, (s) => s.admissionUncertain);
      bloc.add(VideoAdmissionRetried());
      await failed;
      expect(r.keys, hasLength(2));
      expect(r.keys[1], r.keys[0]);
      final cleared = waitFor(bloc, (s) => !s.admissionUncertain);
      bloc.add(VideosCleared());
      await cleared;
      failed = waitFor(bloc, (s) => s.admissionUncertain);
      bloc.add(VideoRequested(connection, 'Shiba', '16:9', 6));
      await failed;
      expect(r.keys[2], isNot(r.keys[0]));
    },
  );
  test(
    'Video creation is submitted once and polled to a playable result',
    () async {
      final r = FakeVideos();
      final bloc = makeBloc(r);
      addTearDown(bloc.close);
      final done = waitFor(bloc, (s) => s.task?.terminal == true);
      bloc.add(VideoRequested(connection, 'Shiba', '16:9', 6));
      bloc.add(VideoRequested(connection, 'Duplicate', '16:9', 6));
      final result = await done;
      expect(result.task!.filename, 'a.mp4');
      expect(result.busy, false);
      expect(r.posts, 1);
      expect(r.polls, 1);
    },
  );
  test('Resuming server history only performs GET, never POST', () async {
    final r = FakeVideos();
    final bloc = makeBloc(r);
    addTearDown(bloc.close);
    final done = waitFor(bloc, (s) => s.task?.terminal == true);
    bloc.add(VideoResumed(connection, 'existing'));
    await done;
    expect(r.posts, 0);
    expect(r.polls, 1);
    expect(bloc.state.task!.id, 'existing');
  });
  test(
    'Lost POST response blocks another submission until user checks tasks',
    () async {
      final r = FakeVideos()..failPost = true;
      final bloc = makeBloc(r);
      addTearDown(bloc.close);
      final error = waitFor(bloc, (s) => s.admissionUncertain);
      bloc.add(VideoRequested(connection, 'Shiba', '16:9', 6));
      await error;
      bloc.add(VideoRequested(connection, 'Shiba', '16:9', 6));
      await Future<void>.delayed(Duration.zero);
      expect(r.posts, 1);
    },
  );
  test(
    'Polling failure retains task and retry only queries same task',
    () async {
      final r = FakeVideos()..failPoll = true;
      final bloc = makeBloc(r);
      addTearDown(bloc.close);
      final error = waitFor(bloc, (s) => s.error != null);
      bloc.add(VideoRequested(connection, 'Shiba', '16:9', 6));
      await error;
      r.failPoll = false;
      final done = waitFor(bloc, (s) => s.task?.terminal == true);
      bloc.add(VideoPollingRetried());
      await done;
      expect(r.posts, 1);
      expect(r.polls, 2);
    },
  );
  test('Reset ignores admission response from previous connection', () async {
    final r = FakeVideos()..pending = Completer<GenerationTask>();
    final bloc = makeBloc(r);
    addTearDown(bloc.close);
    final busy = waitFor(bloc, (s) => s.busy);
    bloc.add(VideoRequested(connection, 'Shiba', '16:9', 6));
    await busy;
    final cleared = waitFor(bloc, (s) => !s.busy);
    bloc.add(VideosCleared());
    await cleared;
    r.pending!.complete(
      const GenerationTask(
        id: 'old',
        kind: 'video',
        status: GenerationStatus.queued,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.task, isNull);
    expect(r.polls, 0);
  });
}
