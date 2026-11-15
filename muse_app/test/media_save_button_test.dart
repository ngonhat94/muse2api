import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muse_app/core/domain/save_media.dart';
import 'package:muse_app/core/presentation/media_save_button.dart';
import 'package:muse_app/core/presentation/media_preview.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';
import 'package:flutter/foundation.dart';

class FakeSaver implements MediaSaver {
  int calls = 0;
  bool Function()? current;
  final completer = Completer<MediaSaveResult>();
  @override
  Future<MediaSaveResult> save(
    MediaSaveSource source, {
    required bool Function() isCurrent,
    void Function(int)? onProgress,
  }) async {
    calls++;
    current = isCurrent;
    onProgress?.call(8192);
    return completer.future;
  }
}

void main() {
  for (final dispose in [false, true]) {
    testWidgets(
      dispose
          ? 'dispose invalidates in-flight save without feedback'
          : 'cancel invalidates in-flight save without success',
      (tester) async {
        final saver = FakeSaver();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MediaSaveButton(
                source: MediaSaveSource.image(Uint8List(8)),
                saveMedia: SaveMedia(saver),
                isCurrent: () => true,
              ),
            ),
          ),
        );
        await tester.tap(find.text('Lưu về máy'));
        await tester.pump();
        expect(saver.current!(), true);
        if (dispose) {
          await tester.pumpWidget(const MaterialApp(home: Scaffold()));
        } else {
          await tester.tap(find.text('Hủy lưu'));
          await tester.pump();
        }
        expect(saver.current!(), false);
        saver.completer.complete(MediaSaveResult.saved);
        await tester.pumpAndSettle();
        expect(find.byType(SnackBar), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'shared video preview exposes direct save beside browser action',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaPreview(
              uri: Uri.parse('https://fixture.example/v1/media/a.mp4'),
              video: true,
              connection: const ServerConnection(
                baseUrl: 'https://fixture.example',
                apiKey: 'fixture',
              ),
            ),
          ),
        ),
      );
      expect(find.byType(MediaSaveButton), findsOneWidget);
      expect(find.text('Mở bằng trình duyệt'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    },
  );
  testWidgets(
    'explicit save shows progress, blocks duplicate taps, announces success at narrow width',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final saver = FakeSaver();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: MediaSaveButton(
                source: MediaSaveSource.image(
                  Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
                ),
                saveMedia: SaveMedia(saver),
                isCurrent: () => true,
              ),
            ),
          ),
        ),
      );
      expect(saver.calls, 0);
      await tester.tap(find.text('Lưu về máy'));
      await tester.pump();
      expect(saver.calls, 1);
      expect(find.textContaining('Đang lưu'), findsOneWidget);
      expect(find.text('Hủy lưu'), findsOneWidget);
      expect(tester.takeException(), isNull);
      saver.completer.complete(MediaSaveResult.saved);
      await tester.pumpAndSettle();
      expect(find.text('Đã lưu media về máy.'), findsOneWidget);
    },
  );
  testWidgets('picker cancellation is not success or error', (tester) async {
    final saver = FakeSaver();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaSaveButton(
            source: MediaSaveSource.image(Uint8List(8)),
            saveMedia: SaveMedia(saver),
            isCurrent: () => true,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Lưu về máy'));
    saver.completer.complete(MediaSaveResult.cancelled);
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });
}
