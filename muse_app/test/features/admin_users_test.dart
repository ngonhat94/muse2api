import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muse_app/app/app.dart';
import 'package:muse_app/app/dependencies.dart';
import 'package:muse_app/features/connection/presentation/bloc/connection_bloc.dart';

import '../support/memory_credential_store.dart';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muse_app/core/network/json_api_client.dart';
import 'package:muse_app/features/admin/data/repositories/admin_users_repository_impl.dart';
import 'package:muse_app/features/admin/domain/repositories/admin_users_repository.dart';
import 'package:muse_app/features/admin/presentation/cubit/admin_users_cubit.dart';
import 'package:muse_app/features/admin/presentation/pages/admin_users_page.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';

ServerConnection connection({
  String role = 'admin',
  bool capability = true,
  bool local = false,
}) {
  final value = ServerConnection(
    baseUrl: 'https://fixture.invalid',
    apiKey: 'synthetic-only',
    isLocal: local,
  );
  value.attachPrincipal(
    ServerPrincipal(
      id: 'fixture',
      label: 'Fixture',
      role: role,
      capabilities: {'manage_users': capability},
    ),
  );
  return value;
}

class FakeUsers implements AdminUsersRepository {
  int mutations = 0;
  int reads = 0;
  Completer<String>? pending;
  bool fail = false;
  @override
  Future<List<AdminUser>> list(ServerConnection connection) async {
    reads++;
    if (fail) throw Exception('sensitive raw error');
    return [
      const AdminUser(id: 'fixture-user', label: 'Fixture user', enabled: true),
    ];
  }

  @override
  Future<String> create(ServerConnection connection, String label) async {
    mutations++;
    return pending?.future ?? Future.value('fixture-one-time-key');
  }

  @override
  Future<String> rotate(ServerConnection connection, String id) =>
      create(connection, id);
  @override
  Future<void> revoke(ServerConnection connection, String id) async {
    mutations++;
  }

  @override
  Future<void> setEnabled(
    ServerConnection connection,
    String id,
    bool enabled,
  ) async {
    mutations++;
  }
}

Future<void> settled() => Future<void>.delayed(Duration.zero);

