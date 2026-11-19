import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muse_app/features/accounts/presentation/pages/get_cookies_guide.dart';

void main() {
  test('guide version and compatibility match current extension policy', () {
    final manifest = jsonDecode(
      File('../extension/manifest.json').readAsStringSync(),
    ) as Map;
    expect(manifest['version'], '1.1.1');
    expect(manifest['externally_connectable']['matches'], [
      'https://muapp-3d6.pages.dev/*',
      'https://muse.dntrip.xyz/*',
    ]);
    // Keep the user-facing compatibility guidance in sync with the policy.
    expect(
      File('../extension/import_policy.js').readAsStringSync(),
      contains(
        "const origins = Object.freeze(['https://muapp-3d6.pages.dev', 'https://muse.dntrip.xyz'])",
      ),
    );
  });

  for (final width in [320.0, 390.0, 1280.0]) {
    testWidgets('guide scrolls at $width with large text', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 800),
                textScaler: const TextScaler.linear(1.4),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: GetCookiesGuide(onManualImport: () => opened++),
              ),
            ),
          ),
        ),
      );
      expect(opened, 0);
      expect(find.text('Nhập phiên Muse an toàn'), findsOneWidget);
      await tester.ensureVisible(find.text('Mở form nhập thủ công'));
      await tester.pump();
      await tester.tap(find.text('Mở form nhập thủ công'));
      expect(opened, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
