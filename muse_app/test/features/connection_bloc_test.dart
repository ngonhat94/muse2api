import 'dart:async';

import 'package:test/test.dart';
import 'package:muse_app/core/errors/app_failure.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';
import 'package:muse_app/features/connection/domain/repositories/connection_repository.dart';
import 'package:muse_app/features/connection/domain/usecases/connect_server.dart';
import 'package:muse_app/features/connection/domain/usecases/restore_connection.dart';
import 'package:muse_app/features/connection/presentation/bloc/connection_bloc.dart';

class FakeConnectionRepository implements ConnectionRepository {
  final verification = Completer<void>();
  String? saved;
  @override
  String? get savedAddress => saved;
  @override
  Future<void> verify(ServerConnection connection) => verification.future;
  ServerConnection? credentials;
  @override
  Future<void> saveConnection(ServerConnection connection) async {
    saved = connection.baseUrl;
    credentials = connection;
  }

  @override
  Future<ServerConnection?> readSavedConnection() async => credentials;
  @override
  Future<void> forgetConnection() async {
    credentials = null;
  }
}

Future<void> tick() => Future<void>.delayed(Duration.zero);
void main() {
  test(
    'Validates address and strips trailing slash without losing proxy prefix',
    () {
      final connection = ServerConnection.parse(
        ' https://example.com/muse/ ',
        ' secret ',
      );
      expect(
        connection.endpoint('/v1/models').toString(),
        'https://example.com/muse/v1/models',
      );
      expect(connection.apiKey, 'secret');
      expect(connection.toString(), isNot(contains('secret')));
      for (final url in [
        'ftp://example.com',
        'https://user:password@example.com',
        'https://example.com?key=secret',
        'https://example.com/v1/',
        'invalid',
      ]) {
        expect(
          () => ServerConnection.parse(url, 'key'),
          throwsA(isA<AppFailure>()),
        );
      }
    },
  );
  test('Becomes connected only after server verification', () async {
    final repository = FakeConnectionRepository();
    final bloc = ConnectionBloc(ConnectServer(repository));
    addTearDown(bloc.close);
    bloc.add(ConnectionRequested('https://example.com', 'secret'));
    await tick();
    expect(bloc.state.status, ConnectionStatus.connecting);
    repository.verification.complete();
    await tick();
    expect(bloc.state.status, ConnectionStatus.connected);
    expect(repository.saved, 'https://example.com');
    bloc.add(ConnectionDisconnected());
    await tick();
    expect(bloc.state.connection, isNull);
  });
  test('Late verification cannot reconnect after disconnect', () async {
    final repository = FakeConnectionRepository();
    final bloc = ConnectionBloc(ConnectServer(repository));
    addTearDown(bloc.close);
    bloc.add(ConnectionRequested('https://example.com', 'secret'));
    await tick();
    bloc.add(ConnectionDisconnected());
    await tick();
    repository.verification.complete();
    await tick();
    expect(bloc.state.status, ConnectionStatus.disconnected);
    expect(bloc.state.connection, isNull);
  });
  test('Authentication failure leaves connection empty', () async {
    final repository = FakeConnectionRepository();
    final bloc = ConnectionBloc(ConnectServer(repository));
    addTearDown(bloc.close);
    bloc.add(ConnectionRequested('https://example.com', 'secret'));
    await tick();
    repository.verification.completeError(const AppFailure('Invalid key'));
    await tick();
    expect(bloc.state.error, 'Invalid key');
    expect(bloc.state.connection, isNull);
    expect(repository.saved, isNull);
  });

  test(
    'Reopening restores saved credentials and verifies without typing key',
    () async {
      final repository = FakeConnectionRepository();
      repository.verification.complete();
      final first = ConnectionBloc(ConnectServer(repository));
      final connected = first.stream.firstWhere(
        (s) => s.status == ConnectionStatus.connected,
      );
      first.add(ConnectionRequested('https://example.com', 'remember-me'));
      await connected;
      await first.close();
      final reopened = ConnectionBloc(
        ConnectServer(repository),
        restore: RestoreConnection(repository),
      );
      addTearDown(reopened.close);
      final restored = reopened.stream.firstWhere(
        (s) => s.status == ConnectionStatus.connected,
      );
      reopened.add(ConnectionRestored());
      expect((await restored).connection!.apiKey, 'remember-me');
    },
  );
  test(
    'Disconnect keeps remembered credentials; forgetting removes them',
    () async {
      final repository = FakeConnectionRepository();
      repository.verification.complete();
      final bloc = ConnectionBloc(
        ConnectServer(repository),
        forget: ForgetConnection(repository),
      );
      addTearDown(bloc.close);
      final connected = bloc.stream.firstWhere(
        (s) => s.status == ConnectionStatus.connected,
      );
      bloc.add(ConnectionRequested('https://example.com', 'remember-me'));
      await connected;
      bloc.add(ConnectionDisconnected());
      await tick();
      expect(bloc.state.connection, isNull);
      expect(bloc.state.savedConnection!.apiKey, 'remember-me');
      expect(repository.credentials, isNotNull);
      bloc.add(ConnectionForgotten());
      await tick();
      expect(bloc.state.savedConnection, isNull);
      expect(repository.credentials, isNull);
    },
  );
  test('Failed automatic verification retains key for reconnecting', () async {
    final repository = FakeConnectionRepository()
      ..credentials = ServerConnection.parse(
        'https://example.com',
        'remember-me',
      );
    final bloc = ConnectionBloc(
      ConnectServer(repository),
      restore: RestoreConnection(repository),
    );
    addTearDown(bloc.close);
    bloc.add(ConnectionRestored());
    await tick();
    repository.verification.completeError(const AppFailure('Server offline'));
    await tick();
    expect(bloc.state.status, ConnectionStatus.disconnected);
    expect(bloc.state.savedConnection!.apiKey, 'remember-me');
    expect(bloc.state.error, 'Server offline');
  });
  test('No saved credentials leaves app disconnected', () async {
    final repository = FakeConnectionRepository();
    final bloc = ConnectionBloc(
      ConnectServer(repository),
      restore: RestoreConnection(repository),
    );
    addTearDown(bloc.close);
    bloc.add(ConnectionRestored());
    await tick();
    expect(bloc.state.status, ConnectionStatus.disconnected);
    expect(bloc.state.savedConnection, isNull);
  });
}
