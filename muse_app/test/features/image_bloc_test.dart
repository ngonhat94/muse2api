import 'package:muse_app/core/domain/reference_image.dart';

import 'dart:async';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:muse_app/core/errors/app_failure.dart';
import 'package:muse_app/features/images/domain/entities/image_task.dart';
import 'package:muse_app/features/images/domain/repositories/image_repository.dart';
import 'package:muse_app/features/images/domain/usecases/generate_image.dart';
import 'package:muse_app/features/images/presentation/bloc/image_bloc.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';

const connection = ServerConnection(
  baseUrl: 'https://example.com',
  apiKey: 'key',
);

class FakeImages implements ImageRepository {
  int posts = 0;
  int polls = 0;
  bool failPoll = false;
  bool failPost = false;
  final keys = <String>[];
  final intents = <(ServerConnection, String, String, List<ReferenceImage>)>[];
  Completer<ImageTask>? pending;
  @override
  Future<ImageTask> create(
    ServerConnection connection,
    String prompt,
    String ratio,
    String key, {
    List<ReferenceImage> references = const [],
  }) async {
    posts++;
    keys.add(key);
    intents.add((connection, prompt, ratio, references));
    if (failPost) {
      throw TimeoutException('Accepted by fixture server; response lost');
    }
    if (pending != null) return pending!.future;
    return const ImageTask(id: 'img1', status: ImageTaskStatus.queued);
  }

  @override
  Future<ImageTask> get(ServerConnection connection, String id) async {
    polls++;
    if (failPoll) throw const AppFailure('Network offline');
    return ImageTask(
      id: id,
      status: ImageTaskStatus.completed,
      bytes: Uint8List.fromList([1, 2, 3]),
    );
  }
}

