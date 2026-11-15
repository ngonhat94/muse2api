import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/presentation/list_header.dart';
import '../bloc/chat_bloc.dart';

Future<void> showChatHistory(BuildContext context) async {
  final bloc = context.read<ChatBloc>();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 700),
    builder: (context) =>
        BlocProvider.value(value: bloc, child: const _HistorySheet()),
  );
}

class _HistorySheet extends StatelessWidget {
  const _HistorySheet();
  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .75,
      child: BlocBuilder<ChatBloc, ChatState>(
        builder: (context, state) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Lịch sử trò chuyện',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng lịch sử',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Lưu trên thiết bị này, tách riêng theo server và API key.',
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: TextButton.icon(
                  onPressed: state.historyLoading
                      ? null
                      : () {
                          context.read<ChatBloc>().add(ChatCleared());
                          Navigator.pop(context);
                        },
                  icon: const Icon(Icons.edit_square),
                  label: const Text('Cuộc trò chuyện mới'),
                ),
              ),
            ),
            if (state.historyLoading) const LinearProgressIndicator(),
            if (state.historyError != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  state.historyError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Expanded(
              child: state.threads.isEmpty
                  ? const Center(child: Text('Chưa có cuộc trò chuyện đã lưu.'))
                  : ListView.builder(
                      itemCount: state.threads.length,
                      itemBuilder: (context, index) {
                        final thread = state.threads[index];
                        return ListTile(
                          selected: state.activeId == thread.id,
                          title: Text(
                            thread.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${thread.messages.length} tin nhắn · ${formatDate(thread.updatedAt)}',
                          ),
                          onTap: () {
                            context.read<ChatBloc>().add(
                              ChatThreadOpened(thread.id),
                            );
                            Navigator.pop(context);
                          },
                          trailing: IconButton(
                            tooltip: 'Xóa cuộc trò chuyện',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              final bloc = context.read<ChatBloc>();
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Xóa cuộc trò chuyện?'),
                                  content: const Text(
                                    'Xóa cuộc trò chuyện này khỏi lịch sử trên thiết bị?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Hủy'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Xóa'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true && !bloc.isClosed) {
                                bloc.add(ChatThreadDeleted(thread.id));
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    ),
  );
}
