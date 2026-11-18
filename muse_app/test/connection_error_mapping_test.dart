import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muse_app/app/dependencies.dart';
import 'package:muse_app/core/network/api_error.dart';
import 'package:muse_app/features/connection/presentation/bloc/connection_bloc.dart';

import 'support/memory_credential_store.dart';

void main() {
  for (final path in ['/v1/models', '/v1/me']) {
    for (final failure in ['401', '403', 'network', 'timeout', 'malformed']) {
      test('$path $failure stays disconnected with safe actionable error', () async {
        SharedPreferences.setMockInitialValues({});
        var rejections = 0;
        final store = MemoryCredentialStore();
        final deps = AppDependencies(
          await SharedPreferences.getInstance(),
          credentialStore: store,
          clientFactory: () => MockClient((r) async {
            if (r.url.path == path) {
              switch (failure) {
                case 'network':
                  throw http.ClientException('synthetic-secret transport');
                case 'timeout':
                  throw TimeoutException('synthetic-secret timeout');
                case 'malformed':
                  return http.Response('synthetic-secret invalid json', 200);
                default:
                  return http.Response(
                    'synthetic-secret server body',
                    int.parse(failure),
                  );
              }
            }
            return http.Response('{"data":[]}', 200);
          }),
        );
        // Startup has no mounted session listener. A captured listener must not
        // swallow the HTTP error either, even when several clients reject.
        deps.onCredentialRejected = (_, _) => rejections++;
        final bloc = ConnectionBloc(
          deps.connectServer,
          onSessionEnded: deps.endSession,
          onSessionStarting: deps.startSession,
        );
        final done = bloc.stream.firstWhere((s) => s.error != null);
        bloc.add(
          ConnectionRequested('https://fixture.example', 'synthetic-secret'),
        );
        final state = await done;
        expect(state.status, ConnectionStatus.disconnected);
        expect(state.connection, isNull);
        expect(await deps.restoreConnection(), isNull);
        expect(state.error, isNot(contains('synthetic-secret')));
        switch (failure) {
          case '401':
            expect(state.error, apiError(401, '').message);
            expect(rejections, 1);
          case '403':
            expect(state.error, apiError(403, '').message);
            expect(rejections, 0);
          case 'network':
            expect(state.error, contains('Kiểm tra mạng'));
            expect(state.error, isNot(contains('Kiểm tra URL')));
          case 'timeout':
            expect(state.error, contains('quá chậm'));
          case 'malformed':
            expect(state.error, contains('phản hồi không hợp lệ'));
        }
        await bloc.close();
      });
    }
  }

  test('logout wins over a concurrent login 401 without stale error', () async {
    SharedPreferences.setMockInitialValues({});
    final response = Completer<http.Response>();
    final entered = Completer<void>();
    final deps = AppDependencies(
      await SharedPreferences.getInstance(),
      credentialStore: MemoryCredentialStore(),
      clientFactory: () => MockClient((_) {
        entered.complete();
        return response.future;
      }),
    );
    final bloc = ConnectionBloc(
      deps.connectServer,
      forget: deps.forgetConnection,
      onSessionEnded: deps.endSession,
      onSessionStarting: deps.startSession,
    );
    final states = <ServerConnectionState>[];
    final subscription = bloc.stream.listen(states.add);
    bloc.add(
      ConnectionRequested('https://fixture.example', 'synthetic-secret'),
    );
    await entered.future;
    final loggedOut = bloc.stream.firstWhere((s) => s.loggingOut);
    bloc.add(LogoutRequested());
    await loggedOut;
    response.complete(http.Response('synthetic-secret', 401));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(bloc.state.connection, isNull);
    expect(bloc.state.error, isNull);
    expect(states.any((s) => s.status == ConnectionStatus.connected), false);
    await subscription.cancel();
    await bloc.close();
  });
}
