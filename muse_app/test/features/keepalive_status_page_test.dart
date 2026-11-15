import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muse_app/features/accounts/domain/entities/keepalive_status.dart';
import 'package:muse_app/features/accounts/presentation/pages/keepalive_status_section.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';

import 'keepalive_status_bloc_test.dart' show StatusRepo, server;

void main() {
  testWidgets(
    'manual read-only section: null, busy, partial results and stale error at narrow large text',
    (t) async {
      final repo = StatusRepo();
      await t.binding.setSurfaceSize(const Size(375, 1100));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.7)),
              child: SingleChildScrollView(
                child: KeepaliveStatusSection(
                  repository: repo,
                  connection: server,
                ),
              ),
            ),
          ),
        ),
      );
      expect(repo.calls, 0);
      expect(find.text('Chưa tải trạng thái.'), findsOneWidget);
      await t.tap(find.text('Tải trạng thái'));
      await t.pump();
      expect(find.text('Đang tải trạng thái…'), findsOneWidget);
      expect(
        t
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Đang tải trạng thái…'),
            )
            .onPressed,
        isNull,
      );
      repo.pending.complete(
        const KeepaliveStatus(
          running: true,
          lastResult: KeepaliveSummary(
            attempts: 3,
            successes: 1,
            failures: 1,
            busy: 1,
            unknown: 1,
            skipped: 2,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Đang chạy trên server'), findsOneWidget);
      expect(find.textContaining('Lần tới (ước tính)'), findsOneWidget);
      expect(find.textContaining('1 thành công'), findsOneWidget);
      expect(find.textContaining('1 thất bại'), findsOneWidget);
      expect(find.textContaining('1 chưa xác định'), findsOneWidget);
      expect(find.textContaining('2 bỏ qua'), findsOneWidget);
      expect(t.takeException(), isNull);
      repo.pending = Completer();
      await t.tap(find.text('Tải trạng thái'));
      await t.pump();
      repo.pending.completeError(Exception('private-cookie'));
      await t.pumpAndSettle();
      expect(find.textContaining('Dữ liệu cũ'), findsOneWidget);
      expect(find.textContaining('private-cookie'), findsNothing);
      expect(find.textContaining('hãy thử tải lại'), findsOneWidget);
    },
  );
  testWidgets('connection replacement drops old snapshot and late response', (
    t,
  ) async {
    final old = StatusRepo();
    final next = StatusRepo();
    Widget app(StatusRepo r, ServerConnection c) => MaterialApp(
      home: Scaffold(
        body: KeepaliveStatusSection(repository: r, connection: c),
      ),
    );
    await t.pumpWidget(app(old, server));
    await t.tap(find.text('Tải trạng thái'));
    await t.pump();
    await t.pumpWidget(
      app(
        next,
        const ServerConnection(
          baseUrl: 'https://other.test',
          apiKey: 'fixture',
        ),
      ),
    );
    old.pending.complete(const KeepaliveStatus(running: true));
    await t.pumpAndSettle();
    expect(find.text('Chưa tải trạng thái.'), findsOneWidget);
    expect(find.text('Đang chạy trên server'), findsNothing);
    expect(next.calls, 0);
  });
}
