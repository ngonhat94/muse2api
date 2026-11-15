import '../../../connection/domain/entities/server_connection.dart';
import '../entities/chat_message.dart';

abstract interface class ChatRepository {
  Stream<String> streamReply(
    ServerConnection connection,
    List<ChatMessage> messages,
  );
}
