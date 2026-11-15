import '../../../connection/domain/entities/server_connection.dart';
import '../entities/chat_thread.dart';
import '../repositories/chat_history_repository.dart';

class ManageChatHistory {
  const ManageChatHistory(this.repository);
  final ChatHistoryRepository repository;
  Future<List<ChatThread>> list(ServerConnection connection) =>
      repository.list(connection);
  Future<void> save(ServerConnection connection, ChatThread thread) =>
      repository.save(connection, thread);
  Future<void> delete(ServerConnection connection, String id) =>
      repository.delete(connection, id);
}
