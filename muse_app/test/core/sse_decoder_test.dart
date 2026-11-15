import 'dart:convert';

import 'package:test/test.dart';
import 'package:muse_app/core/network/sse_decoder.dart';

void main() {
  test('SSE handles UTF-8 split across chunks, CRLF, comments and multiple data lines', () async {
    final bytes = utf8.encode(
      ': ping\r\ndata: Xin chào\r\ndata: Muse\r\n\r\ndata: [DONE]\r\n\r\n',
    );
    final stream = Stream.fromIterable(bytes.map((byte) => [byte]));
    final events = await stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .transform(const SseDecoder())
        .toList();
    expect(events, ['Xin chào\nMuse', '[DONE]']);
  });
}
