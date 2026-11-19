import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muse_app/features/connection/presentation/widgets/shiba_loading.dart';

void main() {
  testWidgets('Shiba respects reduced motion, semantics and disposal', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    for (final reduced in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              disableAnimations: reduced,
              size: const Size(320, 568),
            ),
            child: const ShibaLoadingPage(),
          ),
        ),
      );
      expect(
        find.bySemanticsLabel('Đang kiểm tra API key đã lưu. Vui lòng chờ.'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.binding.hasScheduledFrame, !reduced);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
