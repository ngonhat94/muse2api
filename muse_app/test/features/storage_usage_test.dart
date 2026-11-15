import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:muse_app/features/media/domain/repositories/storage_repository.dart';
import 'package:muse_app/features/media/domain/entities/storage_usage.dart';
import 'package:muse_app/features/media/presentation/pages/storage_usage_panel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muse_app/core/network/json_api_client.dart';
import 'package:muse_app/features/media/data/repositories/media_repository_impl.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';

class FixtureStorage implements StorageRepository {
  int calls = 0;
  Future<StorageUsage> Function() response = () async => const StorageUsage(
    bytes: 17,
    files: 1,
    limitBytes: 100,
    limitFiles: 3,
    retentionDays: 30,
  );
  @override
  Future<StorageUsage> loadStorage(ServerConnection c) {
    calls++;
    return response();
  }
}

ServerConnection owner({bool allowed = true}) =>
    ServerConnection(baseUrl: 'https://fixture.invalid', apiKey: 'synthetic')
      ..attachPrincipal(
        ServerPrincipal(
          id: 'fixture',
          label: 'fixture',
          role: 'user',
          capabilities: {'media': allowed},
        ),
      );
void main() {
  testWidgets('storage requires manual refresh and clears on identity change', (
    tester,
  ) async {
    final repo = FixtureStorage();
    final c = owner();
    Future<void> show(ServerConnection? connection) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StorageUsagePanel(connection: connection, repository: repo),
        ),
      ),
    );
    await show(c);
    expect(repo.calls, 0);
    expect(find.textContaining('Chưa tải'), findsOneWidget);
    await tester.tap(find.text('Làm mới lưu trữ'));
    await tester.pumpAndSettle();
    expect(repo.calls, 1);
    expect(find.textContaining('17 / 100 bytes'), findsOneWidget);
    await show(owner());
    expect(find.textContaining('17 / 100 bytes'), findsNothing);
    await show(owner(allowed: false));
    expect(find.text('Làm mới lưu trữ'), findsNothing);
    expect(repo.calls, 1);
  });
  testWidgets(
    'late storage response cannot cross identity; errors never expose bodies',
    (tester) async {
      final repo = FixtureStorage();
      final pending = Completer<StorageUsage>();
      repo.response = () => pending.future;
      Future<void> show(ServerConnection? c) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StorageUsagePanel(connection: c, repository: repo),
          ),
        ),
      );
      await show(owner());
      await tester.tap(find.text('Làm mới lưu trữ'));
      await tester.pump();
      await show(owner());
      pending.complete(
        const StorageUsage(
          bytes: 999,
          files: 1,
          limitBytes: 1000,
          limitFiles: 3,
          retentionDays: 30,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('999'), findsNothing);
      repo.response = () async => throw Exception('secret-cookie');
      await tester.tap(find.text('Làm mới lưu trữ'));
      await tester.pumpAndSettle();
      expect(find.textContaining('secret-cookie'), findsNothing);
      expect(find.textContaining('Không tải được'), findsOneWidget);
    },
  );
  for (final status in [401, 403, 404, 429, 507, 503]) {
    testWidgets('HTTP $status storage failure stays safe without retries', (
      tester,
    ) async {
      var calls = 0;
      final repo = MediaRepositoryImpl(
        JsonApiClient(
          () => MockClient((_) async {
            calls++;
            return http.Response('{"detail":"secret-cookie"}', status);
          }),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StorageUsagePanel(connection: owner(), repository: repo),
          ),
        ),
      );
      await tester.tap(find.text('Làm mới lưu trữ'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.textContaining('secret-cookie'), findsNothing);
      expect(find.textContaining(' / '), findsNothing);
      expect(find.text('Làm mới lưu trữ'), findsOneWidget);
    });
  }
  for (final bad in [null, -1, 1.5, 'secret-cookie', true]) {
    test('malformed storage value $bad fails closed', () async {
      final repo = MediaRepositoryImpl(
        JsonApiClient(
          () => MockClient(
            (_) async => http.Response(
              jsonEncode({
                'bytes': bad,
                'files': 0,
                'limits': {'bytes': 100, 'files': 3, 'retention_days': 30},
              }),
              200,
            ),
          ),
        ),
      );
      await expectLater(repo.loadStorage(owner()), throwsFormatException);
    });
  }
  testWidgets('narrow large-text storage remains operable', (tester) async {
    tester.view.resetPhysicalSize();
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = owner();
    final repo = FixtureStorage();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: StorageUsagePanel(connection: c, repository: repo),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Làm mới lưu trữ'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  test(
    'own storage is GET only and returns validated numeric snapshot',
    () async {
      final connection = ServerConnection(
        baseUrl: 'https://fixture.invalid',
        apiKey: 'synthetic',
      );
      final dynamic repo = MediaRepositoryImpl(
        JsonApiClient(
          () => MockClient((r) async {
            expect(r.method, 'GET');
            expect(r.url.path, '/v1/storage');
            expect(r.url.query, isEmpty);
            return http.Response(
              jsonEncode({
                'bytes': 17,
                'files': 1,
                'limits': {'bytes': 100, 'files': 3, 'retention_days': 30},
              }),
              200,
            );
          }),
        ),
      );
      final usage = await repo.loadStorage(connection);
      expect(usage.bytes, 17);
      expect(usage.limitBytes, 100);
    },
  );
}
