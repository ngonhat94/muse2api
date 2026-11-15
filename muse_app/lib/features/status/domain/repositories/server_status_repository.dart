import '../../../connection/domain/entities/server_connection.dart';
import '../entities/server_status.dart';

abstract interface class ServerStatusRepository {
  Future<ServerStatus> load(ServerConnection connection);
}
