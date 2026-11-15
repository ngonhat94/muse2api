import 'dart:async';

import 'package:test/test.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';
import 'package:muse_app/features/connection/domain/repositories/connection_repository.dart';
import 'package:muse_app/features/connection/domain/usecases/connect_server.dart';
import 'package:muse_app/features/connection/domain/usecases/restore_connection.dart';
import 'package:muse_app/features/connection/presentation/bloc/connection_bloc.dart';
import 'package:muse_app/features/desktop/domain/repositories/desktop_engine.dart';
import 'package:muse_app/features/desktop/data/desktop_engine_io.dart';
import 'package:muse_app/features/desktop/domain/repositories/desktop_engine_failure.dart';
import 'package:muse_app/features/desktop/domain/repositories/desktop_engine_installer.dart';

const remote = ServerConnection(
  baseUrl: 'https://example.test',
  apiKey: 'remember-remote',
);
const local = ServerConnection(
  baseUrl: 'http://127.0.0.1:32100',
  apiKey: 'transient',
  isLocal: true,
);

class SavedServer implements ConnectionRepository {
  ServerConnection? saved;
  int writes = 0;
  int verifies = 0;
  bool readFails = false;
  @override
  String? get savedAddress => saved?.baseUrl;
  @override
  Future<ServerConnection?> readSavedConnection() async {
    if (readFails) throw StateError('fixture-keychain-unavailable');
    return saved;
  }

  @override
  Future<void> saveConnection(ServerConnection c) async {
    saved = c;
    writes++;
  }

  @override
  Future<void> forgetConnection() async {
    saved = null;
  }

  @override
  Future<void> verify(ServerConnection c) async {
    verifies++;
  }
}

class FakeEngine implements DesktopEngine {
  int starts = 0;
  int stops = 0;
  bool fail = false;
  @override
  bool supported = true;
  Completer<ServerConnection>? pending;
  final exits = StreamController<void>.broadcast();
  @override
  Stream<void> get unexpectedExit => exits.stream;
  @override
  Future<ServerConnection> start() async {
    starts++;
    if (fail) throw StateError('sensitive-fixture');
    return pending?.future ?? local;
  }

  @override
  Future<void> stop() async {
    stops++;
  }
}

class InstallEngine extends FakeEngine implements DesktopEngineInstaller {
  int installs = 0;
  int cancellations = 0;
  Completer<void>? installation;
  Completer<void>? cancellation;
  Object? installError;
  void Function(DesktopInstallStage)? progress;
  @override
  Future<void> install(void Function(DesktopInstallStage) onProgress) async {
    installs++;
    progress = onProgress;
    if (installError != null) throw installError!;
    await installation?.future;
  }

  @override
  Future<void> cancelInstall() async {
    cancellations++;
    await cancellation?.future;
    if (installation != null && !installation!.isCompleted) {
      installation!.completeError(
        const DesktopEngineFailure(DesktopEngineFailureCode.installCancelled),
      );
    }
  }
}

