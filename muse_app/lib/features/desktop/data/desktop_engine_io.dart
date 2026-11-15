import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../../../core/errors/app_failure.dart';
import '../../connection/domain/entities/server_connection.dart';
import '../domain/repositories/desktop_engine.dart';
import '../domain/repositories/desktop_engine_failure.dart';
import '../domain/repositories/desktop_engine_installer.dart';
import 'desktop_engine_installer_io.dart';
import 'desktop_runtime_paths.dart';

DesktopEngine createDesktopEngine() => ProcessDesktopEngine();

/// The bundled helper owns its HTTP socket and browser. Credentials travel on
/// stdin, never in command-line arguments, persisted preferences or diagnostics.
class ProcessDesktopEngine implements DesktopEngine, DesktopEngineInstaller {
  ProcessDesktopEngine({
    this.executable,
    this.dataDirectory,
    http.Client Function()? clientFactory,
    Future<Process> Function(String)? launch,
  }) : _clientFactory = clientFactory ?? http.Client.new,
       _launch =
           launch ??
           ((executable) =>
               Process.start(executable, const [], runInShell: false));
  final String? executable;
  final String? dataDirectory;
  final http.Client Function() _clientFactory;
  final Future<Process> Function(String) _launch;
  final _exits = StreamController<void>.broadcast();
  Process? _process;
  ServerConnection? _connection;
  Future<ServerConnection>? _starting;
  int? _startingGeneration;
  Future<void>? _stopping;
  Completer<int>? _ready;
  int _generation = 0;
  late final _installer = ProcessDesktopInstaller(
    dataDirectory: () => _dataDirectory,
  );

  @override
  Future<void> install(void Function(DesktopInstallStage) onProgress) =>
      _installer.install(onProgress);
  @override
  Future<void> cancelInstall() => _installer.cancelInstall();

  @override
  bool get supported =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  @override
  Stream<void> get unexpectedExit => _exits.stream;

  String get _bundledExecutable {
    const override = String.fromEnvironment('MUSE_ENGINE_PATH');
    if (executable != null) return executable!;
    final installed = runtimeExecutable(
      installedRuntimeDirectory(_dataDirectory),
    );
    if (File(installed).existsSync()) return installed;
    if (override.isNotEmpty) return override;
    final parent = File(Platform.resolvedExecutable).parent;
    final root = Platform.isMacOS
        ? '${parent.parent.path}/Resources'
        : parent.path;
    return '$root/muse_engine/muse_engine${Platform.isWindows ? '.exe' : ''}';
  }

  String get _dataDirectory => dataDirectory ?? desktopDataDirectory();

  @override
  Future<ServerConnection> start() {
    if (_connection != null) return Future.value(_connection);
    if (_starting != null && _startingGeneration == _generation) {
      return _starting!;
    }
    final previous = _starting;
    final generation = _generation;
    final future = _startAfterPrevious(previous, generation);
    _starting = future;
    _startingGeneration = generation;
    return future.whenComplete(() {
      if (identical(_starting, future)) _starting = null;
    });
  }

  Future<ServerConnection> _startAfterPrevious(
    Future<ServerConnection>? previous,
    int generation,
  ) async {
    if (previous != null) {
      try {
        await previous;
      } catch (_) {
        /* A canceled start must release its child first. */
      }
    }
    return _start(generation);
  }

