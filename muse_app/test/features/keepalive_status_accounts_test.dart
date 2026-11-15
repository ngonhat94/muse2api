import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muse_app/core/network/json_api_client.dart';
import 'package:muse_app/features/accounts/data/repositories/account_repository_impl.dart';
import 'package:muse_app/features/accounts/domain/usecases/manage_accounts.dart';
import 'package:muse_app/features/accounts/presentation/bloc/account_bloc.dart';
import 'package:muse_app/features/accounts/presentation/pages/account_page.dart';
import 'package:muse_app/features/connection/presentation/bloc/connection_bloc.dart';

import 'account_cookies_page_test.dart' show Connect;

void main() {
  testWidgets(
    'accounts exposes status manually without POST or entry requests and clears on disconnect',
    (t) async {
      final requests = <http.Request>[];
      final repo = AccountRepositoryImpl(
        JsonApiClient(
          () => MockClient((r) async {
            requests.add(r);
            return http.Response('{"running":false,"last_result":null}', 200);
          }),
        ),
      );
      final c = ConnectionBloc(Connect());
      final b = AccountBloc(ManageAccounts(repo));
      addTearDown(c.close);
      addTearDown(b.close);
      c.add(ConnectionRequested('https://example.test', 'fixture'));
      await t.pump();
      await t.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: c),
            BlocProvider.value(value: b),
          ],
          child: const MaterialApp(home: Scaffold(body: AccountPage())),
        ),
      );
      await t.pumpAndSettle();
      expect(requests, isEmpty);
      await t.tap(find.text('Tải trạng thái'));
      await t.pumpAndSettle();
      expect(requests.single.method, 'GET');
      expect(requests.single.url.path, '/admin/keepalive/status');
      expect(find.text('Không chạy tại thời điểm tải'), findsOneWidget);
      c.add(ConnectionRequested('https://other.test', 'fixture'));
      await t.pumpAndSettle();
      expect(find.text('Chưa tải trạng thái.'), findsOneWidget);
      expect(requests.length, 1);
    },
  );
}
