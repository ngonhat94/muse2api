import '../../../../core/domain/generation_task.dart';
import '../../../../core/network/json_api_client.dart';
import '../../../../core/network/generation_task_decoder.dart';
import '../../../connection/domain/entities/server_connection.dart';
import '../../domain/repositories/task_repository.dart';

class TaskRepositoryImpl implements TaskRepository {
  const TaskRepositoryImpl(this.api);
  final JsonApiClient api;
  @override
  Future<int> clear(ServerConnection connection) async {
    final result = await api.request(
      connection,
      '/admin/tasks/clear',
      method: 'POST',
      body: {'keep': 0},
    );
    final removed = result['removed'];
    if (removed is! int || removed < 0) {
      throw const FormatException('Invalid removal count');
    }
    return removed;
  }

  @override
  Future<void> delete(ServerConnection connection, String id) async {
    final result = await api.request(
      connection,
      '/admin/tasks/${Uri.encodeComponent(id)}',
      method: 'DELETE',
    );
    if (result['deleted'] != true) {
      throw const FormatException('Invalid deletion acknowledgement');
    }
  }

  @override
  Future<void> cancel(ServerConnection connection, String id) async {
    final result = await api.request(
      connection,
      '/admin/tasks/${Uri.encodeComponent(id)}/cancel',
      method: 'POST',
    );
    if (result['cancelled'] != true) {
      throw const FormatException('Invalid cancellation acknowledgement');
    }
  }

  @override
  Future<List<GenerationTask>> list(ServerConnection connection) async {
    final json = await api.request(connection, '/admin/tasks?limit=100');
    return (json['tasks'] as List)
        .map(
          (e) => decodeTask(e as Map<String, dynamic>, connection: connection),
        )
        .toList();
  }
}
