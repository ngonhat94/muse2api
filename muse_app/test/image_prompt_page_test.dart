import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muse_app/app/studio_theme.dart';
import 'package:muse_app/features/image_prompt/presentation/image_prompt_cubit.dart';
import 'package:muse_app/features/image_prompt/presentation/image_prompt_page.dart';

import 'image_prompt_cubit_test.dart' show PendingPromptRepository;
import 'prompt_image_loader_test.dart' show png;

class SlowPromptFile extends XFile {
  SlowPromptFile() : super('/synthetic/replacement.png');
  static final bytes = Completer<Uint8List>();
  @override
  String get name => 'replacement.png';
  @override
  Future<int> length() async => png.length;
  @override
  Future<Uint8List> readAsBytes() => bytes.future;
}

void main() {
  testWidgets(
    'pending old response is invalidated as soon as replacement read begins',
    (tester) async {
      final repository = PendingPromptRepository();
      final cubit = ImagePromptCubit(repository);
      addTearDown(cubit.close);
      await tester.runAsync(() => cubit.select('old.png', png));
      final pending = cubit.generate();
      await tester.pumpWidget(
        MaterialApp(
          theme: StudioTheme.dark,
          home: BlocProvider.value(
            value: cubit,
            child: ImagePromptPage(pickImage: () async => SlowPromptFile()),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Đổi ảnh'));
      await tester.tap(find.text('Đổi ảnh'));
      await tester.pump();
      repository.requests.single.complete('stale');
      await pending;
      await tester.pump();
      expect(cubit.state.prompt, isNull);
      SlowPromptFile.bytes.complete(png);
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(cubit.state.image?.name, 'replacement.png');
    },
  );
  testWidgets('file drop validates locally and never sends automatically', (
    tester,
  ) async {
    final repository = PendingPromptRepository();
    final cubit = ImagePromptCubit(repository);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: StudioTheme.dark,
        home: BlocProvider.value(value: cubit, child: const ImagePromptPage()),
      ),
    );
    final target = tester.widget<DropTarget>(find.byType(DropTarget));
    target.onDragDone!(
      DropDoneDetails(
        files: [
          DropItemFile.fromData(
            png,
            name: 'dropped.png',
            path: '/synthetic/dropped.png',
          ),
        ],
        localPosition: Offset.zero,
        globalPosition: Offset.zero,
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(cubit.state.image?.name, 'dropped.png');
    expect(repository.requests, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('picker cancel preserves image; picker error is recoverable', (
    tester,
  ) async {
    final cubit = ImagePromptCubit(PendingPromptRepository());
    addTearDown(cubit.close);
    await tester.runAsync(() => cubit.select('peach.png', png));
    var fail = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: StudioTheme.dark,
        home: BlocProvider.value(
          value: cubit,
          child: ImagePromptPage(
            pickImage: () async {
              if (fail) throw Exception('private path');
              return null;
            },
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Đổi ảnh'));
    await tester.tap(find.text('Đổi ảnh'));
    await tester.pumpAndSettle();
    expect(cubit.state.image?.name, 'peach.png');
    fail = true;
    await tester.tap(find.text('Đổi ảnh'));
    await tester.pumpAndSettle();
    expect(find.text('Không mở được tệp. Thử chọn ảnh lại.'), findsOneWidget);
    expect(find.textContaining('private path'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('pick preview explicit send copy clear; narrow large text fits', (
    tester,
  ) async {
    tester.view.reset();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = PendingPromptRepository();
    final cubit = ImagePromptCubit(repository);
    addTearDown(cubit.close);
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: StudioTheme.dark,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: BlocProvider.value(
            value: cubit,
            child: ImagePromptPage(
              pickImage: () async => XFile.fromData(png, name: 'peach.png'),
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('imageprompt.org'), findsWidgets);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Lấy prompt'))
          .onPressed,
      isNull,
    );
    await tester.ensureVisible(find.text('Chọn ảnh'));
    await tester.tap(find.text('Chọn ảnh'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    expect(repository.requests, isEmpty);
    await tester.ensureVisible(find.text('Lấy prompt'));
    await tester.tap(find.text('Lấy prompt'));
    await tester.pump();
    expect(find.text('Đang lấy prompt…'), findsOneWidget);
    repository.requests.single.complete('A peach square');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sao chép prompt'));
    await tester.tap(find.text('Sao chép prompt'));
    await tester.pumpAndSettle();
    expect(copied, 'A peach square');
    await tester.ensureVisible(find.text('Xóa ảnh'));
    await tester.tap(find.text('Xóa ảnh'));
    await tester.pumpAndSettle();
    expect(find.text('A peach square'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
