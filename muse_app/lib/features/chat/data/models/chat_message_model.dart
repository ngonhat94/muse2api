import '../../domain/entities/chat_message.dart';

class ChatMessageModel {
  static Map<String, String> toJson(ChatMessage message) => {
    'role': message.role.name,
    'content': message.content,
  };
}
