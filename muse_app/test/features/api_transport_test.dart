import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:muse_app/core/errors/app_failure.dart';
import 'package:muse_app/features/chat/data/datasources/chat_remote_data_source.dart';
import 'package:muse_app/features/connection/data/datasources/connection_remote_data_source.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';

void main() {
  late HttpServer server;
  late ServerConnection connection;
  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    connection = ServerConnection(
      baseUrl: 'http://127.0.0.1:${server.port}/muse',
      apiKey: 'test-key',
    );
  });
  tearDown(() => server.close(force: true));

  test('Real HTTP verifies key and streams fragmented chat payloads', () async {
    final paths = <String>[];
    server.listen((request) async {
      paths.add(request.uri.path);
      expect(request.headers.value('authorization'), 'Bearer test-key');
      if (request.uri.path.endsWith('/models')) {
        request.response.headers.contentType = ContentType.json;
        request.response.write('{"data":[{"id":"muse-spark"}]}');
      } else if (request.uri.path.endsWith('/me')) {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          '{"id":"usr_fixture","label":"Tenant A","role":"user",'
          '"capabilities":{"manage_users":false,"global_settings":false}}',
        );
      } else {
        final body = jsonDecode(await utf8.decoder.bind(request).join());
        expect(body['stream'], true);
        expect(body['messages'][0]['content'], 'Hello');
        request.response.headers.set('content-type', 'text/event-stream');
        for (final part in [
          'data: {"choices":[{"delta":',
          '{"content":"Xin chào"}}]}\n\n',
          'data: [DONE]\n\n',
        ]) {
          request.response.add(utf8.encode(part));
          await request.response.flush();
        }
      }
      await request.response.close();
    });
    await ConnectionRemoteDataSource(http.Client.new).verify(connection);
    expect(connection.principal?.id, 'usr_fixture');
    expect(connection.principal?.isAdmin, false);
    final chunks = await ChatRemoteDataSource(http.Client.new)
        .streamReply(connection, [
          {'role': 'user', 'content': 'Hello'},
        ])
        .toList();
    expect(chunks, ['Xin chào']);
    expect(paths, [
      '/muse/v1/models',
      '/muse/v1/me',
      '/muse/v1/chat/completions',
    ]);
  });

  test(
    '401 is reported without exposing upstream body or credentials',
    () async {
      server.listen((request) async {
        request.response.statusCode = 401;
        request.response.write('secret test-key');
        await request.response.close();
      });
      await expectLater(
        ConnectionRemoteDataSource(http.Client.new).verify(connection),
        throwsA(
          isA<AppFailure>().having(
            (error) => error.message,
            'message',
            isNot(contains('test-key')),
          ),
        ),
      );
    },
  );

  test('HTTP 429 exits streaming with an actionable failure', () async {
    server.listen((request) async {
      await request.drain<void>();
      request.response.statusCode = 429;
      await request.response.close();
    });
    await expectLater(
      ChatRemoteDataSource(http.Client.new)
          .streamReply(connection, [])
          .toList(),
      throwsA(
        isA<AppFailure>().having(
          (error) => error.message,
          'message',
          contains('giới hạn yêu cầu'),
        ),
      ),
    );
  });

  for (final payload in [
    'data: {"error":{"message":"private upstream error"}}\n\n',
    'data: {"choices":[{"delta":{"content":"partial"}}]}\n\n',
    'data: broken-json\n\n',
  ]) {
    test(
      'SSE errors, truncated and malformed streams fail instead of succeeding: $payload',
      () async {
        server.listen((request) async {
          await request.drain<void>();
          request.response.headers.set('content-type', 'text/event-stream');
          request.response.write(payload);
          await request.response.close();
        });
        await expectLater(
          ChatRemoteDataSource(http.Client.new)
              .streamReply(connection, [])
              .toList(),
          throwsA(isA<AppFailure>()),
        );
      },
    );
  }
}