  Future<ServerConnection> _start(int generation) async {
    await _stopping;
    if (generation != _generation) throw const AppFailure('Đã hủy khởi động.');
    if (!supported || !File(_bundledExecutable).existsSync()) {
      throw const DesktopEngineFailure(DesktopEngineFailureCode.missingEngine);
    }
    final key = List.generate(
      32,
      (_) => Random.secure().nextInt(256),
    ).map((n) => n.toRadixString(16).padLeft(2, '0')).join();
    final ready = Completer<int>();
    // Attach an error handler before pipe writes/exit callbacks can complete it.
    unawaited(
      ready.future.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    );
    _ready = ready;
    StreamSubscription<String>? output;
    StreamSubscription<List<int>>? errors;
    Process? process;
    try {
      process = await _launch(_bundledExecutable);
      _process = process;
      if (generation != _generation) {
        throw const AppFailure('Đã hủy khởi động.');
      }
      final child = process;
      output = child.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              // Ignore all non-protocol output, never echo backend logs into the UI.
              try {
                final message = jsonDecode(line);
                if (message is Map &&
                    message['event'] == 'ready' &&
                    message['port'] is int) {
                  final port = message['port'] as int;
                  if (!ready.isCompleted && port > 0 && port <= 65535) {
                    ready.complete(port);
                  }
                } else if (message is Map &&
                    message['event'] == 'error' &&
                    !ready.isCompleted) {
                  ready.completeError(
                    DesktopEngineFailure.fromProtocol(message['code']),
                  );
                }
              } catch (_) {
                /* Backend text is intentionally discarded. */
              }
            },
            onError: (_) {
              if (!ready.isCompleted) {
                ready.completeError(
                  const AppFailure('Không đọc được trạng thái engine.'),
                );
              }
            },
            onDone: () {
              // Drain protocol output before classifying an early exit: the
              // process exit future may complete before its last stdout line.
              if (!ready.isCompleted) {
                ready.completeError(
                  const DesktopEngineFailure(
                    DesktopEngineFailureCode.startupFailed,
                  ),
                );
              }
            },
          );
      errors = child.stderr.listen((_) {});
      unawaited(
        child.exitCode.then((_) {
          if (identical(_process, child)) {
            final connected = _connection != null;
            _process = null;
            _connection = null;
            if (connected) _exits.add(null);
          }
        }),
      );
      child.stdin.writeln(
        jsonEncode({'api_key': key, 'data_dir': _dataDirectory}),
      );
      await child.stdin.flush();
      final port = await ready.future.timeout(const Duration(seconds: 30));
      final connection = ServerConnection(
        baseUrl: 'http://127.0.0.1:$port',
        apiKey: key,
        isLocal: true,
      );
      final client = _clientFactory();
      try {
        final response = await client
            .get(connection.endpoint('/v1/models'), headers: connection.headers)
            .timeout(const Duration(seconds: 15));
        final body = jsonDecode(response.body);
        if (response.statusCode != 200 ||
            body is! Map ||
            body['data'] is! List) {
          throw const AppFailure('Engine chưa sẵn sàng.');
        }
      } finally {
        client.close();
      }
      if (generation != _generation || !identical(_process, child)) {
        throw const AppFailure('Đã hủy khởi động.');
      }
      _connection = connection;
      return connection;
    } catch (error) {
      if (identical(_process, process) && process != null) {
        _process = null;
        _connection = null;
        await _stopProcess(process);
      }
      if (error is DesktopEngineFailure) rethrow;
      if (error is TimeoutException) {
        throw const DesktopEngineFailure(
          DesktopEngineFailureCode.startupTimeout,
        );
      }
      if (error is ProcessException && [1, 5, 13].contains(error.errorCode)) {
        throw const DesktopEngineFailure(DesktopEngineFailureCode.launchDenied);
      }
      throw const DesktopEngineFailure(DesktopEngineFailureCode.startupFailed);
    } finally {
      if (identical(_ready, ready)) _ready = null;
      // Keep draining pipes for the entire lifetime, then dispose listeners.
      if (process != null) {
        unawaited(
          process.exitCode.then((_) async {
            await output?.cancel();
            await errors?.cancel();
          }),
        );
      } else {
        await output?.cancel();
        await errors?.cancel();
      }
    }
  }

  @override
  Future<void> stop() {
    ++_generation;
    _connection = null;
    final process = _process;
    _process = null;
    if (process == null) return _stopping ?? Future.value();
    final stopped = _stopProcess(process);
    _stopping = stopped;
    return stopped.whenComplete(() {
      if (identical(_stopping, stopped)) _stopping = null;
    });
  }

  Future<void> _stopProcess(Process process) async {
    try {
      // EOF asks the helper to shut down its browser before exiting.
      await process.stdin.close();
      await process.exitCode.timeout(const Duration(seconds: 20));
    } catch (_) {
      process.kill();
      try {
        await process.exitCode.timeout(const Duration(seconds: 3));
      } catch (_) {
        process.kill(ProcessSignal.sigkill);
      }
    }
  }
}
