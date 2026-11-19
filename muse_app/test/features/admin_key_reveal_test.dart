import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muse_app/core/network/json_api_client.dart';
import 'package:muse_app/features/admin/data/repositories/admin_users_repository_impl.dart';
import 'package:muse_app/features/admin/domain/repositories/admin_users_repository.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muse_app/features/admin/presentation/pages/admin_users_page.dart';
import 'package:muse_app/features/admin/presentation/cubit/admin_users_cubit.dart';

import 'admin_users_test.dart' show FakeUsers, connection, settled;

class RevealUsers extends FakeUsers {
  Completer<String>? revealPending;
  int reveals = 0;
  bool legacy = false;
  bool failReveal = false;
  @override
  Future<List<AdminUser>> list(dynamic connection) async => [
    AdminUser(
      id: "fixture-user",
      label: "Fixture user",
      enabled: true,
      keyRevealable: !legacy,
    ),
  ];
  @override
  Future<String> reveal(dynamic connection, String id) async {
    reveals++;
    if (failReveal) throw Exception("sensitive-secret");
    return revealPending?.future ?? 'synthetic-existing-key';
  }
}

void main() {
  testWidgets(
    'backgrounding hides revealed key and late response stays hidden',
    (tester) async {
      final repo = RevealUsers();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminUsersPage(repository: repo, connection: connection()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xem key'));
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();
      expect(find.text('synthetic-existing-key'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      repo.revealPending = Completer<String>();
      await tester.tap(find.text('Xem key'));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      repo.revealPending!.complete('late-background-secret');
      await tester.pumpAndSettle();
      expect(find.text('late-background-secret'), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    },
  );

  for (final width in [390.0, 1280.0]) {
    testWidgets('revealed row visual at $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = RevealUsers();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RepaintBoundary(
              key: const ValueKey('capture'),
              child: AdminUsersPage(repository: repo, connection: connection()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xem key'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
      expect(find.text('synthetic-existing-key'), findsOneWidget);
      expect(find.byTooltip('Sao chép API key'), findsOneWidget);
      expect(find.text('Ẩn key'), findsOneWidget);
    });
  }
  test(
    'repository reveals via POST, escapes ID and denies nonadmin before IO',
    () async {
      final calls = <http.Request>[];
      final repo = AdminUsersRepositoryImpl(
        JsonApiClient(
          () => MockClient((request) async {
            calls.add(request);
            return http.Response(
              jsonEncode({'api_key': 'synthetic-existing-key'}),
              200,
            );
          }),
        ),
      );
      expect(await repo.reveal(connection(), 'u/a'), 'synthetic-existing-key');
      expect(calls.single.method, 'POST');
      expect(
        calls.single.url.toString(),
        endsWith('/admin/users/u%2Fa/key/reveal'),
      );
      for (final denied in [
        connection(role: 'user'),
        connection(capability: false),
      ]) {
        await expectLater(repo.reveal(denied, 'u'), throwsA(anything));
      }
      expect(calls, hasLength(1));
    },
  );

  test(
    'hide cancels pending reveal and errors do not expose secrets',
    () async {
      final repo = RevealUsers()..revealPending = Completer<String>();
      final cubit = AdminUsersCubit(repo)..connect(connection());
      await settled();
      final request = cubit.reveal(cubit.state.users.single);
      cubit.dismissKey();
      repo.revealPending!.complete('late-secret');
      await request;
      expect(cubit.state.revealedKey, null);
      expect(cubit.state.mutating, false);
      repo.failReveal = true;
      await cubit.reveal(cubit.state.users.single);
      expect(cubit.state.error, isNot(contains('sensitive')));
      cubit.connect(connection(role: 'user'));
      await cubit.reveal(const AdminUser(id: 'u', label: 'U', enabled: true));
      expect(repo.reveals, 2);
      await cubit.close();
    },
  );

  testWidgets(
    'legacy shows rotate guidance without reveal and rotation still confirms',
    (tester) async {
      final repo = RevealUsers()..legacy = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminUsersPage(repository: repo, connection: connection()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Xem key'), findsNothing);
      expect(find.textContaining('Không thể xem key cũ'), findsOneWidget);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đổi key'));
      await tester.pumpAndSettle();
      expect(find.text('Đổi API key?'), findsOneWidget);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(repo.mutations, 0);
      expect(repo.reveals, 0);
    },
  );

  test(
    'reveal is explicit, hide and session change discard late secrets',
    () async {
      final repo = RevealUsers();
      final cubit = AdminUsersCubit(repo)..connect(connection());
      await settled();
      expect(repo.reveals, 0);
      await cubit.reveal(cubit.state.users.single);
      expect(cubit.state.revealedKey, 'synthetic-existing-key');
      cubit.dismissKey();
      expect(cubit.state.revealedKey, null);
      repo.revealPending = Completer<String>();
      final request = cubit.reveal(cubit.state.users.single);
      cubit.connect(null);
      repo.revealPending!.complete('late-secret');
      await request;
      expect(cubit.state.revealedKey, null);
      await cubit.close();
    },
  );

  testWidgets('existing row key reveals copies and hides without rotation', (
    tester,
  ) async {
    final repo = RevealUsers();
    final writes = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          writes.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminUsersPage(repository: repo, connection: connection()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('synthetic-existing-key'), findsNothing);
    await tester.tap(find.text('Xem key'));
    await tester.pumpAndSettle();
    expect(find.text('synthetic-existing-key'), findsOneWidget);
    await tester.tap(find.byTooltip('Sao chép API key'));
    await tester.pumpAndSettle();
    expect(writes, ['synthetic-existing-key']);
    await tester.tap(find.text('Ẩn key'));
    await tester.pumpAndSettle();
    expect(find.text('synthetic-existing-key'), findsNothing);
    expect(repo.mutations, 0);
  });
}
