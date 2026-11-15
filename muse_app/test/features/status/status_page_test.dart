import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muse_app/app/app.dart';
import 'package:muse_app/app/dependencies.dart';
import 'package:muse_app/app/studio_theme.dart';
import 'package:muse_app/features/chat/data/datasources/history_record_store.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';
import 'package:muse_app/features/connection/presentation/bloc/connection_bloc.dart';
import 'package:muse_app/features/status/domain/entities/server_status.dart';
import 'package:muse_app/features/status/domain/usecases/load_server_status.dart';
import 'package:muse_app/features/status/presentation/bloc/server_status_bloc.dart';
import 'package:muse_app/features/status/presentation/pages/server_status_page.dart';

import '../../support/memory_credential_store.dart';
import 'status_bloc_test.dart' show PendingStatusRepository;

void main() {
  testWidgets(
    'narrow large text page supports unknown, busy, error, stale and disconnect states',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(320, 700);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetPhysicalSize);
      final repository = PendingStatusRepository();
      final bloc = ServerStatusBloc(LoadServerStatus(repository));
      addTearDown(bloc.close);
      await t.pumpWidget(
        BlocProvider.value(
          value: bloc,
          child: MaterialApp(
            theme: StudioTheme.dark,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const Scaffold(body: ServerStatusPage()),
          ),
        ),
      );
      await t.scrollUntilVisible(
        find.text('Kết nối server để xem trạng thái.'),
        200,
      );
      expect(find.text('Kết nối server để xem trạng thái.'), findsOneWidget);
      const connection = ServerConnection(
        baseUrl: 'https://example.test',
        apiKey: 'fixture',
      );
      bloc.connectionChanged(connection);
      await t.pumpAndSettle();
      expect(repository.calls, isEmpty);
      expect(find.text('Chưa tải trạng thái.'), findsOneWidget);
      await t.tap(find.text('Tải trạng thái server'));
      await t.pump();
      expect(
        t.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      repository.calls.single.completeError(Exception('private raw details'));
      await t.pumpAndSettle();
      expect(find.textContaining('Không tải được trạng thái.'), findsOneWidget);
      expect(find.textContaining('private'), findsNothing);
      await t.tap(find.text('Tải trạng thái server'));
      await t.pump();
      repository.calls[1].complete(
        const ServerStatus(browserRunning: false, mediaCount: 0),
      );
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('Không chạy tại thời điểm tải'),
        200,
      );
      expect(find.text('Không chạy tại thời điểm tải'), findsOneWidget);
      await t.scrollUntilVisible(find.text('0'), 200);
      expect(find.text('0'), findsOneWidget);
      await t.scrollUntilVisible(find.text('Tổng tài khoản'), 200);
      await t.drag(find.byType(ListView), const Offset(0, -150));
      await t.pumpAndSettle();
      expect(find.text('Chưa rõ'), findsWidgets);
      t
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await t.pumpAndSettle();
      final failed = bloc.refresh();
      repository.calls[2].completeError(Exception('private'));
      await failed;
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.textContaining('Dữ liệu cũ'), 200);
      expect(find.textContaining('Dữ liệu cũ'), findsOneWidget);
      expect(testerException(t), isNull);
      bloc.connectionChanged(null);
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('Kết nối server để xem trạng thái.'),
        200,
      );
      expect(find.text('Không chạy tại thời điểm tải'), findsNothing);
      expect(find.text('Kết nối server để xem trạng thái.'), findsOneWidget);
    },
  );
  for (final size in [
    const Size(390, 844),
    const Size(1280, 800),
    const Size(640, 360),
  ]) {
    testWidgets(
      'shell status navigation is manual GET only at $size and clears connection changes',
      (t) async {
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = size;
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.view.resetPhysicalSize);
        SharedPreferences.setMockInitialValues({});
        final requests = <http.Request>[];
        final dependencies = AppDependencies(
          await SharedPreferences.getInstance(),
          credentialStore: MemoryCredentialStore(),
          historyStore: MemoryStatusHistoryStore(),
          clientFactory: () => MockClient((r) async {
            requests.add(r);
            return http.Response(
              jsonEncode(
                r.url.path == '/v1/me'
                    ? {
                        'id': 'admin',
                        'label': 'Synthetic administrator',
                        'role': 'admin',
                        'capabilities': {'global_admin': true},
                      }
                    : r.url.path == '/admin/status'
                    ? {
                        'browser_running': true,
                        'media_count': 4,
                        'config': {'host': 'private'},
                        'accounts': [
                          {'label': 'private'},
                        ],
                      }
                    : {'data': []},
              ),
              200,
            );
          }),
        );
        await t.pumpWidget(MuseApp(dependencies: dependencies));
        await t.pumpAndSettle();
        final context = t.element(
          find.byType(ServerStatusPage, skipOffstage: false),
        );
        final connection = context.read<ConnectionBloc>();
        await t.runAsync(() async {
          connection.add(
            ConnectionRequested('https://example.test', 'fixture'),
          );
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await t.pumpAndSettle();
        if (size.width < 800) {
          await t.tap(find.text('Thêm'));
          await t.pumpAndSettle();
          await t.ensureVisible(find.text('Trạng thái server'));
        }
        await t.ensureVisible(find.text('Trạng thái server'));
        await t.pumpAndSettle();
        await t.tap(find.text('Trạng thái server'));
        await t.pumpAndSettle();
        expect(requests.where((r) => r.url.path == '/admin/status'), isEmpty);
        await t.tap(find.text('Tải trạng thái server'));
        await t.pumpAndSettle();
        await t.scrollUntilVisible(
          find.text('Đang chạy tại thời điểm tải'),
          150,
          scrollable: find.descendant(
            of: find.byType(ServerStatusPage),
            matching: find.byType(Scrollable),
          ),
        );
        expect(find.text('Đang chạy tại thời điểm tải'), findsOneWidget);
        expect(find.text('private'), findsNothing);
        expect(
          requests.where((r) => r.url.path == '/admin/status').single.method,
          'GET',
        );
        await t.runAsync(() async {
          connection.add(ConnectionRequested('https://other.test', 'fixture'));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await t.pumpAndSettle();
        expect(context.read<ServerStatusBloc>().state.snapshot, isNull);
        expect(
          requests.where((r) => r.url.path == '/admin/status'),
          hasLength(1),
        );
        expect(t.takeException(), isNull);
      },
    );
  }
}

Object? testerException(WidgetTester tester) => tester.takeException();

class MemoryStatusHistoryStore implements HistoryRecordStore {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
}
