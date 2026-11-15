import '../../../connection/domain/entities/server_connection.dart';
import '../entities/server_status.dart';
import '../repositories/server_status_repository.dart';

class LoadServerStatus {
  const LoadServerStatus(this.repository);
  final ServerStatusRepository repository;
  Future<ServerStatus> call(ServerConnection connection) =>
      repository.load(connection);
}
