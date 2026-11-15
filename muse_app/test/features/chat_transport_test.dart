import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:muse_app/core/errors/app_failure.dart';
import 'package:muse_app/features/chat/data/datasources/chat_remote_data_source.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';

const connection = ServerConnection(
  baseUrl: 'https://example.com/muse',
  apiKey: 'secret',
);
void main() {
  test('Transport serializes authenticated multi-turn request and decodes fragmented UTF-8 SSE', () async {
    late http.Request sent;
    final source = ChatRemoteDataSource(
      () => MockClient.streaming((request, body) async {
        sent = request as http.Request;
        final bytes = utf8.encode(
          'data: {"choices":[{"delta":{"content":"Xin chào"}}]}\r\n\r\ndata: [DONE]\r\n\r\n',
        );
        return http.StreamedResponse(
          Stream.fromIterable(bytes.map((b) => [b])),
          200,
          headers: {'content-type': 'text/event-stream; charset=utf-8'},
        );
      }),
    );
    final result = await source.streamReply(connection, [
      {'role': 'user', 'content': 'Hello'},
    ]).toList();
    expect(result, ['Xin chào']);
    expect(sent.url.toString(), 'https://example.com/muse/v1/chat/completions');
    expect(sent.headers['Authorization'], 'Bearer secret');
    expect(jsonDecode(sent.body)['messages'][0]['content'], 'Hello');
    expect(jsonDecode(sent.body)['stream'], true);
  });

  for (final status in [401, 429, 502]) {
    test('HTTP $status becomes a sanitized application failure', () async {
      final source = ChatRemoteDataSource(
        () => MockClient((_) async => http.Response('secret', status)),
      );
      await expectLater(
        source.streamReply(connection, []).toList(),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.message,
            'message',
            isNot(contains('secret')),
          ),
        ),
      );
    });
  }
  for (final payload in [
    'data: {"error":{"message":"secret"}}\n\n',
    'data: {"choices":[{"delta":{"content":"partial"}}]}\n\n',
    'data: broken-json\n\n',
  ]) {
    test(
      'Does not report success for malformed, truncated or error SSE: $payload',
      () async {
        final source = ChatRemoteDataSource(
          () => MockClient.streaming(
            (_, _) async => http.StreamedResponse(
              Stream.value(utf8.encode(payload)),
              200,
              headers: {'content-type': 'text/event-stream'},
            ),
          ),
        );
        await expectLater(
          source.streamReply(connection, []).toList(),
          throwsA(isA<AppFailure>()),
        );
      },
    );
  }
  test('Cancelling response closes the active client', () async {
    final client = ClosingClient();
    final subscription = ChatRemoteDataSource(() => client)
        .streamReply(connection, [])
        .listen((_) {});
    await Future<void>.delayed(Duration.zero);
    await subscription.cancel();
    expect(client.closed, true);
    await client.body.close();
  });
}

class ClosingClient extends http.BaseClient {
  bool closed = false;
  final body = StreamController<List<int>>();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async =>
      http.StreamedResponse(
        body.stream,
        200,
        headers: {'content-type': 'text/event-stream'},
      );
  @override
  void close() {
    closed = true;
  }
}
