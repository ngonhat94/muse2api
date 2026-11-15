import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:muse_app/core/domain/reference_image.dart';
import 'package:muse_app/core/domain/pick_reference_images.dart';
import 'package:muse_app/core/presentation/reference_cubit.dart';
import 'package:muse_app/core/errors/app_failure.dart';
import 'package:muse_app/core/network/json_api_client.dart';
import 'package:muse_app/features/images/data/datasources/image_remote_data_source.dart';
import 'package:muse_app/features/images/domain/entities/image_task.dart';
import 'package:muse_app/features/images/domain/repositories/image_repository.dart';
import 'package:muse_app/features/images/domain/usecases/generate_image.dart';
import 'package:muse_app/features/images/presentation/bloc/image_bloc.dart';
import 'package:muse_app/features/videos/data/repositories/video_repository_impl.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';

ReferenceImage png(String name, int marker) => ReferenceImage.fromBytes(
  name,
  Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, marker]),
);
const connection = ServerConnection(
  baseUrl: 'https://example.com/muse',
  apiKey: 'fixture',
);

class FakeFiles implements ReferenceFileSource {
  List<ReferenceImage> files = [];
  bool fail = false;
  int? remaining;
  @override
  Future<List<ReferenceImage>> select({
    required int remainingFiles,
    required int remainingBytes,
  }) async {
    remaining = remainingFiles;
    if (fail) throw const AppFailure('Unreadable file');
    return files;
  }
}

class RejectedImageRepository implements ImageRepository {
  final keys = <String>[];
  final payloads = <List<ReferenceImage>>[];
  @override
  Future<ImageTask> create(
    ServerConnection c,
    String p,
    String r,
    String key, {
    List<ReferenceImage> references = const [],
  }) async {
    keys.add(key);
    payloads.add(references);
    throw const AppFailure('Lost POST response');
  }

  @override
  Future<ImageTask> get(ServerConnection c, String id) =>
      throw UnimplementedError();
}

void main() {
  test('Sniffs content instead of trusting filename, and bytes are immutable snapshots', () {
    final bytes = Uint8List.fromList([255, 216, 255, 1]);
    final ref = ReferenceImage.fromBytes('fake.png', bytes);
    expect(ref.mime, 'image/jpeg');
    bytes[0] = 0;
    expect(ref.bytes[0], 255);
    expect(() => ref.bytes[0] = 0, throwsUnsupportedError);
    expect(
      () =>
          ReferenceImage.fromBytes('image.png', Uint8List.fromList([1, 2, 3])),
      throwsA(isA<AppFailure>()),
    );
  });
  test('Enforces count, individual size and aggregate limits', () {
    final small = png('a.png', 1);
    expect(
      () => ReferenceImage.validate(List.filled(11, small)),
      throwsA(isA<AppFailure>()),
    );
    expect(
      () => ReferenceImage.fromBytes(
        'huge.png',
        Uint8List(ReferenceImage.maxFileBytes + 1),
      ),
      throwsA(isA<AppFailure>()),
    );
    final bytes = Uint8List(34 * 1024 * 1024)
      ..setRange(0, 8, [137, 80, 78, 71, 13, 10, 26, 10]);
    final large = ReferenceImage.fromBytes('large.png', bytes);
    expect(
      () => ReferenceImage.validate([large, large, large]),
      throwsA(isA<AppFailure>()),
    );
  });
  test('Picker retains current images on cancellation or failure; move/remove preserves order', () async {
    final files = FakeFiles()..files = [png('one', 1), png('two', 2)];
    final cubit = ReferenceCubit(PickReferenceImages(files));
    addTearDown(cubit.close);
    await cubit.pick();
    cubit.move(1, 0);
    expect(cubit.state.images.map((e) => e.name), ['two', 'one']);
    files.files = [];
    await cubit.pick();
    expect(cubit.state.images.length, 2);
    files.fail = true;
    await cubit.pick();
    expect(cubit.state.images.length, 2);
    expect(cubit.state.error, isNotNull);
    cubit.remove(0);
    expect(cubit.state.images.single.name, 'one');
    expect(files.remaining, 8);
  });
  test(
    'Image edit and video reference payloads preserve MIME and selection order',
    () async {
      final refs = [png('first', 1), png('second', 2)];
      final bodies = <Map<String, dynamic>>[];
      http.Client factory() => MockClient((request) async {
        bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response('{"id":"task1","status":"queued"}', 202);
      });
      await ImageRemoteDataSource(factory)
          .create(connection, 'edit', '1:1', 'stable', references: refs);
      await VideoRepositoryImpl(JsonApiClient(factory))
          .create(connection, 'move', '16:9', 6, references: refs);
      for (final body in bodies) {
        final images = body['images'] as List;
        expect(images.length, 2);
        expect(images.first, startsWith('data:image/png;base64,'));
        expect(
          base64Decode((images.first as String).split(',').last),
          refs.first.bytes,
        );
        expect(
          base64Decode((images.last as String).split(',').last),
          refs.last.bytes,
        );
      }
    },
  );
  test(
    'Reference changes require informed discard; manual retry preserves order',
    () async {
      final repository = RejectedImageRepository();
      final bloc = ImageBloc(
        GenerateImage(repository),
        GetImageTask(repository),
      );
      addTearDown(bloc.close);
      final refs = [png('first', 1), png('second', 2)];
      Future<void> submit(List<ReferenceImage> images) async {
        final failed = bloc.stream
            .firstWhere((s) => s.error != null)
            .timeout(const Duration(seconds: 2));
        bloc.add(ImageRequested(connection, 'edit', '1:1', references: images));
        await failed;
      }

      await submit(refs);
      final retry = bloc.stream.firstWhere((s) => s.admissionUncertain);
      bloc.add(ImageAdmissionRetried());
      await retry;
      bloc.add(
        ImageRequested(
          connection,
          'edit',
          '1:1',
          references: refs.reversed.toList(),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(repository.keys, hasLength(2));
      expect(repository.payloads.last.first.name, 'first');
      final cleared = bloc.stream.firstWhere((s) => !s.admissionUncertain);
      bloc.add(ImagesCleared(discardUncertain: true));
      await cleared;
      await submit(refs.reversed.toList());
      expect(repository.keys[0], repository.keys[1]);
      expect(repository.keys[2], isNot(repository.keys[1]));
      expect(repository.payloads.last.first.name, 'second');
    },
  );
}
