import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muse_app/core/domain/reference_image.dart';
import 'package:muse_app/features/image_prompt/data/image_prompt_repository_impl.dart';

class ClosingClient extends http.BaseClient {
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      Completer<http.StreamedResponse>().future;
  @override
  void close() {
    closed = true;
  }
}

void main() {
  final image = ReferenceImage.fromBytes(
    'test.png',
    Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
  );
  for (final status in [401, 402, 403, 429, 451, 500]) {
    test(
      'HTTP $status is an honest failure without retry or body disclosure',
      () async {
        var calls = 0;
        final repository = ImagePromptRepositoryImpl(
          () => MockClient((request) async {
            calls++;
            return http.Response(
              '{"prompt":"must not accept","secret":"private"}',
              status,
            );
          }),
        );
        await expectLater(
          repository.generate(image),
          throwsA(
            predicate(
              (e) =>
                  e.toString().contains('$status') &&
                  !e.toString().contains('private'),
            ),
          ),
        );
        expect(calls, 1);
      },
    );
  }
  for (final body in [
    '<html>blocked</html>',
    '[]',
    '{"prompt":4}',
    '{"prompt":" "}',
    '{}',
  ]) {
    test('rejects malformed successful response $body', () async {
      final repository = ImagePromptRepositoryImpl(
        () => MockClient((_) async => http.Response(body, 200)),
      );
      await expectLater(
        repository.generate(image),
        throwsA(predicate((e) => e.toString().contains('phản hồi'))),
      );
    });
  }
  test(
    'network failure explains web CORS without exposing raw transport details',
    () async {
      final repository = ImagePromptRepositoryImpl(
        () => MockClient(
          (_) async => throw http.ClientException('sensitive transport'),
        ),
      );
      await expectLater(
        repository.generate(image),
        throwsA(
          predicate(
            (e) =>
                e.toString().contains('CORS') &&
                !e.toString().contains('sensitive'),
          ),
        ),
      );
    },
  );
  test('timeout is bounded and closes the owned client', () async {
    final client = ClosingClient();
    final repository = ImagePromptRepositoryImpl(
      () => client,
      timeout: const Duration(milliseconds: 1),
    );
    await expectLater(
      repository.generate(image),
      throwsA(predicate((e) => e.toString().contains('hết thời gian'))),
    );
    expect(client.closed, isTrue);
  });

  test(
    'sends only imageprompt JSON with detected MIME and returns prompt',
    () async {
      var calls = 0;
      final repository = ImagePromptRepositoryImpl(
        () => MockClient((request) async {
          calls++;
          expect(
            request.url.toString(),
            'https://imageprompt.org/api/ai/prompts/image',
          );
          expect(request.method, 'POST');
          expect(request.headers['content-type'], 'application/json');
          expect(request.headers.keys, isNot(contains('authorization')));
          expect(request.headers.keys, isNot(contains('cookie')));
          expect(jsonDecode(request.body), {
            'base64Url': 'data:image/png;base64,iVBORw0KGgo=',
            'imageModelId': 0,
            'language': 'en',
          });
          return http.Response(
            '{"prompt":"A peach square","generatedAt":"ignored"}',
            200,
          );
        }),
      );
      expect(
        await repository.generate(
          ReferenceImage.fromBytes(
            'wrong.jpg',
            Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
          ),
        ),
        'A peach square',
      );
      expect(calls, 1);
    },
  );
}
