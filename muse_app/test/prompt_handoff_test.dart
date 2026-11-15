import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muse_app/core/presentation/reference_picker.dart';
import 'package:muse_app/features/images/presentation/pages/image_page.dart';
import 'package:muse_app/features/videos/presentation/pages/video_page.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muse_app/app/app.dart';
import 'package:muse_app/app/dependencies.dart';
import 'package:muse_app/features/image_prompt/presentation/image_prompt_page.dart';
import 'package:muse_app/features/text_prompt/presentation/text_prompt_page.dart';

import 'support/memory_credential_store.dart';

void main() {
  testWidgets(
    'both tools hand off locally; dirty prompt needs consent; no requests',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var requests = 0;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MuseApp(
          dependencies: AppDependencies(
            prefs,
            credentialStore: MemoryCredentialStore(),
            clientFactory: () => MockClient((r) async {
              requests++;
              return http.Response('{}', 500);
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final imageTool = tester.widget<ImagePromptPage>(
        find.byType(ImagePromptPage, skipOffstage: false),
      );
      final imagePageState = tester.state(
        find.byType(ImagePage, skipOffstage: false),
      );
      final videoPageState = tester.state(
        find.byType(VideoPage, skipOffstage: false),
      );
      final referenceElement = find
          .descendant(
            of: find.byType(ImagePage, skipOffstage: false),
            matching: find.byType(ReferencePicker, skipOffstage: false),
            skipOffstage: false,
          )
          .evaluate()
          .single;
      // Preserving the page/ReferencePicker subtree preserves picked bytes in RAM.

      imageTool.onCreateImage!('first image');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'first image'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'my draft');
      final textTool = tester.widget<TextPromptPage>(
        find.byType(TextPromptPage, skipOffstage: false),
      );
      textTool.onCreateImage!('replacement');
      await tester.pumpAndSettle();
      expect(find.text('Thay mô tả hiện tại?'), findsOneWidget);
      await tester.tap(find.text('Giữ mô tả'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'my draft'), findsOneWidget);
      textTool.onCreateImage!('replacement');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thay mô tả'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'replacement'), findsOneWidget);
      imageTool.onCreateVideo!('first video');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'first video'), findsOneWidget);
      textTool.onCreateVideo!('next video');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thay mô tả'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'next video'), findsOneWidget);
      expect(find.text('Kết nối server'), findsOneWidget);
      await tester.tap(find.text('Tác vụ').first);
      await tester.pumpAndSettle();
      expect(find.text('Khôi phục tác vụ đã lưu'), findsOneWidget);
      expect(
        tester.state(find.byType(ImagePage, skipOffstage: false)),
        same(imagePageState),
      );
      expect(
        tester.state(find.byType(VideoPage, skipOffstage: false)),
        same(videoPageState),
      );
      expect(
        find
            .descendant(
              of: find.byType(ImagePage, skipOffstage: false),
              matching: find.byType(ReferencePicker, skipOffstage: false),
              skipOffstage: false,
            )
            .evaluate()
            .single,
        same(referenceElement),
      );
      expect(requests, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
