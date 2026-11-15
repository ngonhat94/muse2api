import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';
import 'package:muse_app/features/videos/presentation/bloc/video_bloc.dart';
import 'package:muse_app/features/videos/presentation/pages/video_page.dart';
import 'package:muse_app/app/app.dart';
import 'package:muse_app/app/dependencies.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;

import 'support/memory_credential_store.dart';

void main() {
  testWidgets(
    'uncertain video exposes explicit same-key retry, never automatic POST',
    (tester) async {
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
      final page = find
          .byType(VideoPage, skipOffstage: false)
          .evaluate()
          .single;
      final bloc = page.read<VideoBloc>();
      // A failed synthetic POST produces the real uncertain state.
      bloc.add(
        VideoRequested(
          const ServerConnection(
            baseUrl: 'https://example.com',
            apiKey: 'synthetic',
          ),
          'fixture',
          '16:9',
          6,
        ),
      );
      await tester.pumpAndSettle();
      expect(bloc.state.admissionUncertain, isTrue);
      expect(
        find.text('Thử lại cùng yêu cầu', skipOffstage: false),
        findsOneWidget,
      );
    },
  );
}
