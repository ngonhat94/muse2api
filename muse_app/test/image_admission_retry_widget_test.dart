import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';
import 'package:muse_app/features/images/presentation/bloc/image_bloc.dart';
import 'package:muse_app/features/images/presentation/pages/image_page.dart';
import 'package:muse_app/app/app.dart';
import 'package:muse_app/app/dependencies.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

import 'support/memory_credential_store.dart';

void main() {
  testWidgets('uncertain image locks inputs and exposes manual retry', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final dependencies = AppDependencies(
      prefs,
      credentialStore: MemoryCredentialStore(),
      clientFactory: () => MockClient((_) async => http.Response('{}', 500)),
    );
    await tester.pumpWidget(MuseApp(dependencies: dependencies));
    await tester.pumpAndSettle();
    final page = find.byType(ImagePage, skipOffstage: false).evaluate().single;
    final bloc = page.read<ImageBloc>();
    bloc.add(
      ImageRequested(
        const ServerConnection(
          baseUrl: 'https://example.com',
          apiKey: 'synthetic',
        ),
        'fixture',
        '1:1',
      ),
    );
    await tester.pumpAndSettle();
    expect(bloc.state.admissionUncertain, isTrue);
    final field = tester.widget<TextFormField>(
      find
          .descendant(
            of: find.byType(ImagePage, skipOffstage: false),
            matching: find.byType(TextFormField, skipOffstage: false),
          )
          .first,
    );
    expect(field.enabled, isFalse);
    final chips = tester.widgetList<ChoiceChip>(
      find.descendant(
        of: find.byType(ImagePage, skipOffstage: false),
        matching: find.byType(ChoiceChip, skipOffstage: false),
      ),
    );
    expect(chips.every((chip) => chip.onSelected == null), isTrue);
    expect(
      find.text('Thử lại cùng yêu cầu', skipOffstage: false),
      findsOneWidget,
    );
    await tester.tap(find.text('Tạo ảnh').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Bỏ yêu cầu để tạo mới…'));
    await tester.tap(find.text('Bỏ yêu cầu để tạo mới…'));
    await tester.pumpAndSettle();
    expect(find.textContaining('không hủy tác vụ'), findsOneWidget);
    await tester.tap(find.text('Giữ yêu cầu'));
    await tester.pumpAndSettle();
    expect(bloc.state.admissionUncertain, isTrue);
    await tester.tap(find.text('Bỏ yêu cầu để tạo mới…'));
    await tester.pumpAndSettle();
    bloc.add(ImagesCleared(connectionChanged: true));
    await tester.pumpAndSettle();
    bloc.add(
      ImageRequested(
        const ServerConnection(
          baseUrl: 'https://other.example',
          apiKey: 'synthetic-other',
        ),
        'new owner',
        '1:1',
      ),
    );
    await tester.pumpAndSettle();
    expect(bloc.state.admissionUncertain, isTrue);
    await tester.tap(find.text('Đã kiểm tra, bỏ yêu cầu'));
    await tester.pumpAndSettle();
    expect(
      bloc.state.admissionUncertain,
      isTrue,
      reason: 'old confirmation cannot discard a new connection intent',
    );
    await tester.ensureVisible(find.text('Bỏ yêu cầu để tạo mới…'));
    await tester.tap(find.text('Bỏ yêu cầu để tạo mới…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đã kiểm tra, bỏ yêu cầu'));
    await tester.pumpAndSettle();
    expect(bloc.state.admissionUncertain, isFalse);
  });
}
