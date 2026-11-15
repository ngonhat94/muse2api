import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muse_app/features/accounts/domain/entities/keepalive_status.dart';
import 'package:muse_app/features/accounts/domain/repositories/batch_keepalive_repository.dart';
import 'package:muse_app/features/accounts/domain/repositories/keepalive_status_repository.dart';
import 'package:muse_app/features/accounts/domain/usecases/manage_accounts.dart';
import 'package:muse_app/features/accounts/domain/usecases/manage_proxy.dart';
import 'package:muse_app/features/accounts/presentation/bloc/account_bloc.dart';
import 'package:muse_app/features/accounts/presentation/pages/account_page.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';
import 'package:muse_app/features/connection/presentation/bloc/connection_bloc.dart';

import 'account_cookies_page_test.dart' show Connect, Proxy;
import 'account_batch_keepalive_bloc_test.dart' show BatchRepo;

class PageRepo extends BatchRepo implements KeepaliveStatusRepository {
  int statuses = 0;
  bool statusFails = false;
  @override
  Future<KeepaliveStatus> keepaliveStatus(ServerConnection c) async {
    statuses++;
    if (statusFails) throw StateError('private-status');
    return const KeepaliveStatus(running: false);
  }
}

Future<void> mount(
  WidgetTester t,
  PageRepo r,
  ConnectionBloc c,
  AccountBloc b,
) async {
  c.add(ConnectionRequested('https://example.com', 'fixture'));
  await t.pump();
  b.add(AccountsLoaded(c.state.connection!));
  await t.pumpWidget(
    RepositoryProvider(
      create: (_) => ManageProxy(Proxy()),
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: c),
          BlocProvider.value(value: b),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: const Scaffold(body: AccountPage()),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

Future<void> open(WidgetTester t) async {
  await t.ensureVisible(find.text('Duy trì phiên hàng loạt'));
  await t.tap(find.text('Duy trì phiên hàng loạt'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'busy does not refresh; reload error keeps completed batch outcome',
    (t) async {
      final r = PageRepo()..batchBusy = true;
      final c = ConnectionBloc(Connect());
      final b = AccountBloc(ManageAccounts(r));
      addTearDown(c.close);
      addTearDown(b.close);
      await mount(t, r, c, b);
      await open(t);
      await t.tap(find.widgetWithText(FilledButton, 'Chạy đợt duy trì phiên'));
      await t.pumpAndSettle();
      expect(r.statuses, 0);
      expect(r.lists, 1);
      expect(b.state.message, isNull);
      r.batchBusy = false;
      r.statusFails = true;
      await open(t);
      await t.tap(find.widgetWithText(FilledButton, 'Chạy đợt duy trì phiên'));
      await t.pumpAndSettle();
      expect(r.statuses, 1);
      expect(b.state.message, contains('1 thành công · 1 thất bại'));
      await t.scrollUntilVisible(
        find.textContaining('Không tải được trạng thái.'),
        150,
      );
      expect(find.textContaining('Không tải được trạng thái.'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'in-flight batch disables mutations and suppresses late result after server switch',
    (t) async {
      final r = PageRepo()..batchPending = Completer<BatchKeepaliveResult>();
      final c = ConnectionBloc(Connect());
      final b = AccountBloc(ManageAccounts(r));
      addTearDown(c.close);
      addTearDown(b.close);
      await mount(t, r, c, b);
      await open(t);
      await t.tap(find.widgetWithText(FilledButton, 'Chạy đợt duy trì phiên'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(
        t
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Duy trì phiên hàng loạt'),
            )
            .onPressed,
        isNull,
      );
      c.add(ConnectionRequested('https://other.example', 'fixture'));
      b.add(AccountsCleared());
      await t.pump();
      r.batchPending!.complete(
        const BatchKeepaliveResult(
          summary: KeepaliveSummary(
            attempts: 1,
            successes: 1,
            failures: 0,
            unknown: 0,
            busy: 0,
            skipped: 0,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(b.state.message, isNull);
      expect(r.statuses, 0);
      expect(r.batches, 1);
    },
  );
  testWidgets(
    'manual batch confirmation cancel and completion refresh at narrow large text',
    (t) async {
      t.view.physicalSize = const Size(390, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final r = PageRepo();
      final c = ConnectionBloc(Connect());
      final b = AccountBloc(ManageAccounts(r));
      addTearDown(c.close);
      addTearDown(b.close);
      await mount(t, r, c, b);
      expect(r.batches, 0);
      expect(r.statuses, 0);
      await open(t);
      expect(find.textContaining('chính sách server'), findsOneWidget);
      expect(find.textContaining('cookie và proxy đã lưu'), findsOneWidget);
      expect(find.textContaining('đánh thức workspace'), findsOneWidget);
      expect(find.textContaining('mất nhiều thời gian'), findsOneWidget);
      await t.tap(find.text('Hủy'));
      await t.pumpAndSettle();
      expect(r.batches, 0);
      await open(t);
      await t.tap(find.widgetWithText(FilledButton, 'Chạy đợt duy trì phiên'));
      await t.pumpAndSettle();
      expect(r.batches, 1);
      expect(r.lists, 2);
      expect(r.statuses, 1);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('credential change invalidates confirmation', (t) async {
    final r = PageRepo();
    final c = ConnectionBloc(Connect());
    final b = AccountBloc(ManageAccounts(r));
    addTearDown(c.close);
    addTearDown(b.close);
    await mount(t, r, c, b);
    await open(t);
    c.add(ConnectionRequested('https://example.com', 'changed-fixture'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Chạy đợt duy trì phiên'));
    await t.pumpAndSettle();
    expect(r.batches, 0);
  });
}
