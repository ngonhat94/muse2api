import 'package:muse_app/features/accounts/domain/repositories/extension_download.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muse_app/app/dependencies.dart';
import 'package:muse_app/features/accounts/domain/repositories/browser_account_import.dart';
import 'package:muse_app/features/accounts/domain/usecases/manage_accounts.dart';
import 'package:muse_app/features/accounts/presentation/bloc/account_bloc.dart';
import 'package:muse_app/features/accounts/presentation/pages/account_page.dart';
import 'package:muse_app/features/accounts/presentation/pages/browser_import_button.dart';
import 'package:muse_app/features/connection/presentation/bloc/connection_bloc.dart';

import 'account_cookies_bloc_test.dart' show CookiesRepo;
import 'account_cookies_page_test.dart' show Connect;
import 'browser_import_test.dart' show FixtureBridge;

class Download implements ExtensionDownload {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Saver implements ExtensionZipSaver {
  @override
  bool get supported => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Dependencies implements AppDependencies {
  @override
  final extensionDownload = Download();
  @override
  final extensionZipSaver = Saver();
  Dependencies(this.browserImport);
  @override
  final BrowserAccountImport browserImport;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final width in [320.0, 1280.0]) {
    for (final capability in [
      BrowserImportCapability.supported,
      BrowserImportCapability.unsupportedOrigin,
      BrowserImportCapability.unsupportedDevice,
    ]) {
      testWidgets('discoverable on both tabs: $capability at $width', (
        t,
      ) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = Size(width, 900);
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.view.resetPhysicalSize);
        final bridge = FixtureBridge()
          ..capability = capability
          ..installed = false;
        final connections = ConnectionBloc(Connect());
        final accounts = AccountBloc(ManageAccounts(CookiesRepo()));
        connections.add(
          ConnectionRequested('https://fixture.example', 'synthetic'),
        );
        await t.pump();
        await t.pumpWidget(
          RepositoryProvider<AppDependencies>.value(
            value: Dependencies(bridge),
            child: MultiBlocProvider(
              providers: [
                BlocProvider.value(value: connections),
                BlocProvider.value(value: accounts),
              ],
              child: MaterialApp(
                home: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 900),
                    textScaler: const TextScaler.linear(1.4),
                  ),
                  child: const Scaffold(body: AccountPage()),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        final action = find.text('Nhập tài khoản từ trình duyệt');
        expect(action, findsOneWidget);
        expect(bridge.pings, 0); // Mounting never probes or imports.
        await t.ensureVisible(action);
        await t.tap(action);
        await t.pumpAndSettle();
        if (capability == BrowserImportCapability.supported) {
          expect(
            find.textContaining('Chưa tìm thấy extension 1.1.0'),
            findsOneWidget,
          );
          expect(bridge.pings, 1);
        } else {
          expect(bridge.pings, 0);
          expect(
            find.textContaining(
              capability == BrowserImportCapability.unsupportedOrigin
                  ? 'Trang hiện tại chưa được'
                  : 'Thiết bị di động chưa',
            ),
            findsOneWidget,
          );
        }
        expect(bridge.commits, 0);
        final controller = t.state(find.byType(BrowserImportButton));
        await t.ensureVisible(find.text('Get Cookies'));
        await t.tap(find.text('Get Cookies'));
        await t.pumpAndSettle();
        expect(action, findsOneWidget);
        expect(
          identical(t.state(find.byType(BrowserImportButton)), controller),
          isTrue,
        );
        expect(
          bridge.pings,
          capability == BrowserImportCapability.supported ? 1 : 0,
        );
        await t.ensureVisible(find.text('Danh sách'));
        await t.tap(find.text('Danh sách'));
        await t.pumpAndSettle();
        await t.scrollUntilVisible(
          find.text('Nhập tài khoản'),
          200,
          scrollable: find
              .descendant(
                of: find.byType(ListView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await t.drag(find.byType(ListView), const Offset(0, -250));
        await t.pumpAndSettle();
        await t.tap(find.text('Nhập tài khoản'));
        await t.pumpAndSettle();
        expect(find.text('Cookie string'), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await t.runAsync(() async {
          await connections.close();
          await accounts.close();
        });
      });
    }
  }
}
