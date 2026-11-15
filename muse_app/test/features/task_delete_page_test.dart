import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:muse_app/core/presentation/collection_bloc.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';
import 'package:muse_app/features/connection/domain/usecases/connect_server.dart';
import 'package:muse_app/features/connection/presentation/bloc/connection_bloc.dart';
import 'package:muse_app/features/tasks/domain/usecases/load_tasks.dart';
import 'package:muse_app/features/tasks/presentation/bloc/task_bloc.dart';
import 'package:muse_app/features/tasks/presentation/pages/task_page.dart';

import 'task_delete_bloc_test.dart' as f;

class Connect implements ConnectServer {
  @override
  Future<ServerConnection> call(String address, String key) async =>
      ServerConnection(baseUrl: address, apiKey: key);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Future<f.Repository> mount(WidgetTester tester) async {
    final repo = f.Repository();
    final tasks = TaskBloc(LoadTasks(repo));
    final connection = ConnectionBloc(Connect());
    addTearDown(tasks.close);
    addTearDown(connection.close);
    connection.add(ConnectionRequested(f.server.baseUrl, 'test'));
    tasks.add(CollectionLoaded(f.server));
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: tasks),
          BlocProvider.value(value: connection),
        ],
        child: MaterialApp(
          home: Scaffold(body: TaskPage(onResumeVideo: (_) {})),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return repo;
  }

  testWidgets('delete requires confirmation and cancel preserves task', (
    tester,
  ) async {
    final repo = await mount(tester);
    await tester.tap(find.byTooltip('Xóa tác vụ a'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(repo.calls, 0);
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Hủy'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(repo.calls, 0);
    await tester.tap(find.byTooltip('Xóa tác vụ a'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(repo.calls, 1);
    expect(find.byTooltip('Xóa tác vụ a'), findsNothing);
  });
  testWidgets(
    'clear warns about all records including active tasks and confirms',
    (tester) async {
      final repo = await mount(tester);
      await tester.tap(find.text('Xóa tất cả tác vụ'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(repo.calls, 0);
      expect(find.textContaining('đang chạy'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(repo.calls, 1);
      expect(find.text('Chưa có tác vụ.'), findsOneWidget);
    },
  );
  testWidgets('confirmation cannot mutate a new connection', (tester) async {
    final repo = await mount(tester);
    final context = tester.element(find.byType(TaskPage));
    await tester.tap(find.byTooltip('Xóa tác vụ a'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    context.read<ConnectionBloc>().add(
      ConnectionRequested(f.other.baseUrl, 'test'),
    );
    context.read<TaskBloc>().add(CollectionCleared());
    context.read<TaskBloc>().add(CollectionLoaded(f.other));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(repo.calls, 0);
  });
}
