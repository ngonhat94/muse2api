import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:muse_app/features/text_prompt/domain/text_prompt_repository.dart';
import 'package:muse_app/features/text_prompt/presentation/text_prompt_cubit.dart';

class PendingPrompts implements TextPromptRepository {
  final requests = <String>[];
  final pending = <Completer<String>>[];
  @override
  Future<String> enhance(String text) {
    requests.add(text);
    final c = Completer<String>();
    pending.add(c);
    return c.future;
  }
}

void main() {
  test(
    'duplicate submit is ignored; edits and clear discard stale responses',
    () async {
      final repository = PendingPrompts();
      final cubit = TextPromptCubit(repository);
      cubit.edit('dog');
      final first = cubit.generate();
      final duplicate = cubit.generate();
      expect(repository.requests.length, 1);
      await duplicate;
      cubit.edit('cat');
      repository.pending[0].complete('stale');
      await first;
      expect(cubit.state.text, 'cat');
      expect(cubit.state.prompt, isNull);
      final second = cubit.generate();
      cubit.clear();
      repository.pending[1].complete('stale');
      await second;
      expect(cubit.state.text, '');
      expect(cubit.state.prompt, isNull);
      cubit.edit('dog');
      final third = cubit.generate();
      await cubit.close();
      repository.pending[2].complete('late');
      await third;
      cubit.edit('ignored');
      await cubit.generate();
      cubit.clear();
    },
  );
  test('unknown failures never expose exception details', () async {
    final repository = PendingPrompts();
    final cubit = TextPromptCubit(repository);
    cubit.edit('dog');
    final request = cubit.generate();
    repository.pending.single.completeError(Exception('SECRET'));
    await request;
    expect(cubit.state.sending, isFalse);
    expect(cubit.state.error, isNot(contains('SECRET')));
    expect(cubit.state.error, isNotNull);
    await cubit.close();
  });
  test(
    'only explicit submit sends; blank and client length limit reject locally',
    () async {
      final repository = PendingPrompts();
      final cubit = TextPromptCubit(repository);
      cubit.edit('  ');
      await cubit.generate();
      expect(cubit.state.error, isNotNull);
      expect(repository.requests, isEmpty);
      cubit.edit('a' * 4001);
      await cubit.generate();
      expect(cubit.state.error, isNotNull);
      expect(repository.requests, isEmpty);
      cubit.edit(' chó đen ');
      expect(repository.requests, isEmpty);
      final request = cubit.generate();
      expect(cubit.state.sending, isTrue);
      expect(repository.requests, [' chó đen ']);
      repository.pending.single.complete('prompt');
      await request;
      expect(cubit.state.prompt, 'prompt');
      await cubit.close();
    },
  );
}