void main() {
  testWidgets('admin destination is gated on desktop and mobile', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [1280.0, 390.0]) {
      for (final permission in [
        (role: 'admin', capability: true),
        (role: 'admin', capability: false),
        (role: 'user', capability: true),
      ]) {
        tester.view.physicalSize = Size(width, 844);
        final dependencies = AppDependencies(
          preferences,
          credentialStore: MemoryCredentialStore(),
          clientFactory: () => MockClient((request) async {
            final body = request.url.path == '/v1/models'
                ? {'data': []}
                : request.url.path == '/v1/me'
                ? {
                    'id': 'fixture',
                    'label': 'Fixture',
                    'role': permission.role,
                    'capabilities': {'manage_users': permission.capability},
                  }
                : request.url.path == '/admin/users'
                ? {'users': []}
                : <String, Object?>{};
            return http.Response(jsonEncode(body), 200);
          }),
        );
        await tester.pumpWidget(MuseApp(dependencies: dependencies));
        await tester.pumpAndSettle();
        final shellContext = tester.element(find.byType(Scaffold).first);
        shellContext.read<ConnectionBloc>().add(
          ConnectionRequested('https://fixture.invalid', 'synthetic-only'),
        );
        await tester.runAsync(() async {
          for (var attempt = 0; attempt < 100; attempt++) {
            if (shellContext.read<ConnectionBloc>().state.status !=
                    ConnectionStatus.connecting &&
                shellContext.read<ConnectionBloc>().state.connection != null)
              break;
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
        });
        await tester.pump(const Duration(milliseconds: 300));
        expect(shellContext.read<ConnectionBloc>().state.connection, isNotNull);
        if (width < 800) {
          await tester.tap(find.text('Thêm'));
          await tester.pump(const Duration(seconds: 1));
        }
        if (width >= 800) {
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -900),
          );
          await tester.pump(const Duration(milliseconds: 300));
        }
        expect(
          find.widgetWithText(ListTile, 'Người dùng & API key'),
          permission.role == 'admin' && permission.capability
              ? findsOneWidget
              : findsNothing,
        );
        expect(tester.takeException(), null);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    }
  });
  test('permission requires admin AND capability; local is not a bypass', () {
    expect(canManageUsers(null), false);
    expect(canManageUsers(connection(role: 'user')), false);
    expect(canManageUsers(connection(capability: false, local: true)), false);
    expect(canManageUsers(connection()), true);
  });

  test('repository uses exact methods, bodies and escaped user IDs', () async {
    final calls = <http.Request>[];
    final repository = AdminUsersRepositoryImpl(
      JsonApiClient(
        () => MockClient((request) async {
          calls.add(request);
          return http.Response(
            jsonEncode(
              request.method == 'GET'
                  ? {
                      'users': [
                        {'id': 'u', 'label': 'Fixture', 'enabled': true},
                      ],
                    }
                  : {'api_key': 'fixture-key'},
            ),
            200,
          );
        }),
      ),
    );
    final admin = connection();
    expect((await repository.list(admin)).single.label, 'Fixture');
    expect(await repository.create(admin, 'Name'), 'fixture-key');
    await repository.rotate(admin, 'u/a');
    await repository.setEnabled(admin, 'u/a', false);
    await repository.revoke(admin, 'u/a');
    expect(calls.map((call) => call.method), [
      'GET',
      'POST',
      'POST',
      'PATCH',
      'DELETE',
    ]);
    expect(jsonDecode(calls[1].body), {'label': 'Name'});
    expect(jsonDecode(calls[3].body), {'enabled': false});
    expect(calls[2].url.toString(), endsWith('/admin/users/u%2Fa/key'));
    await expectLater(
      repository.list(connection(role: 'user')),
      throwsA(anything),
    );
    expect(calls.length, 5);
  });

  test(
    'create, rotate, enable and revoke refresh; key can be dismissed',
    () async {
      final repository = FakeUsers();
      final cubit = AdminUsersCubit(repository)..connect(connection());
      await settled();
      await cubit.create('Fixture');
      expect(cubit.state.oneTimeKey, 'fixture-one-time-key');
      cubit.dismissKey();
      expect(cubit.state.oneTimeKey, null);
      await cubit.rotate(cubit.state.users.single);
      expect(cubit.state.oneTimeKey, 'fixture-one-time-key');
      await cubit.toggle(cubit.state.users.single);
      expect(cubit.state.oneTimeKey, null);
      await cubit.revoke(cubit.state.users.single);
      expect(repository.mutations, 4);
      expect(repository.reads, 5);
      await cubit.close();
    },
  );

  test(
    'disconnect discards in-flight key and connection can load again',
    () async {
      final repository = FakeUsers()..pending = Completer<String>();
      final cubit = AdminUsersCubit(repository)..connect(connection());
      await settled();
      final creating = cubit.create('Fixture');
      await cubit.create('Duplicate');
      expect(repository.mutations, 1);
      cubit.connect(null);
      repository.pending!.complete('late-secret-fixture');
      await creating;
      expect(cubit.state.oneTimeKey, null);
      expect(cubit.state.users, isEmpty);
      expect(cubit.state.mutating, false);
      cubit.connect(connection());
      await settled();
      expect(cubit.state.users, hasLength(1));
      await cubit.close();
    },
  );

  test('errors are sanitized and list can retry', () async {
    final repository = FakeUsers()..fail = true;
    final cubit = AdminUsersCubit(repository)..connect(connection());
    await settled();
    expect(cubit.state.error, isNot(contains('sensitive')));
    repository.fail = false;
    await cubit.load();
    expect(cubit.state.error, null);
    expect(cubit.state.users, hasLength(1));
    await cubit.close();
  });

  testWidgets('narrow layout and destructive cancellation make no mutation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeUsers();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminUsersPage(
            repository: repository,
            connection: connection(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), null);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tắt'));
    await tester.pumpAndSettle();
    expect(find.text('Tắt người dùng?'), findsOneWidget);
    await tester.tap(find.text('Hủy'));
    await tester.pumpAndSettle();
    expect(repository.mutations, 0);
  });

  testWidgets('unauthorized page never loads users', (tester) async {
    final repository = FakeUsers();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminUsersPage(
            repository: repository,
            connection: connection(role: 'user'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.reads, 0);
    expect(find.text('Bạn không có quyền quản lý người dùng.'), findsOneWidget);
  });
}
