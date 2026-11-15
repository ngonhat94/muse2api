import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:muse_app/core/domain/reference_image.dart';
import 'package:muse_app/features/image_prompt/domain/image_prompt_repository.dart';
import 'package:muse_app/features/image_prompt/presentation/image_prompt_cubit.dart';

import 'prompt_image_loader_test.dart' show png;

class PendingPromptRepository implements ImagePromptRepository {
  final requests = <Completer<String>>[];
  @override
  Future<String> generate(ReferenceImage image) {
    final request = Completer<String>();
    requests.add(request);
    return request.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('clear invalidates in-flight success and prevents empty send', () async {
    final repository = PendingPromptRepository();
    final cubit = ImagePromptCubit(repository);
    await cubit.generate();
    expect(repository.requests, isEmpty);
    await cubit.select('peach.png', png);
    final sending = cubit.generate();
    cubit.clear();
    repository.requests.single.complete('stale');
    await sending;
    expect(cubit.state.image, isNull);
    expect(cubit.state.prompt, isNull);
    await cubit.close();
  });
  test('replacement ignores old failure and duplicate send', () async {
    final repository = PendingPromptRepository();
    final cubit = ImagePromptCubit(repository);
    await cubit.select('first.png', png);
    final sending = cubit.generate();
    await cubit.generate();
    expect(repository.requests, hasLength(1));
    await cubit.select('second.png', png);
    repository.requests.single.completeError(Exception('stale error'));
    await sending;
    expect(cubit.state.image?.name, 'second.png');
    expect(cubit.state.error, isNull);
    await cubit.close();
  });
  test('invalid replacement clears old result without upload', () async {
    final repository = PendingPromptRepository();
    final cubit = ImagePromptCubit(repository);
    await cubit.select('first.png', png);
    await cubit.select('invalid.png', png.sublist(0, 8));
    expect(cubit.state.image, isNull);
    expect(cubit.state.error, isNotEmpty);
    expect(repository.requests, isEmpty);
    await cubit.close();
  });
  test('disposed cubit ignores pending result', () async {
    final repository = PendingPromptRepository();
    final cubit = ImagePromptCubit(repository);
    await cubit.select('first.png', png);
    final sending = cubit.generate();
    await cubit.close();
    repository.requests.single.complete('stale');
    await sending;
  });
  test('current failure becomes recoverable safe error', () async {
    final repository = PendingPromptRepository();
    final cubit = ImagePromptCubit(repository);
    await cubit.select('first.png', png);
    final sending = cubit.generate();
    repository.requests.single.completeError(Exception('sensitive'));
    await sending;
    expect(cubit.state.sending, isFalse);
    expect(cubit.state.error, isNot(contains('sensitive')));
    expect(cubit.state.image, isNotNull);
    await cubit.close();
  });
  test('selection stays local; explicit send produces a prompt', () async {
    final repository = PendingPromptRepository();
    final cubit = ImagePromptCubit(repository);
    await cubit.select('peach.png', png);
    expect(cubit.state.image?.mime, 'image/png');
    expect(repository.requests, isEmpty);
    final sending = cubit.generate();
    expect(cubit.state.sending, isTrue);
    repository.requests.single.complete('A peach square');
    await sending;
    expect(cubit.state.prompt, 'A peach square');
    expect(cubit.state.sending, isFalse);
    await cubit.close();
  });
}
