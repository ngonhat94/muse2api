import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/errors/app_failure.dart';
import '../../../../core/network/api_error.dart';
import '../../../../core/network/sse_decoder.dart';
import '../../../connection/domain/entities/server_connection.dart';

class ChatRemoteDataSource {
  const ChatRemoteDataSource(this.clientFactory);
  final http.Client Function() clientFactory;

  Stream<String> streamReply(
    ServerConnection connection,
    List<Map<String, String>> messages,
  ) {
    final client = clientFactory();
    StreamSubscription<String>? subscription;
    var cancelled = false;
    var finished = false;
    late StreamController<String> controller;
    void fail(Object error) {
      if (cancelled || controller.isClosed) return;
      controller.addError(
        error is AppFailure
            ? error
            : const AppFailure(
                'Kết nối bị gián đoạn. Bạn có thể gửi lại tin nhắn.',
              ),
      );
      unawaited(controller.close());
      client.close();
    }

    Future<void> start() async {
      try {
        final request =
            http.Request('POST', connection.endpoint('/v1/chat/completions'))
              ..headers.addAll({
                ...connection.headers,
                'Content-Type': 'application/json',
                'Accept': 'text/event-stream',
              })
              ..body = jsonEncode({
                'model': 'muse-spark',
                'stream': true,
                'messages': messages,
              });
        final response = await client
            .send(request)
            .timeout(const Duration(seconds: 20));
        if (cancelled) return;
        if (response.statusCode != 200) {
          // Bound error reads, never expose raw response text in the UI.
          fail(apiError(response.statusCode, ''));
          return;
        }
        if (!(response.headers['content-type'] ?? '').contains(
          'text/event-stream',
        )) {
          fail(const AppFailure('Server không trả về luồng SSE hợp lệ.'));
          return;
        }
        subscription = response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .transform(const SseDecoder())
            .timeout(const Duration(seconds: 60))
            .listen(
              (event) {
                if (cancelled || controller.isClosed || finished) return;
                try {
                  if (event.trim() == '[DONE]') {
                    finished = true;
                    unawaited(controller.close());
                    client.close();
                    unawaited(subscription?.cancel());
                    return;
                  }
                  final json = jsonDecode(event) as Map<String, dynamic>;
                  if (json['error'] != null) {
                    fail(
                      const AppFailure(
                        'Muse không hoàn tất phản hồi. Kiểm tra tài khoản và quota trên server.',
                      ),
                    );
                    return;
                  }
                  final choices = json['choices'] as List?;
                  if (choices == null || choices.isEmpty) return;
                  final content = choices.first['delta']?['content'];
                  if (content is String && content.isNotEmpty) {
                    controller.add(content);
                  }
                } catch (_) {
                  fail(
                    const AppFailure(
                      'Dữ liệu streaming từ server không hợp lệ.',
                    ),
                  );
                }
              },
              onError: fail,
              onDone: () {
                if (!finished && !cancelled) {
                  fail(
                    const AppFailure(
                      'Luồng phản hồi kết thúc sớm. Nội dung có thể chưa đầy đủ.',
                    ),
                  );
                }
                client.close();
              },
            );
      } catch (error) {
        fail(error);
      }
    }

    controller = StreamController<String>(
      onListen: () => unawaited(start()),
      onCancel: () async {
        cancelled = true;
        client.close();
        await subscription?.cancel();
      },
    );
    return controller.stream;
  }
}
