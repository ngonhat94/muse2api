import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muse_app/app/studio_theme.dart';
import 'package:muse_app/features/text_prompt/presentation/text_prompt_cubit.dart';
import 'package:muse_app/features/text_prompt/presentation/text_prompt_page.dart';

import 'text_prompt_cubit_test.dart' show PendingPrompts;

void main() {
  testWidgets(
    'narrow large text validates, clears pending work and survives disposal',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final repository = PendingPrompts();
      final cubit = TextPromptCubit(repository);
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp(
            theme: StudioTheme.dark,
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
              child: const Scaffold(body: TextPromptPage()),
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Tạo prompt'));
      await tester.tap(find.text('Tạo prompt'));
      await tester.pumpAndSettle();
      expect(repository.requests, isEmpty);
      expect(cubit.state.error, isNotNull);
      await tester.enterText(find.byType(TextField), 'dog');
      await tester.ensureVisible(find.text('Tạo prompt'));
      await tester.tap(find.text('Tạo prompt'));
      await tester.pump();
      await tester.ensureVisible(find.text('Xóa mô tả'));
      await tester.tap(find.text('Xóa mô tả'));
      await tester.pump();
      repository.pending.single.complete('stale');
      await tester.pumpAndSettle();
      expect(find.text('stale'), findsNothing);
      await tester.enterText(find.byType(TextField), 'cat');
      await tester.ensureVisible(find.text('Tạo prompt'));
      await tester.tap(find.text('Tạo prompt'));
      await tester.pump();
      repository.pending.last.completeError(Exception('SECRET'));
      await tester.pumpAndSettle();
      expect(find.textContaining('SECRET'), findsNothing);
      expect(cubit.state.error, isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await cubit.close();
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'native form discloses destination and only submit transmits; result copy and clear',
    (tester) async {
      final repository = PendingPrompts();
      final cubit = TextPromptCubit(repository);
      addTearDown(cubit.close);
      String? clipboard;
      final handoffs = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp(
            theme: StudioTheme.dark,
            home: Scaffold(
              body: TextPromptPage(
                onCreateImage: (p) => handoffs.add('image:$p'),
                onCreateVideo: (p) => handoffs.add('video:$p'),
              ),
            ),
          ),
        ),
      );
      expect(find.textContaining('imageprompt.org'), findsWidgets);
      await tester.enterText(find.byType(TextField), 'chó đen');
      await tester.pump();
      expect(repository.requests, isEmpty);
      await tester.ensureVisible(find.text('Tạo prompt'));
      await tester.tap(find.text('Tạo prompt'));
      await tester.pump();
      expect(repository.requests, ['chó đen']);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      repository.pending.single.complete('Prompt thử nghiệm');
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(SelectableText, 'Prompt thử nghiệm'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Sao chép prompt'));
      await tester.tap(find.text('Sao chép prompt'));
      await tester.pumpAndSettle();
      expect(clipboard, 'Prompt thử nghiệm');
      for (final label in ['Dùng để tạo ảnh', 'Dùng để tạo video']) {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
      expect(handoffs, ['image:Prompt thử nghiệm', 'video:Prompt thử nghiệm']);
      expect(repository.requests, ['chó đen']);
      await tester.ensureVisible(find.text('Xóa mô tả'));
      await tester.tap(find.text('Xóa mô tả'));
      await tester.pumpAndSettle();
      expect(find.text('Prompt thử nghiệm'), findsNothing);
      expect(cubit.state.text, '');
    },
  );
}
