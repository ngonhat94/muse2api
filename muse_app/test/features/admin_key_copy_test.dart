import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muse_app/features/admin/presentation/pages/admin_users_page.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';

import 'admin_users_test.dart' show FakeUsers, connection;

void main() {
  Future<void> mount(
    WidgetTester tester,
    FakeUsers repository,
    ServerConnection? session,
  ) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AdminUsersPage(repository: repository, connection: session),
      ),
    ),
  );

  Future<void> create(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField), 'Synthetic fixture');
    await tester.tap(find.text('Tạo user & key'));
    await tester.pumpAndSettle();
  }

  for (final width in [375.0, 1280.0]) {
    for (final rotate in [false, true]) {
      testWidgets(
        '${rotate ? 'rotated' : 'created'} key copies once with truthful feedback at $width',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final writes = <String>[];
          final pending = Completer<void>();
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            (call) async {
              if (call.method == 'Clipboard.setData') {
                writes.add((call.arguments as Map)['text'] as String);
                await pending.future;
              }
              return null;
            },
          );
          addTearDown(
            () => tester.binding.defaultBinaryMessenger
                .setMockMethodCallHandler(SystemChannels.platform, null),
          );
          final repository = FakeUsers();
          await mount(tester, repository, connection());
          await tester.pumpAndSettle();
          if (rotate) {
            await tester.tap(find.byType(PopupMenuButton<String>));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Đổi key'));
            await tester.pumpAndSettle();
            await tester.tap(find.text('Xác nhận'));
            await tester.pumpAndSettle();
          } else {
            await create(tester);
          }
          expect(writes, isEmpty);
          final copy = find.byTooltip('Sao chép API key');
          expect(copy, findsOneWidget);
          final key = find.text('fixture-one-time-key');
          expect(find.byType(SelectableText), findsOneWidget);
          expect(
            tester.getRect(copy).left,
            greaterThan(tester.getRect(key).right),
          );
          await tester.tap(copy);
          await tester.pump();
          await tester.tap(copy);
          await tester.pump();
          expect(writes, ['fixture-one-time-key']);
          expect(find.text('Đã sao chép API key'), findsNothing);
          pending.complete();
          await tester.pumpAndSettle();
          expect(find.text('Đã sao chép API key'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'clipboard denial keeps selectable fallback and allows retry without false success',
    (tester) async {
      var fail = true;
      var writes = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            writes++;
            expect((call.arguments as Map)['text'], 'fixture-one-time-key');
            if (fail) {
              throw PlatformException(
                code: 'denied',
                message: 'sensitive platform details',
              );
            }
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
      await mount(tester, FakeUsers(), connection());
      await tester.pumpAndSettle();
      await create(tester);
      await tester.tap(find.byTooltip('Sao chép API key'));
      await tester.pumpAndSettle();
      expect(find.text('Đã sao chép API key'), findsNothing);
      expect(
        find.text(
          'Không thể sao chép API key. Hãy chọn key và sao chép thủ công.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('sensitive platform'), findsNothing);
      expect(find.byType(SelectableText), findsOneWidget);
      fail = false;
      await tester.pump(const Duration(seconds: 5));
      await tester.tap(find.byTooltip('Sao chép API key'));
      await tester.pumpAndSettle();
      expect(writes, 2);
      expect(find.text('Đã sao chép API key'), findsOneWidget);
    },
  );

  for (final transition in ['hide', 'replace', 'logout', 'dispose']) {
    for (final fail in [false, true]) {
      testWidgets(
        'late clipboard ${fail ? 'error' : 'success'} ignored after $transition',
        (tester) async {
          final pending = Completer<void>();
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            (call) async {
              if (call.method == 'Clipboard.setData') await pending.future;
              return null;
            },
          );
          addTearDown(
            () => tester.binding.defaultBinaryMessenger
                .setMockMethodCallHandler(SystemChannels.platform, null),
          );
          final repository = FakeUsers();
          await mount(tester, repository, connection());
          await tester.pumpAndSettle();
          await create(tester);
          await tester.tap(find.byTooltip('Sao chép API key'));
          await tester.pump();
          if (transition == 'hide') {
            await tester.tap(find.text('Đã lưu, ẩn key'));
          } else if (transition == 'dispose') {
            await tester.pumpWidget(
              const MaterialApp(home: Scaffold(body: Text('Another page'))),
            );
          } else {
            await mount(
              tester,
              repository,
              transition == 'logout' ? null : connection(),
            );
          }
          await tester.pump();
          if (fail) {
            pending.completeError(PlatformException(code: 'denied'));
          } else {
            pending.complete();
          }
          await tester.pumpAndSettle();
          expect(find.byType(SnackBar), findsNothing);
          expect(find.text('fixture-one-time-key'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
