import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/repositories/desktop_engine_failure.dart';
import '../domain/repositories/desktop_engine_installer.dart';
import 'desktop_runtime_paths.dart';

class ProcessDesktopInstaller implements DesktopEngineInstaller {
  ProcessDesktopInstaller({required this.dataDirectory, this.sourceRoot});
  final String Function() dataDirectory;
  final String? sourceRoot;
  Process? _process;
  Future<void>? _installing;
  int _generation = 0;

  String _setupRoot() {
    const configured = String.fromEnvironment('MUSE_SOURCE_ROOT');
    final roots = <Directory>[
      if (sourceRoot != null) Directory(sourceRoot!),
      if (configured.isNotEmpty) Directory(configured),
      Directory('${desktopResourceDirectory()}/desktop_setup'),
    ];
    var candidate = Directory.current;
    for (var i = 0; i < 5; i++) {
      roots.add(candidate);
      if (candidate.parent.path == candidate.path) break;
      candidate = candidate.parent;
    }
    candidate = File(Platform.resolvedExecutable).parent;
    for (var i = 0; i < 12; i++) {
      roots.add(candidate);
      if (candidate.parent.path == candidate.path) break;
      candidate = candidate.parent;
    }
    for (final root in roots) {
      if (File('${root.path}/desktop/install.py').existsSync() &&
          File('${root.path}/tools/build_desktop.py').existsSync()) {
        return root.path;
      }
    }
    throw const DesktopEngineFailure(DesktopEngineFailureCode.setupMissing);
  }

  Future<String> _python() async {
    final candidates = [
      if (Platform.isWindows) 'python',
      if (!Platform.isWindows) 'python3',
      if (Platform.isMacOS) ...[
        '/opt/homebrew/bin/python3',
        '/usr/local/bin/python3',
        '/Library/Frameworks/Python.framework/Versions/Current/bin/python3',
      ],
    ];
    for (final executable in candidates) {
      try {
        final result = await Process.run(executable, [
          '-c',
          'import sys;sys.exit(0 if sys.version_info >= (3,11) else 1)',
        ]).timeout(const Duration(seconds: 8));
        if (result.exitCode == 0) return executable;
      } catch (_) {
        /* Try the next standard Python installation. */
      }
    }
    throw const DesktopEngineFailure(DesktopEngineFailureCode.pythonMissing);
  }

  @override
  Future<void> install(void Function(DesktopInstallStage) onProgress) {
    if (_installing != null) {
      return Future.error(
        const DesktopEngineFailure(DesktopEngineFailureCode.installBusy),
      );
    }
    final generation = ++_generation;
    final future = _install(generation, onProgress);
    _installing = future;
    return future.whenComplete(() {
      if (identical(_installing, future)) _installing = null;
    });
  }

  Future<void> _install(
    int generation,
    void Function(DesktopInstallStage) onProgress,
  ) async {
    StreamSubscription<String>? output;
    StreamSubscription<List<int>>? errors;
    try {
      final root = _setupRoot();
      final python = await _python();
      if (generation != _generation) {
        throw const DesktopEngineFailure(
          DesktopEngineFailureCode.installCancelled,
        );
      }
      final destination = installedRuntimeDirectory(dataDirectory());
      final child = await Process.start(python, [
        '$root/desktop/install.py',
        '--destination',
        destination,
      ], runInShell: false);
      _process = child;
      final drained = Completer<void>();
      DesktopEngineFailure? failure;
      var complete = false;
      output = child.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              try {
                final value = jsonDecode(line);
                if (value is! Map) return;
                if (value['event'] == 'progress') {
                  final stage = switch (value['stage']) {
                    'preparing' => DesktopInstallStage.preparing,
                    'dependencies' => DesktopInstallStage.dependencies,
                    'browser' => DesktopInstallStage.browser,
                    'packaging' => DesktopInstallStage.packaging,
                    'verifying' => DesktopInstallStage.verifying,
                    _ => null,
                  };
                  if (stage != null && generation == _generation) {
                    onProgress(stage);
                  }
                } else if (value['event'] == 'error') {
                  failure = DesktopEngineFailure.fromInstallProtocol(
                    value['code'],
                  );
                } else if (value['event'] == 'complete') {
                  complete = true;
                }
              } catch (_) {
                /* Only fixed protocol fields may reach the interface. */
              }
            },
            onError: (_) {
              if (!drained.isCompleted) drained.complete();
            },
            onDone: () {
              if (!drained.isCompleted) drained.complete();
            },
          );
      errors = child.stderr.listen((_) {});
      if (generation != _generation) {
        await _stopChild();
        throw const DesktopEngineFailure(
          DesktopEngineFailureCode.installCancelled,
        );
      }
      final exit = await child.exitCode.timeout(const Duration(minutes: 45));
      await drained.future.timeout(const Duration(seconds: 5));
      if (generation != _generation) {
        throw const DesktopEngineFailure(
          DesktopEngineFailureCode.installCancelled,
        );
      }
      if (failure != null) throw failure!;
      if (exit != 0 ||
          !complete ||
          !File(runtimeExecutable(destination)).existsSync()) {
        throw const DesktopEngineFailure(
          DesktopEngineFailureCode.installFailed,
        );
      }
    } catch (error) {
      if (error is DesktopEngineFailure) rethrow;
      await _stopChild();
      throw const DesktopEngineFailure(DesktopEngineFailureCode.installFailed);
    } finally {
      final child = _process;
      _process = null;
      try {
        await child?.stdin.close();
      } catch (_) {
        /* The helper may already have exited. */
      }
      await output?.cancel();
      await errors?.cancel();
    }
  }

  @override
  Future<void> cancelInstall() async {
    ++_generation;
    await _stopChild();
    try {
      await _installing;
    } catch (_) {
      /* Cancellation has no error UI. */
    }
  }

  Future<void> _stopChild() async {
    final child = _process;
    if (child == null) return;
    try {
      await child.stdin
          .close(); // Helper kills its pip/build descendants on EOF.
      await child.exitCode.timeout(const Duration(seconds: 15));
    } catch (_) {
      child.kill();
    }
  }
}
