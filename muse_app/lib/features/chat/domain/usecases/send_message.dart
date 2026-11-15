import '../../../connection/domain/entities/server_connection.dart';
import '../entities/chat_message.dart';
import '../repositories/chat_repository.dart';

class SendMessage {
  const SendMessage(this.repository);
  final ChatRepository repository;
  Stream<String> call(
    ServerConnection connection,
    List<ChatMessage> messages,
  ) => repository.streamReply(connection, List.unmodifiable(messages));
}
