import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muse_app/features/accounts/domain/entities/muse_account.dart';
import 'package:muse_app/features/accounts/domain/usecases/manage_accounts.dart';
import 'package:muse_app/features/accounts/domain/usecases/manage_proxy.dart';
import 'package:muse_app/features/accounts/presentation/bloc/account_bloc.dart';
import 'package:muse_app/features/accounts/presentation/pages/account_page.dart';
import 'package:muse_app/features/connection/presentation/bloc/connection_bloc.dart';

import 'account_cookies_page_test.dart' show Connect, Proxy;
import 'account_keepalive_bloc_test.dart' show KeepaliveRepo;

void main() {
  testWidgets(
    'all quota fields wrap at 320 with large text; load never probes quota',
    (t) async {
      t.view.physicalSize = const Size(320, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final r = KeepaliveRepo()
        ..items = [
          MuseAccount(
            id: 'a',
            label: 'A',
            enabled: true,
            plan: 'Free plan',
            weeklyUsed: 12.5,
            weeklyReset: 'Sep 30',
            extraUsed: 0,
            extraLeft: '2B tokens left',
            extraExpires: 'never',
            quotaCheckedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
          ),
        ];
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
            child: MaterialApp(
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(2)),
                child: child!,
              ),
              home: const Scaffold(body: AccountPage()),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('Gói: Free plan'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      for (final text in [
        'Gói: Free plan',
        'Tuần: đã dùng 12.5% · còn 87.5%',
        'Đặt lại tuần: Sep 30',
        'Token bổ sung còn lại: 2B tokens left',
        'Bổ sung: đã dùng 0% · còn 100%',
        'Hết hạn bổ sung: never',
        'Dữ liệu lưu đệm · không tự làm mới',
      ]) {
        expect(find.text(text), findsOneWidget);
      }
      expect(find.textContaining('Quota cập nhật:'), findsOneWidget);
      expect(r.calls, 0);
      expect(t.takeException(), isNull);
      r.items = [
        const MuseAccount(
          id: 'a',
          label: 'A',
          enabled: true,
          plan: 'Free plan',
        ),
      ];
      b.add(AccountsLoaded(c.state.connection!));
      await t.pumpAndSettle();
      expect(find.text('Tuần: chưa có dữ liệu'), findsOneWidget);
      expect(
        find.text('Token bổ sung còn lại: chưa có dữ liệu'),
        findsOneWidget,
      );
      expect(
        find.text('Chưa xác nhận lần đọc quota thành công'),
        findsOneWidget,
      );
      expect(find.textContaining('0%'), findsNothing);
      expect(t.takeException(), isNull);
      await t.ensureVisible(find.widgetWithText(TextButton, 'Quota'));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(TextButton, 'Quota'));
      await t.pumpAndSettle();
      expect(r.calls, 1);
    },
  );
}
