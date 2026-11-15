import 'chat_history_sheet.dart';
import '../../../../app/studio_theme.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../connection/presentation/bloc/connection_bloc.dart';
import '../../domain/entities/chat_message.dart';
import '../bloc/chat_bloc.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.onConfigure,
    required this.onCreateImage,
  });
  final VoidCallback onConfigure;
  final ValueChanged<String> onCreateImage;
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final connection = context.read<ConnectionBloc>().state.connection;
    if (connection == null ||
        _input.text.trim().isEmpty ||
        context.read<ChatBloc>().state.isStreaming ||
        context.read<ChatBloc>().state.historyLoading) {
      return;
    }
    context.read<ChatBloc>().add(ChatSubmitted(_input.text, connection));
    _input.clear();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<ConnectionBloc, ServerConnectionState>(
    builder: (context, connectionState) {
      final connected = connectionState.status == ConnectionStatus.connected;
      return BlocConsumer<ChatBloc, ChatState>(
        listener: (context, state) {
          final nearBottom =
              !_scroll.hasClients ||
              _scroll.position.maxScrollExtent - _scroll.offset < 120;
          if (nearBottom) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _scroll.hasClients) {
                _scroll.jumpTo(_scroll.position.maxScrollExtent);
              }
            });
          }
        },
        builder: (context, state) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trò chuyện',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Muse Spark · Văn bản',
                          style: TextStyle(
                            color: StudioColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Tooltip(
                    message: connected ? 'Đã kết nối' : 'Chưa kết nối',
                    child: Semantics(
                      label: connected ? 'Đã kết nối' : 'Chưa kết nối',
                      child: Icon(
                        connected ? Icons.circle : Icons.circle_outlined,
                        size: 9,
                        color: connected
                            ? Colors.tealAccent
                            : StudioColors.muted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (MediaQuery.sizeOf(context).width >= 700)
                    Text(
                      connected ? 'Đã kết nối' : 'Chưa kết nối',
                      style: const TextStyle(fontSize: 12),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Lịch sử trò chuyện',
                    onPressed: connected
                        ? () => showChatHistory(context)
                        : null,
                    icon: const Icon(Icons.history),
                  ),
                  IconButton(
                    tooltip: 'Tạo ảnh từ mô tả gần nhất',
                    icon: const Icon(Icons.image_outlined),
                    onPressed: () {
                      final prompts = state.messages.where(
                        (m) => m.role == MessageRole.user,
                      );
                      widget.onCreateImage(
                        _input.text.trim().isNotEmpty
                            ? _input.text
                            : prompts.isEmpty
                            ? ''
                            : prompts.last.content,
                      );
                    },
                  ),
                  IconButton(
                    tooltip: 'Cuộc trò chuyện mới',
                    onPressed: state.messages.isEmpty
                        ? null
                        : () => context.read<ChatBloc>().add(ChatCleared()),
                    icon: const Icon(Icons.edit_square),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white10),
            if (state.historyLoading) const LinearProgressIndicator(),
            if (state.historyError != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                child: Semantics(
                  liveRegion: true,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          state.historyError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => state.messages.isEmpty
                            ? context.read<ChatBloc>().add(
                                ChatSessionChanged(connectionState.connection),
                              )
                            : context.read<ChatBloc>().add(
                                ChatHistoryFlushed(),
                              ),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: state.messages.isEmpty
                  ? _welcome(connected)
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(24),
                      itemCount: state.messages.length,
                      itemBuilder: (context, index) {
                        final message = state.messages[index];
                        final user = message.role == MessageRole.user;
                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 840),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: user
                                        ? StudioColors.raised
                                        : StudioColors.selected,
                                    child: Icon(
                                      user
                                          ? Icons.person_outline
                                          : Icons.auto_awesome,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user ? 'Bạn' : 'Muse',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        if (message.content.isEmpty)
                                          const Text(
                                            'Đang suy nghĩ…',
                                            style: TextStyle(
                                              color: Colors.white54,
                                            ),
                                          )
                                        else
                                          SelectionArea(
                                            child: Text(
                                              message.content,
                                              style: const TextStyle(
                                                height: 1.7,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (state.error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                color: Theme.of(context).colorScheme.errorContainer
                    .withValues(alpha: 0.3),
                child: Text(
                  state.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _input,
                              enabled:
                                  connected &&
                                  !state.isStreaming &&
                                  !state.historyLoading,
                              minLines: 1,
                              maxLines: 5,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _send(),
                              decoration: InputDecoration(
                                hintText: connected
                                    ? 'Bạn muốn khám phá điều gì?'
                                    : 'Kết nối server để bắt đầu',
                                contentPadding: const EdgeInsets.all(18),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          if (state.isStreaming)
                            IconButton.filled(
                              tooltip: 'Dừng phản hồi',
                              onPressed: () =>
                                  context.read<ChatBloc>().add(ChatStopped()),
                              icon: const Icon(Icons.stop_rounded),
                            )
                          else
                            IconButton.filled(
                              tooltip: 'Gửi tin nhắn',
                              onPressed: connected ? _send : null,
                              icon: const Icon(Icons.arrow_upward_rounded),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Muse có thể mắc lỗi. Hãy kiểm tra thông tin quan trọng.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: StudioColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
  Widget _welcome(bool connected) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: StudioColors.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 36,
                color: StudioColors.accent,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Trò chuyện cùng Muse',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const Text(
              'Đặt câu hỏi, viết nội dung hoặc trao đổi về mã nguồn.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, height: 1.8),
            ),
            const SizedBox(height: 28),
            if (!connected)
              FilledButton.icon(
                onPressed: widget.onConfigure,
                icon: const Icon(Icons.link),
                label: const Text('Kết nối server'),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children:
                    [
                          'Giải thích một ý tưởng',
                          'Giúp tôi viết code',
                          'Lên kế hoạch hôm nay',
                        ]
                        .map(
                          (text) => ActionChip(
                            label: Text(text),
                            onPressed: () {
                              _input.text = text;
                            },
                          ),
                        )
                        .toList(),
              ),
          ],
        ),
      ),
    ),
  );
}
