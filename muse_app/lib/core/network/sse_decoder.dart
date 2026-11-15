import 'dart:async';

/// Consumes decoded lines, not TCP chunks. Blank lines delimit SSE events.
/// A subscription-backed transformer propagates cancellation even while idle.
class SseDecoder extends StreamTransformerBase<String, String> {
  const SseDecoder();
  @override
  Stream<String> bind(Stream<String> stream) {
    var data = <String>[];
    late StreamSubscription<String> subscription;
    late StreamController<String> controller;
    void flush() {
      if (data.isNotEmpty) controller.add(data.join('\n'));
      data = [];
    }

    controller = StreamController<String>(
      sync: true,
      onListen: () {
        subscription = stream.listen(
          (line) {
            if (line.isEmpty) {
              flush();
            } else if (line.startsWith('data:')) {
              var value = line.substring(5);
              if (value.startsWith(' ')) value = value.substring(1);
              data.add(value);
            }
          },
          onError: controller.addError,
          onDone: () {
            flush();
            unawaited(controller.close());
          },
        );
      },
      onPause: () => subscription.pause(),
      onResume: () => subscription.resume(),
      onCancel: () => subscription.cancel(),
    );
    return controller.stream;
  }
}
