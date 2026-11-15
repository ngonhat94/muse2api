import '../../../connection/domain/entities/server_connection.dart';
import '../entities/chat_thread.dart';

abstract interface class ChatHistoryRepository {
  Future<List<ChatThread>> list(ServerConnection connection);
  Future<void> save(ServerConnection connection, ChatThread thread);
  Future<void> delete(ServerConnection connection, String id);
}
