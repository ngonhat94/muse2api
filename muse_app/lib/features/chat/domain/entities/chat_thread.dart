import 'chat_message.dart';

class ChatThread {
  ChatThread({
    required this.id,
    required this.updatedAt,
    required List<ChatMessage> messages,
  }) : messages = List.unmodifiable(messages);
  final String id;
  final DateTime updatedAt;
  final List<ChatMessage> messages;
  String get title {
    final text =
        messages
            .where((m) => m.role == MessageRole.user)
            .firstOrNull
            ?.content
            .trim() ??
        'Cuộc trò chuyện';
    return text.length > 80 ? '${text.substring(0, 80)}…' : text;
  }
}
