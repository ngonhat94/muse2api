import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';
import 'package:muse_app/features/connection/domain/usecases/connect_server.dart';
import 'package:muse_app/features/connection/presentation/bloc/connection_bloc.dart';
import 'package:muse_app/features/connection/presentation/pages/local_engine_panel.dart';
import 'package:muse_app/features/desktop/domain/repositories/desktop_engine.dart';
import 'package:muse_app/features/desktop/domain/repositories/desktop_engine_installer.dart';
import 'package:muse_app/features/desktop/domain/repositories/desktop_engine_failure.dart';

class UnusedConnect implements ConnectServer {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class PanelEngine implements DesktopEngine, DesktopEngineInstaller {
  var calls = 0;
  final pending = Completer<void>();
  void Function(DesktopInstallStage)? progress;
  @override
  bool get supported => true;
  @override
  Stream<void> get unexpectedExit => const Stream.empty();
  @override
  Future<ServerConnection> start() async => const ServerConnection(
    baseUrl: 'http://127.0.0.1:32100',
    apiKey: 'fixture',
    isLocal: true,
  );
  @override
  Future<void> stop() async {}
  @override
  Future<void> install(void Function(DesktopInstallStage) onProgress) async {
    calls++;
    progress = onProgress;
    await pending.future;
  }

  @override
  Future<void> cancelInstall() async {
    if (calls > 0 && !pending.isCompleted) {
      pending.completeError(
        const DesktopEngineFailure(DesktopEngineFailureCode.installCancelled),
      );
    }
  }
}

Widget app(
  ConnectionBloc bloc, {
  TextScaler textScaler = TextScaler.noScaling,
}) => MaterialApp(
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: textScaler),
    child: child!,
  ),
  home: Scaffold(
    body: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: BlocProvider.value(
          value: bloc,
          child: BlocBuilder<ConnectionBloc, ServerConnectionState>(
            builder: (context, state) => LocalEnginePanel(state: state),
          ),
        ),
      ),
    ),
  ),
);
void main() {
  testWidgets(
    'Install button shows stage, blocks duplicates and allows cancellation',
    (tester) async {
      final engine = PanelEngine();
      final bloc = ConnectionBloc(UnusedConnect(), desktop: engine);
      addTearDown(bloc.close);
      await tester.pumpWidget(app(bloc));
      await tester.ensureVisible(find.text('Cài đặt engine'));
      await tester.tap(find.text('Cài đặt engine'));
      await tester.pump();
      expect(engine.calls, 1);
      expect(find.text('Đang chuẩn bị bộ cài…'), findsOneWidget);
      expect(find.text('Cài đặt engine'), findsNothing);
      engine.progress!(DesktopInstallStage.browser);
      await tester.pump();
      expect(find.text('Đang tải trình duyệt đi kèm…'), findsOneWidget);
      await tester.ensureVisible(find.text('Hủy cài đặt'));
      await tester.tap(find.text('Hủy cài đặt'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Cài đặt engine'), findsOneWidget);
      expect(bloc.state.connection, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Install panel wraps at narrow width and large text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bloc = ConnectionBloc(UnusedConnect(), desktop: PanelEngine());
    addTearDown(bloc.close);
    await tester.pumpWidget(app(bloc, textScaler: const TextScaler.linear(2)));
    expect(find.text('Cài đặt engine'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
