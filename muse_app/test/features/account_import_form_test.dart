import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muse_app/features/accounts/presentation/pages/cookie_import_form.dart';

const batch =
    'acc-01 | hatch_sess=first; hatch_vml=vm1\nacc-02 | hatch_sess=second; hatch_vml=vm2';
void main() {
  testWidgets(
    'Multiline batch is counted, named per row, can be hidden and is submitted unchanged',
    (tester) async {
      String? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: CookieImportForm(
                  busy: false,
                  onSubmit: (label, cookies) {
                    submitted = cookies;
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField).last, batch);
      await tester.pump();
      expect(find.text('Sẽ nhập 2 tài khoản từ danh sách.'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField).first).enabled,
        false,
      );
      await tester.tap(find.byTooltip('Ẩn cookie'));
      await tester.pump();
      expect(
        tester.widget<EditableText>(find.byType(EditableText).last).obscureText,
        true,
      );
      await tester.tap(find.byTooltip('Hiện cookie'));
      await tester.pump();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).last)
            .controller!
            .text,
        batch,
      );
      await tester.ensureVisible(find.text('Nhập 2 tài khoản'));
      await tester.tap(find.text('Nhập 2 tài khoản'));
      await tester.pump();
      expect(submitted, batch);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Invalid batch retains input and reports the line without submitting',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CookieImportForm(
                busy: false,
                onSubmit: (_, _) {
                  calls++;
                },
              ),
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byType(TextFormField).last,
        'acc-01 | hatch_sess=first\nacc-02 | missing',
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Nhập vào server'));
      await tester.tap(find.text('Nhập vào server'));
      await tester.pump();
      expect(find.textContaining('Dòng 2'), findsOneWidget);
      expect(calls, 0);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).last)
            .controller!
            .text,
        contains('hatch_sess=first'),
      );
    },
  );
  testWidgets(
    'Draft is cleared when the connection key changes and busy disables submit',
    (tester) async {
      var calls = 0;
      Widget app(String key, bool busy) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CookieImportForm(
              key: ValueKey(key),
              busy: busy,
              onSubmit: (_, _) {
                calls++;
              },
            ),
          ),
        ),
      );
      await tester.pumpWidget(app('first', false));
      await tester.enterText(find.byType(TextFormField).last, batch);
      await tester.pump();
      await tester.pumpWidget(app('second', true));
      await tester.pump();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).last)
            .controller!
            .text,
        '',
      );
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField).last).enabled,
        false,
      );
      expect(calls, 0);
    },
  );
  testWidgets('Form fits a small viewport with large text', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: CookieImportForm(busy: false, onSubmit: (_, _) {}),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
