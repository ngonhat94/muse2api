import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muse_app/app/app.dart';
import 'package:muse_app/app/dependencies.dart';
import 'package:muse_app/app/shell.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';
import 'package:muse_app/features/connection/domain/entities/connection_permissions.dart';
import 'package:muse_app/features/connection/domain/repositories/client_config_repository.dart';
import 'package:muse_app/features/connection/presentation/bloc/connection_bloc.dart';
import 'package:muse_app/features/connection/presentation/pages/key_login_page.dart';
import 'package:muse_app/features/connection/presentation/pages/connection_page.dart';
import 'package:muse_app/features/connection/presentation/pages/server_settings_page.dart';
import 'package:muse_app/features/status/presentation/pages/server_status_page.dart';
import 'package:muse_app/features/status/presentation/bloc/server_status_bloc.dart';
import 'package:muse_app/features/status/domain/usecases/load_server_status.dart';

import 'features/status/status_bloc_test.dart' show PendingStatusRepository;
import 'support/memory_credential_store.dart';

Future<void> frames(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  test('technical permissions fail closed, local engine is not admin', () {
    for (final role in ['user', 'unknown', 'admin']) {
      for (final capability in [false, true]) {
        final c = ServerConnection(
          baseUrl: 'https://fixture.invalid',
          apiKey: 'synthetic',
        );
        c.attachPrincipal(
          ServerPrincipal(
            id: 'fixture',
            label: 'Fixture',
            role: role,
            capabilities: {'global_settings': capability},
          ),
        );
        expect(canConfigureServer(c), role == 'admin' && capability);
      }
    }
    const local = ServerConnection(
      baseUrl: 'http://localhost',
      apiKey: 'synthetic',
      isLocal: true,
    );
    expect(canConfigureServer(local), false);
    expect(canShowConnectionTools(local, supportsLocal: true), true);
    expect(canShowConnectionTools(null, supportsLocal: false), false);
    expect(canConfigureServer(null), false);
  });

  test('admin diagnostics in flight are discarded on a user session', () async {
    final repository = PendingStatusRepository();
    final bloc = ServerStatusBloc(LoadServerStatus(repository));
    final admin = ServerConnection(
      baseUrl: 'https://fixture.invalid',
      apiKey: 'synthetic',
    );
    admin.attachPrincipal(
      const ServerPrincipal(
        id: 'a',
        label: 'Admin',
        role: 'admin',
        capabilities: {'global_settings': true},
      ),
    );
    bloc.connectionChanged(admin);
    final pending = bloc.refresh();
    final user = ServerConnection(baseUrl: admin.baseUrl, apiKey: admin.apiKey);
    user.attachPrincipal(
      const ServerPrincipal(
        id: 'u',
        label: 'User',
        role: 'user',
        capabilities: {'global_settings': true},
      ),
    );
    bloc.connectionChanged(user);
    repository.calls.single.completeError(Exception('private diagnostics'));
    await pending;
    await bloc.refresh();
    expect(repository.calls, hasLength(1));
    expect(bloc.state.connection, isNull);
    expect(bloc.state.snapshot, isNull);
    expect(bloc.state.error, isNull);
    await bloc.close();
  });

  for (final width in [390.0, 1280.0]) {
    for (final role in ['user', 'unknown', 'admin', 'admin-no-capability']) {
      testWidgets('role=$role navigation and gate at $width', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 1100);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        SharedPreferences.setMockInitialValues({});
        final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
        final calls = <String>[];
        final dependencies = AppDependencies(
          prefs,
          credentialStore: MemoryCredentialStore(),
          clientFactory: () => MockClient((r) async {
            calls.add(r.url.path);
            if (r.url.path == '/public/client-config') {
              return http.Response(
                jsonEncode({'server_url': defaultServerUrl}),
                200,
              );
            }
            if (r.url.path == '/v1/me') {
              return http.Response(
                jsonEncode({
                  'id': 'synthetic-id',
                  'label': 'Synthetic fixture',
                  'role': role == 'admin-no-capability' ? 'admin' : role,
                  'capabilities': {
                    'global_settings': role != 'admin-no-capability',
                    'manage_users': role == 'admin',
                  },
                }),
                200,
              );
            }
            if (r.url.path == '/v1/models') {
              return http.Response('{"data":[]}', 200);
            }
            return http.Response('{}', 200);
          }),
        );
        await tester.pumpWidget(
          MuseApp(dependencies: dependencies, requireKey: true),
        );
        await frames(tester);
        expect(find.text(defaultServerUrl, skipOffstage: false), findsNothing);
        await tester.enterText(find.byType(TextField), 'synthetic-valid');
        await tester.tap(find.text('Đăng nhập'));
        await frames(tester);
        if (role == 'unknown') {
          expect(find.byType(KeyLoginPage), findsOneWidget);
          expect(find.byType(AppShell), findsNothing);
          expect(
            find.text(defaultServerUrl, skipOffstage: false),
            findsNothing,
          );
          await tester.pumpWidget(const SizedBox());
          await frames(tester);
          return;
        }
        expect(find.byType(AppShell), findsOneWidget);
        final shellContext = tester.element(find.byType(AppShell));
        final bloc = shellContext.read<ConnectionBloc>();
        if (width < 800) {
          await tester.tap(find.text('Thêm'));
          await frames(tester);
        }
        final admin = role == 'admin';
        for (final label in [
          'Cài đặt server',
          'Trạng thái server',
          'Người dùng & API key',
        ]) {
          if (admin && width >= 800) {
            await tester.scrollUntilVisible(
              find.text(label),
              180,
              scrollable: find
                  .descendant(
                    of: find.byType(AppShell),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
          }
          expect(find.text(label), admin ? findsOneWidget : findsNothing);
        }
        expect(find.byType(ConnectionPage, skipOffstage: false), findsNothing);
        expect(find.text('Kết nối Muse'), findsNothing);
        expect(find.text('Engine trên máy'), findsNothing);
        expect(
          find.byType(ServerStatusPage, skipOffstage: false),
          findsNothing,
        );
        expect(find.text(defaultServerUrl, skipOffstage: false), findsNothing);
        expect(
          calls.where((p) => p == '/admin/status' || p == '/admin/users'),
          isEmpty,
        );
        expect(find.text('Đăng xuất'), findsOneWidget);
        if (admin) {
          if (width >= 800) {
            await tester.scrollUntilVisible(
              find.text('Cài đặt server'),
              -180,
              scrollable: find
                  .descendant(
                    of: find.byType(AppShell),
                    matching: find.byType(Scrollable),
                  )
                  .first,
            );
          }
          await tester.tap(find.text('Cài đặt server'));
          await frames(tester);
          expect(find.byType(ServerSettingsPage), findsOneWidget);
          expect(
            find.byType(ConnectionPage, skipOffstage: false),
            findsNothing,
          );
          expect(find.text('Ngắt kết nối'), findsNothing);
          expect(find.text('Đăng nhập server'), findsNothing);
          expect(find.text('Quên API key đã lưu'), findsNothing);
          expect(find.text('Địa chỉ server dùng chung'), findsOneWidget);
          if (width < 800) {
            await tester.tap(find.text('Thêm'));
            await frames(tester);
          }
        }
        if (width < 800) {
          await tester.tap(find.text('Tài khoản'));
        } else {
          await tester.scrollUntilVisible(
            find.text('Tài khoản'),
            -180,
            scrollable: find
                .descendant(
                  of: find.byType(AppShell),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.tap(find.text('Tài khoản'));
        }
        await frames(tester);
        expect(find.text('Nhập tài khoản'), findsOneWidget);
        expect(find.text('Tài khoản Muse'), findsOneWidget);
        await tester.tap(find.text('Nhập tài khoản'));
        await frames(tester);
        expect(find.text('Cookie string'), findsOneWidget);
        bloc.add(ConnectionDisconnected());
        await frames(tester);
        expect(find.byType(KeyLoginPage), findsOneWidget);
        expect(find.byType(AppShell), findsNothing);
        expect(find.text(defaultServerUrl, skipOffstage: false), findsNothing);
        expect(find.text('Cookie string'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await frames(tester);
      });
    }
  }
}
