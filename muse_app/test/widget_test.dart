import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muse_app/app/app.dart';
import 'package:muse_app/app/dependencies.dart';

import 'support/memory_credential_store.dart';

void main() {
  testWidgets('text prompt is reachable without Muse on desktop and mobile', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [const Size(1280, 800), const Size(390, 844)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        MuseApp(
          dependencies: AppDependencies(
            preferences,
            credentialStore: MemoryCredentialStore(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (size.width < 800) {
        await tester.tap(find.text('Thêm'));
        await tester.pumpAndSettle();
      }
      await tester.scrollUntilVisible(
        find.text('Văn bản thành prompt').hitTestable(),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Văn bản thành prompt'));
      await tester.pumpAndSettle();
      expect(find.text('Mô tả của bạn'), findsOneWidget);
      expect(find.text('Tạo prompt'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });
  testWidgets('image prompt is reachable disconnected on desktop and mobile', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [const Size(1280, 800), const Size(390, 844)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        MuseApp(
          dependencies: AppDependencies(
            preferences,
            credentialStore: MemoryCredentialStore(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (size.width < 800) {
        await tester.tap(find.text('Thêm'));
        await tester.pumpAndSettle();
      }
      await tester.scrollUntilVisible(
        find.text('Ảnh thành prompt'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Ảnh thành prompt'));
      await tester.pumpAndSettle();
      expect(find.text('Chọn ảnh'), findsOneWidget);
      expect(find.textContaining('imageprompt.org'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });
  testWidgets('Connection setup fits mobile and desktop without overflow', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [const Size(390, 844), const Size(1280, 800)]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        MuseApp(
          dependencies: AppDependencies(
            preferences,
            credentialStore: MemoryCredentialStore(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Thiết lập Muse Studio'), findsOneWidget);
      expect(tester.takeException(), isNull);
      // Desktop offers the local engine first; remote setup is collapsed.
      final remoteSetup = find.widgetWithText(
        ExpansionTile,
        'Dùng server riêng',
      );
      if (remoteSetup.evaluate().isNotEmpty) {
        await tester.ensureVisible(remoteSetup);
        await tester.tap(find.text('Dùng server riêng'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Kiểm tra và kết nối'), findsOneWidget);
      await tester.ensureVisible(find.text('Kiểm tra và kết nối'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    }
  });
}
