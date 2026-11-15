import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muse_app/features/accounts/domain/usecases/manage_accounts.dart';
import 'package:muse_app/features/accounts/domain/usecases/manage_proxy.dart';
import 'package:muse_app/features/accounts/domain/repositories/proxy_repository.dart';
import 'package:muse_app/features/accounts/presentation/bloc/account_bloc.dart';
import 'package:muse_app/features/accounts/presentation/pages/account_page.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';
import 'package:muse_app/features/connection/domain/usecases/connect_server.dart';
import 'package:muse_app/features/connection/presentation/bloc/connection_bloc.dart';

import 'account_cookies_bloc_test.dart' show CookiesRepo;

class Connect implements ConnectServer {
  @override
  Future<ServerConnection> call(String address, String key) async =>
      ServerConnection(baseUrl: address, apiKey: key);
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class Proxy implements ProxyRepository {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  testWidgets(
    'account cookie action sends once and a dialog from an old server cannot submit',
    (t) async {
      final repo = CookiesRepo();
      final connection = ConnectionBloc(Connect());
      final accounts = AccountBloc(ManageAccounts(repo));
      addTearDown(connection.close);
      addTearDown(accounts.close);
      connection.add(ConnectionRequested('https://example.com', 'fixture'));
      await t.pump();
      accounts.add(AccountsLoaded(connection.state.connection!));
      await t.pumpWidget(
        RepositoryProvider(
          create: (_) => ManageProxy(Proxy()),
          child: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: connection),
              BlocProvider.value(value: accounts),
            ],
            child: const MaterialApp(home: Scaffold(body: AccountPage())),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Cập nhật cookie'));
      await t.tap(find.text('Cập nhật cookie'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'x=y');
      await t.tap(find.widgetWithText(FilledButton, 'Cập nhật cookie'));
      await t.pumpAndSettle();
      expect(repo.calls, 1);
      await t.ensureVisible(find.text('Cập nhật cookie'));
      await t.tap(find.text('Cập nhật cookie'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), 'x=y');
      connection.add(
        ConnectionRequested('https://other.example.com', 'fixture'),
      );
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(FilledButton, 'Cập nhật cookie'));
      await t.pumpAndSettle();
      expect(repo.calls, 1);
    },
  );
}
