import '../../../../core/domain/generation_task.dart';
import '../../../connection/domain/entities/server_connection.dart';

abstract interface class TaskRepository {
  Future<List<GenerationTask>> list(ServerConnection connection);
  Future<void> delete(ServerConnection connection, String id);
  Future<void> cancel(ServerConnection connection, String id);
  Future<int> clear(ServerConnection connection);
}
