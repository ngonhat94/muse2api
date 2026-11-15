import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muse_app/features/accounts/presentation/pages/cookie_update_dialog.dart';

void main() {
  Future<void> open(
    WidgetTester tester, {
    bool Function()? current,
    void Function(String)? submit,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => CookieUpdateDialog(
                  isCurrent: current ?? () => true,
                  onSubmit: submit ?? (_) {},
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'cookie dialog warns about replacement, obscures input and rejects blank',
    (t) async {
      var calls = 0;
      await open(t, submit: (_) => calls++);
      expect(find.textContaining('thay thế toàn bộ'), findsOneWidget);
      expect(find.textContaining('không xác nhận'), findsOneWidget);
      final field = t.widget<TextField>(find.byType(TextField));
      expect(field.obscureText, true);
      expect(field.enableSuggestions, false);
      expect(field.autocorrect, false);
      expect(field.enableIMEPersonalizedLearning, false);
      await t.tap(find.widgetWithText(FilledButton, 'Cập nhật cookie'));
      await t.pumpAndSettle();
      expect(calls, 0);
      await t.enterText(find.byType(TextField), 'x=y');
      await t.tap(find.widgetWithText(FilledButton, 'Cập nhật cookie'));
      await t.pumpAndSettle();
      expect(calls, 1);
      expect(find.byType(AlertDialog), findsNothing);
      expect(field.controller!.text, isEmpty);
    },
  );
  testWidgets('stale dialog cannot submit and clears input on dismissal', (
    t,
  ) async {
    var current = true;
    var calls = 0;
    await open(t, current: () => current, submit: (_) => calls++);
    await t.enterText(find.byType(TextField), 'x=y');
    current = false;
    await t.tap(find.widgetWithText(FilledButton, 'Cập nhật cookie'));
    await t.pumpAndSettle();
    expect(calls, 0);
    expect(find.byType(AlertDialog), findsNothing);
  });
  testWidgets('dialog fits a 320px screen', (t) async {
    t.view.physicalSize = const Size(320, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await open(t);
    expect(t.takeException(), isNull);
    await t.ensureVisible(find.widgetWithText(FilledButton, 'Cập nhật cookie'));
    expect(t.takeException(), isNull);
  });
  testWidgets('cancel then reopen never restores cookie input', (t) async {
    await open(t);
    await t.enterText(find.byType(TextField), 'x=y');
    await t.tap(find.text('Hủy'));
    await t.pumpAndSettle();
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    expect(
      t.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });
}
