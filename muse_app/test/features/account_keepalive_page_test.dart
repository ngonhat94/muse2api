import 'package:flutter/material.dart';
import 'package:muse_app/features/accounts/domain/entities/muse_account.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muse_app/features/accounts/domain/usecases/manage_accounts.dart';
import 'package:muse_app/features/accounts/domain/usecases/manage_proxy.dart';
import 'package:muse_app/features/accounts/presentation/bloc/account_bloc.dart';
import 'package:muse_app/features/accounts/presentation/pages/account_page.dart';
import 'package:muse_app/features/connection/presentation/bloc/connection_bloc.dart';

import 'account_cookies_page_test.dart' show Connect, Proxy;
import 'account_keepalive_bloc_test.dart' show KeepaliveRepo;

void main() {
  testWidgets(
    'native confirmation explains routing; cancel never posts, confirm sends once, stale dialog cannot send',
    (t) async {
      final r = KeepaliveRepo();
      final c = ConnectionBloc(Connect());
      final b = AccountBloc(ManageAccounts(r));
      addTearDown(c.close);
      addTearDown(b.close);
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
            child: const MaterialApp(home: Scaffold(body: AccountPage())),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(r.calls, 0);
      Future<void> open() async {
        await t.ensureVisible(find.text('Duy trì phiên'));
        await t.tap(find.text('Duy trì phiên'));
        await t.pumpAndSettle();
      }

      await open();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('cookie và proxy đã lưu'), findsOneWidget);
      expect(find.textContaining('đánh thức workspace'), findsOneWidget);
      expect(r.calls, 0);
      await t.tap(find.text('Hủy'));
      await t.pumpAndSettle();
      expect(r.calls, 0);
      await open();
      await t.tap(find.widgetWithText(FilledButton, 'Duy trì phiên'));
      await t.pumpAndSettle();
      expect(r.calls, 1);
      await open();
      r.items = [];
      b.add(AccountsLoaded(c.state.connection!));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Duy trì phiên'));
      await t.pumpAndSettle();
      expect(r.calls, 1);
      r.items = [const MuseAccount(id: 'a', label: 'A', enabled: true)];
      b.add(AccountsLoaded(c.state.connection!));
      await t.pumpAndSettle();
      await open();
      c.add(ConnectionRequested('https://other.example', 'fixture'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Duy trì phiên'));
      await t.pumpAndSettle();
      expect(r.calls, 1);
    },
  );
}
