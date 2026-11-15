import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:muse_app/features/desktop/data/desktop_engine_io.dart';
import 'package:muse_app/features/desktop/domain/repositories/desktop_engine_failure.dart';

/// Pipe-level simulation: no sockets, browser or real Muse requests.
class ChildProcess implements Process {
  ChildProcess({this.handshake = true}) {
    stdin = IOSink(input.sink);
    input.stream.listen((bytes) {
      received += utf8.decode(bytes);
      if (received.contains('\n') && handshake && !announced) {
        announced = true;
        output.add(utf8.encode('{"event":"ready","port":32100}\n'));
      }
    }, onDone: finish);
  }
  final bool handshake;
  bool announced = false;
  String received = '';
  final input = StreamController<List<int>>();
  final output = StreamController<List<int>>();
  final errors = StreamController<List<int>>();
  final exited = Completer<int>();
  void finish() {
    if (!exited.isCompleted) {
      exited.complete(0);
      unawaited(output.close());
      unawaited(errors.close());
    }
  }

  @override
  late final IOSink stdin;
  @override
  Stream<List<int>> get stdout => output.stream;
  @override
  Stream<List<int>> get stderr => errors.stream;
  @override
  Future<int> get exitCode => exited.future;
  @override
  int get pid => 123;
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    finish();
    return true;
  }
}

Future<void> tick() async {
  for (var i = 0; i < 6; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('Bootstrap key stays on stdin; owned loopback endpoint is verified and stopped by EOF', () async {
    final child = ChildProcess();
    var launches = 0;
    http.Request? request;
    final engine = ProcessDesktopEngine(
      executable: Platform.resolvedExecutable,
      dataDirectory: '/tmp/fixture-engine',
      launch: (executable) async {
        launches++;
        expect(executable, Platform.resolvedExecutable);
        return child;
      },
      clientFactory: () => MockClient((r) async {
        request = r;
        return http.Response('{"data":[]}', 200);
      }),
    );
    final results = await Future.wait([engine.start(), engine.start()]);
    expect(launches, 1);
    expect(identical(results[0], results[1]), true);
    final connection = results.first;
    expect(connection.isLocal, true);
    expect(connection.baseUrl, 'http://127.0.0.1:32100');
    final bootstrap = jsonDecode(child.received) as Map;
    expect(bootstrap['api_key'], connection.apiKey);
    expect(connection.apiKey.length, 64);
    expect(bootstrap['data_dir'], '/tmp/fixture-engine');
    expect(request!.headers['Authorization'], 'Bearer ${connection.apiKey}');
    expect(request!.url.path, '/v1/models');
    expect(connection.toString(), isNot(contains(connection.apiKey)));
    await engine.stop();
    expect(child.exited.isCompleted, true);
  });
  test(
    'Wrong service response never becomes a connection and receives no retries',
    () async {
      final child = ChildProcess();
      var requests = 0;
      final engine = ProcessDesktopEngine(
        executable: Platform.resolvedExecutable,
        launch: (_) async => child,
        clientFactory: () => MockClient((_) async {
          requests++;
          return http.Response('sensitive-fixture', 401);
        }),
      );
      await expectLater(
        engine.start(),
        throwsA(predicate((e) => !e.toString().contains('sensitive-fixture'))),
      );
      expect(requests, 1);
      expect(child.exited.isCompleted, true);
    },
  );
  test(
    'Unexpected child exit is published; intentional stop is silent',
    () async {
      final children = [ChildProcess(), ChildProcess()];
      var index = 0;
      var exits = 0;
      final engine = ProcessDesktopEngine(
        executable: Platform.resolvedExecutable,
        launch: (_) async => children[index++],
        clientFactory: () =>
            MockClient((_) async => http.Response('{"data":[]}', 200)),
      );
      final subscription = engine.unexpectedExit.listen((_) {
        exits++;
      });
      addTearDown(subscription.cancel);
      await engine.start();
      children.first.finish();
      await tick();
      expect(exits, 1);
      await engine.start();
      await engine.stop();
      await tick();
      expect(exits, 1);
    },
  );
  test(
    'Cancel while process spawn is pending disposes the late child',
    () async {
      final pending = Completer<Process>();
      final child = ChildProcess(handshake: false);
      final engine = ProcessDesktopEngine(
        executable: Platform.resolvedExecutable,
        launch: (_) => pending.future,
      );
      final start = expectLater(engine.start(), throwsA(anything));
      await tick();
      await engine.stop();
      pending.complete(child);
      await start;
      expect(child.exited.isCompleted, true);
    },
  );
  test('Immediate restart after cancel waits for old spawn then starts a fresh child', () async {
    final pending = Completer<Process>();
    final canceled = ChildProcess(handshake: false);
    final fresh = ChildProcess();
    var launches = 0;
    final engine = ProcessDesktopEngine(
      executable: Platform.resolvedExecutable,
      launch: (_) {
        launches++;
        return launches == 1 ? pending.future : Future.value(fresh);
      },
      clientFactory: () =>
          MockClient((_) async => http.Response('{"data":[]}', 200)),
    );
    final first = expectLater(engine.start(), throwsA(anything));
    await tick();
    await engine.stop();
    final second = engine.start();
    pending.complete(canceled);
    await first;
    final connection = await second;
    expect(canceled.exited.isCompleted, true);
    expect(launches, 2);
    expect(connection.isLocal, true);
    await engine.stop();
  });
  test(
    'Early process exit preserves the final fixed protocol diagnosis',
    () async {
      final child = ChildProcess(handshake: false);
      final engine = ProcessDesktopEngine(
        executable: Platform.resolvedExecutable,
        launch: (_) async => child,
      );
      final result = expectLater(
        engine.start(),
        throwsA(
          isA<DesktopEngineFailure>().having(
            (e) => e.code,
            'code',
            DesktopEngineFailureCode.missingBrowser,
          ),
        ),
      );
      await tick();
      // Deliberately complete exit before delivering its final buffered output.
      child.exited.complete(1);
      child.output.add(
        utf8.encode(
          '{"event":"error","code":"browser_missing","detail":"sensitive-fixture"}\n',
        ),
      );
      await child.output.close();
      await child.errors.close();
      await result;
      await child.stdin.close();
    },
  );
}
