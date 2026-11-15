import '../../../../core/domain/generation_task.dart';
import '../../../connection/domain/entities/server_connection.dart';
import '../repositories/task_repository.dart';

class LoadTasks {
  const LoadTasks(this.repository);
  final TaskRepository repository;
  Future<List<GenerationTask>> call(ServerConnection connection) =>
      repository.list(connection);
}
