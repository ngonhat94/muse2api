import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muse_app/features/text_prompt/data/text_prompt_repository_impl.dart';

void main() {
  test(
    'timeout and network failures are sanitized and close clients once',
    () async {
      for (final timeout in [false, true]) {
        final client = TrackingClient(timeout);
        final repository = TextPromptRepositoryImpl(
          () => client,
          timeout: const Duration(milliseconds: 5),
        );
        await expectLater(
          repository.enhance('dog'),
          throwsA(
            predicate(
              (e) =>
                  !e.toString().contains('SECRET') &&
                  e.toString().contains(timeout ? 'thời gian' : 'CORS'),
            ),
          ),
        );
        expect(client.calls, 1);
        expect(client.closed, isTrue);
      }
    },
  );
  test(
    'rejects HTTP errors and malformed prompts without leaking bodies',
    () async {
      for (final status in [401, 402, 403, 429, 451, 500]) {
        final repository = TextPromptRepositoryImpl(
          () => MockClient((_) async => http.Response('SECRET', status)),
        );
        await expectLater(
          repository.enhance('dog'),
          throwsA(
            predicate(
              (e) =>
                  e.toString().contains('HTTP $status') &&
                  !e.toString().contains('SECRET'),
            ),
          ),
        );
      }
      for (final body in [
        'SECRET',
        '{}',
        '[]',
        '{"prompt":42}',
        '{"prompt":"  "}',
      ]) {
        final repository = TextPromptRepositoryImpl(
          () => MockClient((_) async => http.Response(body, 200)),
        );
        await expectLater(
          repository.enhance('dog'),
          throwsA(
            predicate(
              (e) =>
                  !e.toString().contains('SECRET') &&
                  e.toString().contains('phản hồi'),
            ),
          ),
        );
      }
    },
  );

  test(
    'magic enhance sends only public JSON contract and reads prompt',
    () async {
      final repository = TextPromptRepositoryImpl(
        () => MockClient((request) async {
          expect(request.method, 'POST');
          expect(
            request.url.toString(),
            'https://imageprompt.org/api/ai/prompts/magic-enhance',
          );
          expect(
            request.headers.keys.map((e) => e.toLowerCase()),
            isNot(contains('cookie')),
          );
          expect(
            request.headers.keys.map((e) => e.toLowerCase()),
            isNot(contains('authorization')),
          );
          expect(jsonDecode(request.body), {
            'userPrompt': 'chú chó màu đen tai cụp dễ thương',
            'page': 'image-prompt-generator',
          });
          return http.Response(
            jsonEncode({
              'prompt': ' Một chú chó đen dễ thương ',
              'generatedAt': '2026-11-12T15:41:07.252Z',
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      expect(
        await repository.enhance('chú chó màu đen tai cụp dễ thương'),
        'Một chú chó đen dễ thương',
      );
    },
  );
}

class TrackingClient extends http.BaseClient {
  TrackingClient(this.wait);
  final bool wait;
  int calls = 0;
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    calls++;
    if (wait) return Completer<http.StreamedResponse>().future;
    throw http.ClientException('SECRET');
  }

  @override
  void close() {
    closed = true;
  }
}
