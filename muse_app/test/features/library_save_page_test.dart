import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muse_app/core/domain/save_library.dart';
import 'package:muse_app/core/domain/save_media.dart';
import 'package:muse_app/core/presentation/collection_bloc.dart';
import 'package:muse_app/features/connection/presentation/bloc/connection_bloc.dart';
import 'package:muse_app/features/media/domain/usecases/load_media.dart';
import 'package:muse_app/features/media/presentation/bloc/media_bloc.dart';
import 'package:muse_app/features/media/presentation/pages/media_page.dart';

import 'media_delete_bloc_test.dart' as fixtures;
import 'media_delete_page_test.dart' show Connect;

class PendingSaver implements LibrarySaver {
  final done = Completer<List<LibrarySaveEntry>>();
  late bool Function() current;
  late void Function(String, int)? progress;
  int calls = 0;
  @override
  Future<List<LibrarySaveEntry>> save(
    List<MediaSaveSource> sources, {
    required bool Function() isCurrent,
    void Function(String, int)? onProgress,
  }) {
    calls++;
    current = isCurrent;
    progress = onProgress;
    return done.future;
  }
}

void main() {
  Future<(ConnectionBloc, MediaBloc)> mount(
    WidgetTester tester,
    PendingSaver saver, {
    bool narrow = false,
  }) async {
    if (narrow) {
      await tester.binding.setSurfaceSize(const Size(320, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
    }
    final media = MediaBloc(LoadMedia(fixtures.Repository()));
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
            data: MediaQueryData(textScaler: TextScaler.linear(narrow ? 2 : 1)),
            child: Scaffold(body: MediaPage(saver: saver)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (connection, media);
  }

  Future<void> start(WidgetTester tester) async {
    await tester.ensureVisible(find.byTooltip('Chọn a.png'));
    await tester.tap(find.byTooltip('Chọn a.png'));
    await tester.pump();
    await tester.ensureVisible(find.text('Lưu 1 tệp vào thư mục'));
    await tester.tap(find.text('Lưu 1 tệp vào thư mục'));
    await tester.pump();
  }

  testWidgets(
    'old server failure and late progress cannot leak into new server',
    (tester) async {
      final saver = PendingSaver();
      final (connection, media) = await mount(tester, saver);
      await start(tester);
      connection.add(ConnectionRequested(fixtures.other.baseUrl, 'test'));
      media.add(CollectionCleared());
      media.add(CollectionLoaded(fixtures.other));
      await tester.pump();
      await tester.pump();
      expect(saver.current(), false);
      saver.progress?.call('old-server.mp4', 1024);
      saver.done.completeError(StateError('old transfer'));
      await tester.pumpAndSettle();
      expect(find.textContaining('old-server.mp4'), findsNothing);
      expect(
        find.textContaining('Không lưu được media. Kiểm tra tên tệp'),
        findsNothing,
      );
      expect(find.textContaining('Đã lưu '), findsNothing);
      expect(find.text('Lưu 1 tệp vào thư mục'), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
  for (final transfer in [false, true]) {
    testWidgets(
      'server switch during ${transfer ? 'transfer' : 'picker'} suppresses stale success',
      (tester) async {
        final saver = PendingSaver();
        final (connection, media) = await mount(tester, saver);
        await start(tester);
        if (transfer) {
          saver.progress?.call('a.png', 1024);
          await tester.pump();
        }
        connection.add(ConnectionRequested(fixtures.other.baseUrl, 'test'));
        media.add(CollectionCleared());
        media.add(CollectionLoaded(fixtures.other));
        await tester.pump();
        await tester.pump();
        expect(saver.current(), false);
        saver.progress?.call('stale-progress.png', 2048);
        await tester.pump();
        expect(find.textContaining('stale-progress'), findsNothing);
        saver.done.complete(const [
          LibrarySaveEntry('a.png', LibrarySaveStatus.saved),
        ]);
        await tester.pumpAndSettle();
        expect(find.textContaining('Đã lưu '), findsNothing);
        expect(find.text('Lưu 1 tệp vào thư mục'), findsNothing);
        expect(find.text('Xóa 1 tệp'), findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );
    testWidgets(
      'dispose during ${transfer ? 'transfer' : 'picker'} invalidates pending save',
      (tester) async {
        final saver = PendingSaver();
        await mount(tester, saver);
        await start(tester);
        if (transfer) {
          saver.progress?.call('a.png', 1024);
          await tester.pump();
        }
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        expect(saver.current(), false);
        saver.progress?.call('late.png', 2048);
        saver.done.complete([
          const LibrarySaveEntry('a.png', LibrarySaveStatus.saved),
        ]);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.textContaining('Đã lưu'), findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );
    testWidgets(
      'cancel during ${transfer ? 'transfer' : 'picker'} keeps exact partial results',
      (tester) async {
        final saver = PendingSaver();
        await mount(tester, saver);
        await start(tester);
        if (transfer) {
          saver.progress?.call('a.png', 1024);
          await tester.pump();
        }
        await tester.tap(find.text('Hủy lưu'));
        await tester.pump();
        expect(saver.current(), false);
        saver.done.complete([
          if (transfer)
            const LibrarySaveEntry('earlier.png', LibrarySaveStatus.saved),
          const LibrarySaveEntry('a.png', LibrarySaveStatus.cancelled),
        ]);
        await tester.pumpAndSettle();
        expect(
          find.text(transfer ? 'Đã lưu 1/2 tệp' : 'Đã lưu 0/1 tệp'),
          findsOneWidget,
        );
        expect(find.text('a.png: Đã hủy / chưa lưu'), findsOneWidget);
        expect(find.text('Hủy lưu'), findsNothing);
        expect(saver.calls, 1);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );
  }
  testWidgets('selected progress and partial results fit 320px with 2x text', (
    tester,
  ) async {
    final saver = PendingSaver();
    await mount(tester, saver, narrow: true);
    await start(tester);
    expect(tester.takeException(), isNull);
    saver.progress?.call('a.png', 1024);
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Hủy lưu'));
    await tester.tap(find.text('Hủy lưu'));
    await tester.pump();
    saver.done.complete(const [
      LibrarySaveEntry('a.png', LibrarySaveStatus.saved),
      LibrarySaveEntry('b.png', LibrarySaveStatus.failed),
    ]);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Đã lưu 1/2 tệp'));
    expect(find.text('Đã lưu 1/2 tệp'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
