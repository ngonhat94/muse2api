import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muse_app/core/presentation/generation_workspace.dart';

void main() {
  for (final width in [320.0, 390.0, 768.0, 1440.0]) {
    for (final scale in [1.0, 2.0, 3.0]) {
      for (final video in [true, false]) {
        for (final busy in [true, false]) {
          testWidgets(
            '${video ? 'video' : 'image'} preview at $width px, ${scale}x text, busy=$busy',
            (tester) async {
              tester.view.physicalSize = Size(width, 1000);
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
              const status = 'Muse đang tạo video · 25%';
              await tester.pumpWidget(
                MaterialApp(
                  home: MediaQuery(
                    data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                    child: Scaffold(
                      body: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: GenerationPreview(
                          video: video,
                          busy: busy,
                          status: busy ? status : null,
                        ),
                      ),
                    ),
                  ),
                ),
              );
              expect(tester.takeException(), isNull);
              final preview = tester.getRect(find.byType(GenerationPreview));
              final text = tester.getRect(find.byType(Text).last);
              expect(text.left, greaterThanOrEqualTo(preview.left + 24));
              expect(text.right, lessThanOrEqualTo(preview.right - 24));
              expect(text.bottom, lessThanOrEqualTo(preview.bottom - 24));
              expect(
                find.byType(LinearProgressIndicator),
                busy ? findsOneWidget : findsNothing,
              );
              if (busy) {
                expect(find.text(status), findsOneWidget);
                final progress = tester.getRect(
                  find.byType(LinearProgressIndicator),
                );
                expect(progress.top, greaterThan(text.bottom));
                expect(progress.bottom, lessThanOrEqualTo(preview.bottom - 24));
                final semantics = tester.widget<Semantics>(
                  find
                      .ancestor(
                        of: find.text(status),
                        matching: find.byType(Semantics),
                      )
                      .first,
                );
                expect(semantics.properties.liveRegion, isTrue);
              }
              if (width == 1440 && scale == 1) {
                expect(
                  preview.height,
                  closeTo(preview.width / (video ? 16 / 9 : 1), 0.01),
                );
              }
            },
          );
        }
      }
    }
  }

  testWidgets('completed media bypasses placeholder layout', (tester) async {
    const media = SizedBox(key: ValueKey('media'), height: 100);
    await tester.pumpWidget(
      const MaterialApp(
        home: GenerationPreview(video: true, busy: false, child: media),
      ),
    );
    expect(find.byKey(const ValueKey('media')), findsOneWidget);
    expect(find.byType(LayoutBuilder), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