Future<void> tick() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test(
    'First desktop launch starts local without saving ephemeral credentials',
    () async {
      final repo = SavedServer();
      final engine = FakeEngine();
      bool? preferred;
      final bloc = ConnectionBloc(
        ConnectServer(repo),
        restore: RestoreConnection(repo),
        desktop: engine,
        readLocalPreference: () async => preferred,
        saveLocalPreference: (v) async {
          preferred = v;
        },
      );
      addTearDown(bloc.close);
      final ready = bloc.stream.firstWhere(
        (s) => s.status == ConnectionStatus.connected,
      );
      bloc.add(ConnectionRestored());
      final state = await ready;
      expect(state.connection, local);
      expect(state.localMode, true);
      expect(repo.writes, 0);
      expect(repo.verifies, 0);
      expect(preferred, true);
      expect(state.savedConnection, isNull);
    },
  );
  test('Existing remote key is restored by default and survives switching to local and back', () async {
    final repo = SavedServer()..saved = remote;
    final engine = FakeEngine();
    bool? preferred;
    final bloc = ConnectionBloc(
      ConnectServer(repo),
      restore: RestoreConnection(repo),
      desktop: engine,
      saveLocalPreference: (v) async {
        preferred = v;
      },
    );
    addTearDown(bloc.close);
    bloc.add(ConnectionRestored());
    await tick();
    expect(bloc.state.connection?.baseUrl, remote.baseUrl);
    expect(engine.starts, 0);
    bloc.add(LocalConnectionRequested());
    await tick();
    expect(bloc.state.connection, local);
    expect(repo.saved?.apiKey, remote.apiKey);
    expect(bloc.state.savedConnection?.apiKey, remote.apiKey);
    expect(preferred, true);
    bloc.add(ConnectionRequested(remote.baseUrl, remote.apiKey));
    await tick();
    expect(bloc.state.connection!.isLocal, false);
    expect(preferred, false);
    expect(engine.stops, greaterThan(0));
  });
  test('Remembered local choice restores local while retaining the remote credentials', () async {
    final repo = SavedServer()..saved = remote;
    final engine = FakeEngine();
    final bloc = ConnectionBloc(
      ConnectServer(repo),
      restore: RestoreConnection(repo),
      desktop: engine,
      readLocalPreference: () async => true,
    );
    addTearDown(bloc.close);
    bloc.add(ConnectionRestored());
    await tick();
    expect(bloc.state.connection, local);
    expect(bloc.state.savedConnection, remote);
    expect(repo.writes, 0);
    bloc.add(
      ConnectionForgotten(),
    ); // no forget use case: remote key remains intact
    await tick();
    expect(repo.saved, remote);
  });
  test('Duplicate start is ignored and cancel rejects late results', () async {
    final repo = SavedServer();
    final engine = FakeEngine()..pending = Completer();
    final bloc = ConnectionBloc(ConnectServer(repo), desktop: engine);
    addTearDown(bloc.close);
    bloc.add(LocalConnectionRequested());
    bloc.add(LocalConnectionRequested());
    await tick();
    expect(engine.starts, 1);
    bloc.add(ConnectionDisconnected());
    await tick();
    engine.pending!.complete(local);
    await tick();
    expect(bloc.state.connection, isNull);
    expect(engine.stops, 1);
  });
  test('Unexpected runtime exit clears active session without discarding saved server', () async {
    final repo = SavedServer()..saved = remote;
    final engine = FakeEngine();
    final bloc = ConnectionBloc(
      ConnectServer(repo),
      desktop: engine,
      restore: RestoreConnection(repo),
      readLocalPreference: () async => true,
    );
    addTearDown(bloc.close);
    bloc.add(ConnectionRestored());
    await tick();
    engine.exits.add(null);
    await tick();
    expect(bloc.state.connection, isNull);
    expect(bloc.state.localMode, true);
    expect(bloc.state.error, contains('đã dừng'));
    expect(bloc.state.savedConnection, remote);
    bloc.add(LocalConnectionRequested());
    await tick();
    expect(bloc.state.connection, local);
  });
  test(
    'Failure is sanitized; retry works; unsupported platforms never spawn',
    () async {
      final engine = FakeEngine()..fail = true;
      final bloc = ConnectionBloc(
        ConnectServer(SavedServer()),
        desktop: engine,
      );
      addTearDown(bloc.close);
      bloc.add(LocalConnectionRequested());
      await tick();
      expect(bloc.state.error, isNot(contains('sensitive-fixture')));
      expect(bloc.state.connection, isNull);
      engine.fail = false;
      bloc.add(LocalConnectionRequested());
      await tick();
      expect(bloc.state.connection, local);
      bloc.add(ConnectionDisconnected());
      await tick();
      engine.supported = false;
      bloc.add(LocalConnectionRequested());
      await tick();
      expect(engine.starts, 2);
      expect(bloc.state.connection, isNull);
    },
  );
  test('Closing the BLoC stops its owned engine', () async {
    final engine = FakeEngine();
    final bloc = ConnectionBloc(ConnectServer(SavedServer()), desktop: engine);
    bloc.add(LocalConnectionRequested());
    await tick();
    await bloc.close();
    expect(engine.stops, 1);
  });
  test(
    'Missing packaged executable yields actionable sanitized failure',
    () async {
      final engine = ProcessDesktopEngine(
        executable: '/nonexistent/muse_engine',
      );
      await expectLater(
        engine.start(),
        throwsA(predicate((e) => e.toString().contains('đóng gói đầy đủ'))),
      );
      await engine.stop();
    },
  );
  test('Helper exit during preference persistence cannot publish a dead connection', () async {
    final engine = FakeEngine();
    final preference = Completer<void>();
    final bloc = ConnectionBloc(
      ConnectServer(SavedServer()),
      desktop: engine,
      saveLocalPreference: (_) => preference.future,
    );
    addTearDown(bloc.close);
    bloc.add(LocalConnectionRequested());
    await tick();
    expect(bloc.state.status, ConnectionStatus.connecting);
    engine.exits.add(null);
    await tick();
    expect(bloc.state.connection, isNull);
    expect(bloc.state.error, contains('đã dừng'));
    preference.complete();
    await tick();
    expect(bloc.state.connection, isNull);
    expect(bloc.state.status, ConnectionStatus.disconnected);
  });
  test(
    'Preferred local startup survives inaccessible remote credential storage',
    () async {
      final repo = SavedServer()
        ..saved = remote
        ..readFails = true;
      final bloc = ConnectionBloc(
        ConnectServer(repo),
        desktop: FakeEngine(),
        restore: RestoreConnection(repo),
        readLocalPreference: () async => true,
      );
      addTearDown(bloc.close);
      bloc.add(ConnectionRestored());
      await tick();
      expect(bloc.state.connection, local);
      expect(repo.saved, remote);
      expect(repo.writes, 0);
    },
  );
  test(
    'Missing engine diagnosis survives the BLoC and retains remote credentials',
    () async {
      final repo = SavedServer()..saved = remote;
      final engine = ProcessDesktopEngine(
        executable: '/nonexistent/muse_engine',
      );
      final bloc = ConnectionBloc(ConnectServer(repo), desktop: engine);
      addTearDown(bloc.close);
      bloc.add(LocalConnectionRequested());
      await tick();
      expect(
        bloc.state.error,
        const DesktopEngineFailure(DesktopEngineFailureCode.missingEngine)
            .message,
      );
      expect(bloc.state.error, contains('chưa có engine'));
      expect(bloc.state.connection, isNull);
      expect(repo.saved, remote);
    },
  );
  test(
    'Protocol codes map to fixed messages without echoing untrusted content',
    () {
      expect(
        DesktopEngineFailure.fromProtocol('browser_missing').code,
        DesktopEngineFailureCode.missingBrowser,
      );
      expect(
        DesktopEngineFailure.fromProtocol('engine_in_use').code,
        DesktopEngineFailureCode.alreadyRunning,
      );
      expect(
        DesktopEngineFailure.fromProtocol('storage_denied').code,
        DesktopEngineFailureCode.storageDenied,
      );
      final failure = DesktopEngineFailure.fromProtocol('sensitive-fixture');
      expect(failure.code, DesktopEngineFailureCode.startupFailed);
      expect(failure.message, isNot(contains('sensitive-fixture')));
      expect(failure.toString(), failure.message);
    },
  );
  test('Install emits progress, rejects duplicates and auto-connects without replacing saved key', () async {
    final repo = SavedServer()..saved = remote;
    final engine = InstallEngine()..installation = Completer<void>();
    final bloc = ConnectionBloc(
      ConnectServer(repo),
      desktop: engine,
      restore: RestoreConnection(repo),
    );
    addTearDown(bloc.close);
    bloc.add(ConnectionRestored());
    await tick();
    bloc.add(ConnectionDisconnected());
    await tick();
    final writes = repo.writes;
    bloc.add(DesktopInstallationRequested());
    bloc.add(DesktopInstallationRequested());
    await tick();
    expect(engine.installs, 1);
    expect(bloc.state.installation, DesktopInstallStage.preparing);
    engine.progress!(DesktopInstallStage.browser);
    await tick();
    expect(bloc.state.installation, DesktopInstallStage.browser);
    engine.installation!.complete();
    await tick();
    expect(bloc.state.connection, local);
    expect(bloc.state.installation, isNull);
    expect(bloc.state.savedConnection!.apiKey, remote.apiKey);
    expect(repo.saved!.apiKey, remote.apiKey);
    expect(repo.writes, writes);
    expect(engine.starts, 1);
  });
  test('Cancel blocks connection changes until cleanup and ignores late install success/progress', () async {
    final engine = InstallEngine()
      ..installation = Completer<void>()
      ..cancellation = Completer<void>();
    final bloc = ConnectionBloc(ConnectServer(SavedServer()), desktop: engine);
    addTearDown(bloc.close);
    bloc.add(DesktopInstallationRequested());
    await tick();
    bloc.add(DesktopInstallationCancelled());
    await tick();
    expect(bloc.state.installation, DesktopInstallStage.cancelling);
    bloc.add(ConnectionRequested(remote.baseUrl, remote.apiKey));
    bloc.add(DesktopInstallationRequested());
    await tick();
    expect(engine.installs, 1);
    engine.progress!(DesktopInstallStage.verifying);
    engine.installation!.complete();
    await tick();
    expect(bloc.state.installation, DesktopInstallStage.cancelling);
    expect(engine.starts, 0);
    engine.cancellation!.complete();
    await tick();
    expect(bloc.state.status, ConnectionStatus.disconnected);
    expect(bloc.state.error, isNull);
    engine.installation = null;
    bloc.add(DesktopInstallationRequested());
    await tick();
    expect(engine.installs, 2);
    expect(bloc.state.connection, local);
  });
  test('Install errors have actionable fixed messages and arbitrary errors stay private', () async {
    final engine = InstallEngine()
      ..installError = const DesktopEngineFailure(
        DesktopEngineFailureCode.pythonMissing,
      );
    final bloc = ConnectionBloc(ConnectServer(SavedServer()), desktop: engine);
    addTearDown(bloc.close);
    bloc.add(DesktopInstallationRequested());
    await tick();
    expect(bloc.state.error, contains('Python 3.11'));
    expect(bloc.state.installation, isNull);
    expect(engine.starts, 0);
    engine.installError = StateError('sensitive-fixture');
    bloc.add(DesktopInstallationRequested());
    await tick();
    expect(bloc.state.error, isNot(contains('sensitive-fixture')));
    expect(bloc.state.status, ConnectionStatus.disconnected);
  });
  test('Installation never interrupts an active remote session', () async {
    final engine = InstallEngine();
    final repo = SavedServer();
    final bloc = ConnectionBloc(ConnectServer(repo), desktop: engine);
    addTearDown(bloc.close);
    bloc.add(ConnectionRequested(remote.baseUrl, remote.apiKey));
    await tick();
    final current = bloc.state.connection;
    bloc.add(DesktopInstallationRequested());
    await tick();
    expect(engine.installs, 0);
    expect(bloc.state.connection, same(current));
  });
  test('Closing the app cancels a pending installation', () async {
    final engine = InstallEngine()..installation = Completer<void>();
    final bloc = ConnectionBloc(ConnectServer(SavedServer()), desktop: engine);
    bloc.add(DesktopInstallationRequested());
    await tick();
    await bloc.close();
    expect(engine.cancellations, 1);
    expect(engine.starts, 0);
  });
}
