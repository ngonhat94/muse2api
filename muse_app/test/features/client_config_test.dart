import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muse_app/app/dependencies.dart';
import 'package:muse_app/features/connection/data/repositories/client_config_repository_impl.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';
import 'package:muse_app/features/connection/domain/repositories/client_config_repository.dart';
import 'package:muse_app/features/connection/presentation/bloc/connection_bloc.dart';
import 'package:muse_app/features/connection/presentation/bloc/client_config_cubit.dart';
import 'package:muse_app/features/connection/presentation/pages/connection_page.dart';

import '../support/memory_credential_store.dart';

ServerConnection principal(String role, bool capability) {
  final c = const ServerConnection(
    baseUrl: bootstrapServerUrl,
    apiKey: 'synthetic',
  );
  c.attachPrincipal(
    ServerPrincipal(
      id: 'test',
      label: 'test',
      role: role,
      capabilities: {'global_settings': capability},
    ),
  );
  return c;
}

class DeferredConfig implements ClientConfigRepository {
  final done = Completer<String>();
  @override
  Future<String> load() => done.future;
  @override
  Future<String> save(ServerConnection connection, String address) =>
      done.future;
}

void main() {
  test(
    'directory is pinned, public, single hop; bad responses fall back exactly',
    () async {
      for (final body in [
        '{}',
        '{"server_url":"http://evil.example"}',
        '{"server_url":"https://u:p@evil.example"}',
        '{"server_url":"https://evil.example?key=x"}',
      ]) {
        final repo = ClientConfigRepositoryImpl(
          () => MockClient((r) async {
            expect(
              r.url.toString(),
              '$bootstrapServerUrl/public/client-config',
            );
            expect(r.headers.containsKey('Authorization'), false);
            expect(r.followRedirects, false);
            return http.Response(body, 200);
          }),
        );
        expect(await repo.load(), defaultServerUrl);
      }
    },
  );
  test('admin save explicitly posts and verifies public readback; others never send', () async {
    var calls = 0;
    final repo = ClientConfigRepositoryImpl(
      () => MockClient((r) async {
        calls++;
        expect(r.followRedirects, false);
        if (calls == 1) {
          expect(r.method, 'POST');
          expect(r.url.toString(), '$bootstrapServerUrl/admin/client-config');
          expect(r.headers['Authorization'], 'Bearer synthetic');
          expect(jsonDecode(r.body), {
            'server_url': 'https://next.example/prefix',
          });
        } else {
          expect(r.method, 'GET');
          expect(r.headers.containsKey('Authorization'), false);
        }
        return http.Response(
          '{"server_url":"https://next.example/prefix"}',
          200,
        );
      }),
    );
    for (final c in [
      principal('user', true),
      principal('admin', false),
      const ServerConnection(
        baseUrl: bootstrapServerUrl,
        apiKey: 'synthetic',
        isLocal: true,
      ),
    ]) {
      await expectLater(
        repo.save(c, 'https://next.example'),
        throwsA(anything),
      );
    }
    expect(calls, 0);
    expect(
      await repo.save(principal('admin', true), 'https://next.example/prefix'),
      'https://next.example/prefix',
    );
    expect(calls, 2);
  });
  test('duplicate save and disposed stale save cannot emit', () async {
    final config = DeferredConfig();
    final cubit = ClientConfigCubit(config, principal('admin', true));
    final pending = cubit.save('https://next.example');
    await cubit.save('https://ignored.example');
    expect(cubit.state.busy, true);
    await cubit.close();
    config.done.complete('https://next.example');
    await pending;
  });
  test(
    'startup with changed directory does not forward remembered key',
    () async {
      SharedPreferences.setMockInitialValues({
        'server_url': 'https://old.example',
      });
      final prefs = await SharedPreferences.getInstance();
      var authenticated = 0;
      final dependencies = AppDependencies(
        prefs,
        credentialStore: MemoryCredentialStore(),
        clientFactory: () => MockClient((r) async {
          if (r.headers.containsKey('Authorization')) authenticated++;
          return http.Response('{"server_url":"https://next.example"}', 200);
        }),
      );
      await dependencies.connectionRepository.saveConnection(
        const ServerConnection(
          baseUrl: 'https://old.example',
          apiKey: 'synthetic',
        ),
      );
      final bloc = ConnectionBloc(
        dependencies.connectServer,
        restore: dependencies.restoreConnection,
        clientConfig: dependencies.clientConfig,
      );
      bloc.add(ConnectionRestored());
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(bloc.sharedAddress, 'https://next.example');
      expect(bloc.state.status, ConnectionStatus.disconnected);
      expect(bloc.state.savedConnection, isNotNull);
      expect(authenticated, 0);
      await bloc.close();
    },
  );
  test('late bootstrap after disconnect is ignored', () async {
    SharedPreferences.setMockInitialValues({});
    final deps = AppDependencies(
      await SharedPreferences.getInstance(),
      credentialStore: MemoryCredentialStore(),
    );
    final config = DeferredConfig();
    final bloc = ConnectionBloc(deps.connectServer, clientConfig: config);
    bloc.add(ConnectionRestored());
    await Future<void>.delayed(Duration.zero);
    bloc.add(ConnectionDisconnected());
    await Future<void>.delayed(Duration.zero);
    config.done.complete('https://late.example');
    await Future<void>.delayed(Duration.zero);
    expect(bloc.sharedAddress, defaultServerUrl);
    expect(bloc.loadingConfig, false);
    expect(bloc.state.status, ConnectionStatus.disconnected);
    await bloc.close();
  });
  for (final width in [390.0, 1280.0]) {
    testWidgets(
      'technical connection page at $width is hidden before verification',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 1000);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        SharedPreferences.setMockInitialValues({});
        final deps = AppDependencies(
          (await tester.runAsync(() => SharedPreferences.getInstance()))!,
          credentialStore: MemoryCredentialStore(),
        );
        final bloc = ConnectionBloc(deps.connectServer);
        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider.value(
              value: bloc,
              child: const Scaffold(
                body: ConnectionPage(savedAddress: 'https://stale.example'),
              ),
            ),
          ),
        );
        expect(find.byType(TextField), findsNothing);
        expect(find.text(defaultServerUrl), findsNothing);
        expect(find.text('Lưu cấu hình chung'), findsNothing);
        expect(find.text('https://stale.example'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(() => bloc.close());
      },
    );
  }
}
