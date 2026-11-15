import '../../../../app/studio_theme.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/generation_task.dart';
import '../../../../core/presentation/collection_bloc.dart';
import '../../../../core/presentation/list_header.dart';
import '../../../../core/presentation/media_preview.dart';
import '../../../connection/presentation/bloc/connection_bloc.dart';
import '../bloc/task_bloc.dart';

class TaskPage extends StatefulWidget {
  const TaskPage({super.key, required this.onResumeVideo});
  final ValueChanged<String> onResumeVideo;
  @override
  State<TaskPage> createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  bool _confirming = false;
  Future<void> _delete(String? id) async {
    final bloc = context.read<TaskBloc>();
    final connection = context.read<ConnectionBloc>().state.connection;
    if (_confirming ||
        connection == null ||
        !bloc.matches(connection) ||
        bloc.state.loading ||
        bloc.state.deleting ||
        bloc.state.stale) {
      return;
    }
    _confirming = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(id == null ? 'Xóa tất cả tác vụ?' : 'Xóa tác vụ?'),
        content: Text(
          id == null
              ? 'Xóa toàn bộ lịch sử tác vụ trên server, kể cả tác vụ đang chạy và các tác vụ chưa hiển thị. Thao tác này không hủy quá trình tạo và không xóa tệp kết quả. Không thể hoàn tác.'
              : 'Xóa bản ghi “$id” khỏi server? Thao tác này không hủy quá trình tạo và không xóa tệp kết quả. Không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    _confirming = false;
    if (!mounted || confirmed != true) return;
    final current = context.read<ConnectionBloc>().state.connection;
    if (current?.baseUrl != connection.baseUrl ||
        current?.apiKey != connection.apiKey ||
        !bloc.matches(connection)) {
      return;
    }
    bloc.add(
      id == null
          ? TaskClearRequested(connection)
          : TaskDeleteRequested(connection, id),
    );
  }

  void _cancel(GenerationTask task) {
    final bloc = context.read<TaskBloc>();
    final connection = context.read<ConnectionBloc>().state.connection;
    if (connection == null || task.terminal || !bloc.matches(connection)) {
      return;
    }
    bloc.add(TaskCancelRequested(connection, task.id));
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<TaskBloc, TaskState>(
    builder: (context, state) {
      final connection = context.watch<ConnectionBloc>().state.connection;
      final busy = state.loading || state.deleting;
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
            child: ListHeader(
              title: 'Tác vụ',
              loading: busy,
              error: state.error,
              onRefresh: connection == null || busy
                  ? null
                  : () => context.read<TaskBloc>().add(
                      CollectionLoaded(connection, poll: true),
                    ),
            ),
          ),
          if (state.notice != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Semantics(liveRegion: true, child: Text(state.notice!)),
            ),
          if (state.deleting)
            const LinearProgressIndicator(semanticsLabel: 'Đang xóa tác vụ'),
          if (connection != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed:
                      busy ||
                          state.stale ||
                          !context.read<TaskBloc>().matches(connection)
                      ? null
                      : () => _delete(null),
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Xóa tất cả tác vụ'),
                ),
              ),
            ),
          if (connection == null)
            const Expanded(
              child: Center(child: Text('Kết nối server để xem tác vụ.')),
            )
          else if (state.items.isEmpty && !state.loading)
            const Expanded(child: Center(child: Text('Chưa có tác vụ.')))
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: state.items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final task = state.items[index];
                  final status = switch (task.status) {
                    GenerationStatus.queued => 'Đang chờ',
                    GenerationStatus.processing => 'Đang xử lý',
                    GenerationStatus.completed => 'Hoàn tất',
                    GenerationStatus.failed => 'Thất bại',
                  };
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                task.kind == 'video'
                                    ? Icons.movie_outlined
                                    : Icons.image_outlined,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  status,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Xóa tác vụ ${task.id}',
                                onPressed:
                                    busy ||
                                        state.stale ||
                                        !context.read<TaskBloc>().matches(
                                          connection,
                                        )
                                    ? null
                                    : () => _delete(task.id),
                                icon: const Icon(Icons.delete_outline),
                              ),
                              if (!task.terminal)
                                IconButton(
                                  tooltip: 'Hủy tác vụ ${task.id}',
                                  onPressed: busy || state.stale
                                      ? null
                                      : () => _cancel(task),
                                  icon: const Icon(Icons.cancel_outlined),
                                ),
                              Text(
                                '${task.progress.round()}%',
                                style: const TextStyle(color: Colors.white54),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            task.prompt,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            '${task.id} · ${formatDate(task.createdAt)}',
                            style: const TextStyle(
                              color: StudioColors.muted,
                              fontSize: 12,
                            ),
                          ),
                          if (!task.terminal)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: LinearProgressIndicator(
                                value: task.progress > 0
                                    ? task.progress / 100
                                    : null,
                              ),
                            ),
                          if (task.status == GenerationStatus.completed &&
                              task.protectedUri != null)
                            TextButton.icon(
                              onPressed: () => showMediaPreview(
                                context,
                                task.protectedUri!,
                                task.kind == 'video',
                                connection: connection,
                              ),
                              icon: const Icon(Icons.open_in_full),
                              label: const Text('Xem kết quả'),
                            ),
                          if (task.kind == 'video' && !task.terminal)
                            TextButton.icon(
                              onPressed: () => widget.onResumeVideo(task.id),
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Theo dõi video'),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      );
    },
  );
}
