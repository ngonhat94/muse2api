import 'dart:async';
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
import 'package:muse_app/features/connection/domain/repositories/client_config_repository.dart';
import 'package:muse_app/features/connection/presentation/bloc/connection_bloc.dart';
import 'package:muse_app/features/connection/presentation/pages/key_login_page.dart';

import 'support/memory_credential_store.dart';

void main() {
  for (final width in [390.0, 1280.0]) {
    for (final role in ['user', 'admin']) {
      testWidgets(
        'web gate $width $role: empty, invalid, verified, disconnect',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 1000);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);
          SharedPreferences.setMockInitialValues({});
          final calls = <String>[];
          final verification = Completer<http.Response>();
          final deps = AppDependencies(
            (await tester.runAsync(SharedPreferences.getInstance))!,
            credentialStore: MemoryCredentialStore(),
            clientFactory: () => MockClient((r) async {
              calls.add(r.url.path);
              if (r.url.path == '/public/client-config') {
                expect(r.headers.containsKey('Authorization'), false);
                return http.Response(
                  jsonEncode({'server_url': defaultServerUrl}),
                  200,
                );
              }
              if (r.url.path == '/v1/models') {
                if (r.headers['Authorization'] != 'Bearer synthetic-valid') {
                  return http.Response('do not display synthetic-invalid', 401);
                }
                return http.Response('{"data":[]}', 200);
              }
              if (r.url.path == '/v1/me') return verification.future;
              return http.Response('{}', 200);
            }),
          );
          await tester.pumpWidget(
            MuseApp(dependencies: deps, requireKey: true),
          );
          expect(find.byType(AppShell), findsNothing);
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 40)),
          );
          await tester.pump();
          expect(calls, ['/public/client-config']);
          expect(find.byType(TextField), findsOneWidget);
          expect(
            tester.widget<TextField>(find.byType(TextField)).obscureText,
            true,
          );
          expect(find.byType(NavigationBar), findsNothing);
          expect(find.text('Ảnh thành prompt'), findsNothing);
          await tester.tap(find.text('Đăng nhập'));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
          expect(find.byType(AppShell), findsNothing);
          expect(calls, ['/public/client-config']);
          await tester.enterText(find.byType(TextField), 'synthetic-invalid');
          await tester.tap(find.text('Đăng nhập'));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
          expect(
            find.text('API key không hợp lệ hoặc không có quyền truy cập.'),
            findsOneWidget,
          );
          expect(find.textContaining('do not display'), findsNothing);
          expect(find.byType(AppShell), findsNothing);
          await tester.enterText(find.byType(TextField), 'synthetic-valid');
          await tester.tap(find.text('Đăng nhập'));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
          expect(find.byType(AppShell), findsNothing);
          expect(
            tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
            isNull,
          );
          expect(
            tester.widget<TextField>(find.byType(TextField)).enabled,
            false,
          );
          final before = calls.length;
          await tester.testTextInput.receiveAction(TextInputAction.done);
          await tester.pump();
          expect(calls.length, before);
          verification.complete(
            http.Response(
              jsonEncode({
                'id': 'fixture',
                'label': 'Fixture',
                'role': role,
                'capabilities': {'manage_users': role == 'admin'},
              }),
              200,
            ),
          );
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 40)),
          );
          await tester.pump();
          await tester.pump();
          expect(find.byType(AppShell), findsOneWidget);
          expect(find.byType(KeyLoginPage), findsNothing);
          final context = tester.element(find.byType(AppShell));
          final bloc = context.read<ConnectionBloc>();
          expect(bloc.state.connection!.principal!.role, role);
          if (role == 'admin') {
            // A current credential rejection gates the whole app; 403 does not.
            deps.onCredentialRejected!(
              Uri.parse('$defaultServerUrl/v1/tasks'),
              'Bearer synthetic-valid',
            );
          } else {
            bloc.add(ConnectionDisconnected());
          }
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
          expect(find.byType(AppShell), findsNothing);
          expect(find.byType(KeyLoginPage), findsOneWidget);
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            isEmpty,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
        },
      );
    }
  }

  for (final status in [200, 401, 503, -1]) {
    final success = status == 200;
    testWidgets('remembered key is verified before shell; status=$status', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final pending = Completer<http.Response>();
      final deps = AppDependencies(
        (await tester.runAsync(SharedPreferences.getInstance))!,
        credentialStore: MemoryCredentialStore(),
        clientFactory: () => MockClient((r) async {
          if (r.url.path == '/public/client-config') {
            return http.Response(
              jsonEncode({'server_url': defaultServerUrl}),
              200,
            );
          }
          if (r.url.path == '/v1/models') {
            return http.Response('{"data":[]}', 200);
          }
          if (r.url.path == '/v1/me') return pending.future;
          return http.Response('{}', 200);
        }),
      );
      await tester.runAsync(
        () => deps.connectionRepository.saveConnection(
          const ServerConnection(
            baseUrl: defaultServerUrl,
            apiKey: 'synthetic-stored',
          ),
        ),
      );
      await tester.pumpWidget(MuseApp(dependencies: deps, requireKey: true));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump();
      expect(find.byType(AppShell), findsNothing);
      expect(find.byType(KeyLoginPage), findsOneWidget);
      if (status == -1) {
        tester
            .element(find.byType(KeyLoginPage))
            .read<ConnectionBloc>()
            .add(ConnectionDisconnected());
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      pending.complete(
        http.Response(
          (success || status == -1)
              ? '{"id":"fixture","label":"Fixture","role":"user","capabilities":{}}'
              : 'revoked',
          status == -1 ? 200 : status,
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(AppShell), success ? findsOneWidget : findsNothing);
      if (status == 401) {
        expect(
          find.text('API key không hợp lệ hoặc không có quyền truy cập.'),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    });
  }
}