Future<ImageState> waitFor(
  ImageBloc bloc,
  bool Function(ImageState) predicate,
) => bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 2));
void main() {
  test('Manual retry keeps captured data after attempted edits; switch isolates key', () async {
    final repository = FakeImages()..failPost = true;
    final bloc = ImageBloc(GenerateImage(repository), GetImageTask(repository));
    addTearDown(bloc.close);
    final refs = [
      ReferenceImage.fromBytes('first', Uint8List.fromList([255, 216, 255, 1])),
    ];
    var failed = waitFor(bloc, (s) => s.admissionUncertain);
    bloc.add(ImageRequested(connection, 'captured', '4:3', references: refs));
    await failed;
    refs.clear();
    bloc.add(ImageRequested(connection, 'edited', '9:16'));
    await Future<void>.delayed(Duration.zero);
    failed = waitFor(bloc, (s) => s.admissionUncertain);
    bloc.add(ImageAdmissionRetried());
    await failed;
    expect(repository.posts, 2);
    expect(repository.keys[1], repository.keys[0]);
    expect(repository.intents[1].$2, 'captured');
    expect(repository.intents[1].$3, '4:3');
    expect(repository.intents[1].$4.single.name, 'first');
    final cleared = waitFor(bloc, (s) => !s.admissionUncertain);
    bloc.add(ImagesCleared(connectionChanged: true));
    await cleared;
    bloc.add(ImageAdmissionRetried());
    await Future<void>.delayed(Duration.zero);
    expect(repository.posts, 2);
    const next = ServerConnection(
      baseUrl: 'https://other.example',
      apiKey: 'other-synthetic',
    );
    failed = waitFor(bloc, (s) => s.admissionUncertain);
    bloc.add(ImageRequested(next, 'new owner', '1:1'));
    await failed;
    expect(repository.keys.last, isNot(repository.keys.first));
    expect(repository.intents.last.$1, next);
  });
  test('Dispose ignores late admission and never retries or polls', () async {
    final repository = FakeImages()..pending = Completer<ImageTask>();
    final bloc = ImageBloc(GenerateImage(repository), GetImageTask(repository));
    final busy = waitFor(bloc, (s) => s.busy);
    bloc.add(ImageRequested(connection, 'captured', '1:1'));
    await busy;
    final closing = bloc.close();
    repository.pending!.complete(
      const ImageTask(id: 'late', status: ImageTaskStatus.queued),
    );
    await closing;
    expect(repository.posts, 1);
    expect(repository.polls, 0);
  });
  test(
    'Uncertain accepted POST blocks changed intent and ordinary clear',
    () async {
      final repository = FakeImages()..failPost = true;
      final bloc = ImageBloc(
        GenerateImage(repository),
        GetImageTask(repository),
      );
      addTearDown(bloc.close);
      final failed = waitFor(bloc, (s) => s.error != null);
      bloc.add(ImageRequested(connection, 'captured', '1:1'));
      await failed;
      for (final event in <ImageEvent>[
        ImageRequested(connection, 'changed', '1:1'),
        ImageRequested(connection, 'captured', '16:9'),
        ImageRequested(
          connection,
          'captured',
          '1:1',
          references: [
            ReferenceImage.fromBytes(
              'ref',
              Uint8List.fromList([255, 216, 255, 1]),
            ),
          ],
        ),
        ImagesCleared(),
        ImageRequested(connection, 'after clear', '1:1'),
      ]) {
        bloc.add(event);
        await Future<void>.delayed(Duration.zero);
        expect(repository.posts, 1);
        expect(bloc.state.error, isNotNull);
      }
    },
  );
  test(
    'One POST, sequential polling and image result; duplicate click is ignored',
    () async {
      final repository = FakeImages();
      final bloc = ImageBloc(
        GenerateImage(repository),
        GetImageTask(repository),
        pollInterval: const Duration(milliseconds: 5),
      );
      addTearDown(bloc.close);
      final done = waitFor(
        bloc,
        (s) => s.task?.status == ImageTaskStatus.completed,
      );
      bloc.add(ImageRequested(connection, 'Shiba', '1:1'));
      bloc.add(ImageRequested(connection, 'Shiba', '1:1'));
      final state = await done;
      expect(state.task!.bytes, [1, 2, 3]);
      expect(state.busy, false);
      expect(repository.posts, 1);
      expect(repository.polls, 1);
    },
  );
  test(
    'Lost polling response retries GET without creating a second task',
    () async {
      final repository = FakeImages()..failPoll = true;
      final bloc = ImageBloc(
        GenerateImage(repository),
        GetImageTask(repository),
        pollInterval: const Duration(milliseconds: 5),
      );
      addTearDown(bloc.close);
      final failed = waitFor(bloc, (s) => s.error != null);
      bloc.add(ImageRequested(connection, 'Shiba', '1:1'));
      expect((await failed).task!.id, 'img1');
      repository.failPoll = false;
      final completed = waitFor(
        bloc,
        (s) => s.task?.status == ImageTaskStatus.completed,
      );
      bloc.add(ImagePollingRetried());
      await completed;
      expect(repository.posts, 1);
      expect(repository.polls, 2);
    },
  );
  test(
    'Lost submission response reuses admission key on same-input retry',
    () async {
      final repository = FakeImages()..failPost = true;
      final bloc = ImageBloc(
        GenerateImage(repository),
        GetImageTask(repository),
        pollInterval: const Duration(milliseconds: 5),
      );
      addTearDown(bloc.close);
      final failed = waitFor(bloc, (s) => s.error != null);
      bloc.add(ImageRequested(connection, 'Shiba', '1:1'));
      await failed;
      repository.failPost = false;
      final done = waitFor(
        bloc,
        (s) => s.task?.status == ImageTaskStatus.completed,
      );
      bloc.add(ImageAdmissionRetried());
      await done;
      expect(repository.keys[0], repository.keys[1]);
    },
  );
  test('Disconnect clears image and ignores late task response', () async {
    final repository = FakeImages()..pending = Completer<ImageTask>();
    final bloc = ImageBloc(GenerateImage(repository), GetImageTask(repository));
    addTearDown(bloc.close);
    final busy = waitFor(bloc, (s) => s.busy);
    bloc.add(ImageRequested(connection, 'Shiba', '1:1'));
    await busy;
    final cleared = waitFor(bloc, (s) => !s.busy);
    bloc.add(ImagesCleared(connectionChanged: true));
    await cleared;
    repository.pending!.complete(
      const ImageTask(id: 'old', status: ImageTaskStatus.queued),
    );
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.task, isNull);
    expect(repository.polls, 0);
  });
}
