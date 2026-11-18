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
import 'package:muse_app/core/network/session_client.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';
import 'package:muse_app/features/connection/domain/repositories/client_config_repository.dart';
import 'package:muse_app/features/connection/data/datasources/connection_local_data_source.dart';
import 'package:muse_app/features/connection/presentation/bloc/connection_bloc.dart';
import 'package:muse_app/features/connection/presentation/pages/key_login_page.dart';

import 'support/memory_credential_store.dart';

class FailingDeleteStore extends MemoryCredentialStore {
  bool fail = true;
  int deletes = 0;
  Completer<void>? pending;
  @override
  Future<void> delete() async {
    deletes++;
    await pending?.future;
    if (fail) throw StateError('synthetic secret must not appear');
    await super.delete();
  }
}

Future<void> frames(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 35)),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  for (final width in [390.0, 1280.0]) {
    for (final failure in [false, true]) {
      testWidgets('explicit logout $width deletion failure=$failure', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 1000);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        SharedPreferences.setMockInitialValues({});
        final prefs = (await tester.runAsync(SharedPreferences.getInstance))!;
        final store = FailingDeleteStore()..fail = failure;
        final calls = <String>[];
        final deps = AppDependencies(
          prefs,
          credentialStore: store,
          clientFactory: () => MockClient((request) async {
            calls.add(request.url.path);
            if (request.url.path == '/public/client-config') {
              return http.Response(
                jsonEncode({'server_url': defaultServerUrl}),
                200,
              );
            }
            if (request.url.path == '/v1/me') {
              return http.Response(
                '{"id":"fixture","label":"Fixture","role":"user","capabilities":{}}',
                200,
              );
            }
            if (request.url.path == '/v1/models') {
              return http.Response('{"data":[]}', 200);
            }
            return http.Response('{}', 200);
          }),
        );
        await tester.pumpWidget(MuseApp(dependencies: deps, requireKey: true));
        await frames(tester);
        await tester.enterText(find.byType(TextField), 'synthetic-valid');
        await tester.tap(find.text('Đăng nhập'));
        await frames(tester);
        expect(find.byType(AppShell), findsOneWidget);
        expect(store.value, isNotNull);
        final bloc = tester
            .element(find.byType(AppShell))
            .read<ConnectionBloc>();
        Future<void> openLogout() async {
          if (width < 800) {
            await tester.tap(find.text('Thêm'));
            await frames(tester);
          }
          await tester.tap(find.text('Đăng xuất'));
          await frames(tester);
        }

        await openLogout();
        expect(find.textContaining('không thu hồi API key'), findsOneWidget);
        await tester.tap(find.text('Ở lại'));
        await frames(tester);
        expect(find.byType(AppShell), findsOneWidget);
        expect(store.deletes, 0);
        await openLogout();
        store.pending = Completer<void>();
        await tester.tap(find.widgetWithText(FilledButton, 'Đăng xuất'));
        await frames(tester);
        expect(find.byType(AppShell), findsNothing);
        expect(find.byType(KeyLoginPage), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
        expect(bloc.state.connection, isNull);
        bloc.add(LogoutRequested());
        bloc.add(ConnectionRequested(defaultServerUrl, 'synthetic-other'));
        await frames(tester);
        expect(store.deletes, 1);
        final atLogout = calls.length;
        store.pending!.complete();
        await frames(tester);
        await tester.pump(const Duration(seconds: 60));
        expect(calls.length, atLogout);
        expect(prefs.getBool('explicit_logout'), true);
        expect(prefs.getString('server_address'), defaultServerUrl);
        if (failure) {
          expect(store.value, isNotNull);
          expect(find.textContaining('chưa xóa được API key'), findsOneWidget);
          expect(find.textContaining('synthetic secret'), findsNothing);
          store.fail = false;
          await tester.tap(find.text('Thử xóa API key lại'));
          await frames(tester);
          expect(store.deletes, 2);
        }
        expect(store.value, isNull);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty,
        );
        await tester.pumpWidget(const SizedBox());
        await frames(tester);
        final beforeReload = calls.length;
        await tester.pumpWidget(MuseApp(dependencies: deps, requireKey: true));
        await frames(tester);
        expect(find.byType(AppShell), findsNothing);
        expect(calls.sublist(beforeReload), ['/public/client-config']);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await frames(tester);
      });
    }
  }

  test('logout marker blocks restoration even if deletion fails', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = FailingDeleteStore();
    final local = ConnectionLocalDataSource(prefs, store);
    await local.saveConnection(
      const ServerConnection(baseUrl: defaultServerUrl, apiKey: 'synthetic'),
    );
    await expectLater(local.forgetConnection(), throwsStateError);
    expect(store.value, isNotNull);
    expect(
      await ConnectionLocalDataSource(prefs, store).readConnection(),
      isNull,
    );
  });

  test('credential writes are serialized before logout deletion', () async {
    SharedPreferences.setMockInitialValues({});
    final store = MemoryCredentialStore();
    final local = ConnectionLocalDataSource(
      await SharedPreferences.getInstance(),
      store,
    );
    final saving = local.saveConnection(
      const ServerConnection(baseUrl: defaultServerUrl, apiKey: 'synthetic'),
    );
    final logout = local.forgetConnection();
    await Future.wait([saving, logout]);
    expect(store.value, isNull);
    expect(await local.readConnection(), isNull);
  });

  test(
    'closed and stale transports cannot send or deliver late rejection',
    () async {
      final pending = Completer<http.Response>();
      var sent = 0;
      var rejected = 0;
      var current = true;
      final client = SessionClient(
        MockClient((request) async {
          sent++;
          return pending.future;
        }),
        (_, _) => rejected++,
        isCurrent: () => current,
      );
      final result = client.get(
        Uri.parse('https://fixture.invalid/v1/tasks'),
        headers: {'Authorization': 'Bearer synthetic'},
      );
      final assertion = expectLater(
        result,
        throwsA(isA<http.ClientException>()),
      );
      await Future<void>.delayed(Duration.zero);
      current = false;
      client.close();
      pending.complete(http.Response('{}', 401));
      await assertion;
      await expectLater(
        client.get(Uri.parse('https://fixture.invalid/v1/tasks')),
        throwsA(isA<http.ClientException>()),
      );
      expect(sent, 1);
      expect(rejected, 0);
    },
  );
}
