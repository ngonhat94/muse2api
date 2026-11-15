import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muse_app/core/presentation/collection_bloc.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';
import 'package:muse_app/features/connection/domain/usecases/connect_server.dart';
import 'package:muse_app/features/connection/presentation/bloc/connection_bloc.dart';
import 'package:muse_app/features/media/domain/usecases/load_media.dart';
import 'package:muse_app/features/media/domain/entities/media_item.dart';
import 'package:muse_app/features/media/presentation/bloc/media_bloc.dart';
import 'package:muse_app/features/media/presentation/pages/media_page.dart';

import 'media_delete_bloc_test.dart' as fixtures;

class Connect implements ConnectServer {
  @override
  Future<ServerConnection> call(String address, String key) async =>
      ServerConnection(baseUrl: address, apiKey: key);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<fixtures.Repository> mount(
    WidgetTester tester, {
    bool large = false,
  }) async {
    final repo = fixtures.Repository()
      ..items = [
        MediaItem(
          name: 'a.png',
          isVideo: false,
          bytes: 1,
          protectedUri: fixtures.server.endpoint(
            '/v1/media/a.png?cap=synthetic.capability',
          ),
        ),
        fixtures.b,
      ];
    final media = MediaBloc(LoadMedia(repo));
    final connection = ConnectionBloc(Connect());
    addTearDown(media.close);
    addTearDown(connection.close);
    connection.add(ConnectionRequested(fixtures.server.baseUrl, 'test'));
    media.add(CollectionLoaded(fixtures.server));
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: media),
          BlocProvider.value(value: connection),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(large ? 2 : 1)),
            child: const Scaffold(body: MediaPage()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  testWidgets('confirmation from a previous server cannot delete', (
    tester,
  ) async {
    final repo = await mount(tester);
    final context = tester.element(find.byType(MediaPage));
    await tester.tap(find.byTooltip('Xóa a.png'));
    await tester.pumpAndSettle();
    context.read<ConnectionBloc>().add(
      ConnectionRequested(fixtures.other.baseUrl, 'test'),
    );
    context.read<MediaBloc>().add(CollectionCleared());
    context.read<MediaBloc>().add(CollectionLoaded(fixtures.other));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
    await tester.pumpAndSettle();
    expect(repo.calls, 0);
  });
  testWidgets('search removes hidden selections and exposes desktop save', (
    tester,
  ) async {
    await mount(tester);
    await tester.tap(find.byTooltip('Chọn a.png'));
    await tester.pump();
    expect(find.text('Lưu 1 tệp vào thư mục'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'b.PNG');
    await tester.pumpAndSettle();
    expect(find.text('a.png'), findsNothing);
    expect(find.text('b.png'), findsOneWidget);
    expect(find.text('Xóa 1 tệp'), findsNothing);
    expect(find.text('Lưu 1 tệp vào thư mục'), findsNothing);
  });
  testWidgets('no matching files explains how to recover', (tester) async {
    await mount(tester);
    await tester.enterText(find.byType(TextField), 'no-match-fixture');
    await tester.pumpAndSettle();
    expect(
      find.text('Không có tệp phù hợp. Thử tên khác hoặc chọn Tất cả.'),
      findsOneWidget,
    );
  });
  testWidgets('library remains usable at 320px and 2x text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await mount(tester, large: true);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'media without a capability stays locked instead of inventing a URL',
    (tester) async {
      await mount(tester);
      await tester.tap(find.text('b.png'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    },
  );
  testWidgets('card tap still opens image preview', (tester) async {
    await mount(tester);
    await tester.tap(find.text('a.png'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
  });
  testWidgets(
    'single delete requires confirmation and cancel does not delete',
    (tester) async {
      final repo = await mount(tester);
      await tester.tap(find.byTooltip('Xóa a.png'));
      await tester.pumpAndSettle();
      expect(find.text('Xóa media?'), findsOneWidget);
      expect(repo.calls, 0);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(repo.calls, 0);
      await tester.tap(find.byTooltip('Xóa a.png'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
      await tester.pumpAndSettle();
      expect(repo.calls, 1);
      expect(find.text('a.png'), findsNothing);
    },
  );
  testWidgets(
    'selection offers batch confirmation and reports partial failure',
    (tester) async {
      final repo = await mount(tester);
      await tester.tap(find.byTooltip('Chọn a.png'));
      await tester.pump();
      await tester.tap(find.byTooltip('Chọn b.png'));
      await tester.pump();
      await tester.tap(find.text('Xóa 2 tệp'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.textContaining('2 tệp đã chọn'),
        ),
        findsOneWidget,
      );
      expect(repo.calls, 0);
      await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
      await tester.pumpAndSettle();
      expect(repo.calls, 1);
      expect(find.textContaining('1 tệp không xóa được'), findsOneWidget);
    },
  );
}
