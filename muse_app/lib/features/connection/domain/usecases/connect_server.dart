import '../entities/server_connection.dart';
import '../repositories/connection_repository.dart';

class ConnectServer {
  const ConnectServer(this.repository);
  final ConnectionRepository repository;
  Future<ServerConnection> call(String address, String apiKey) async {
    final connection = ServerConnection.parse(address, apiKey);
    await repository.verify(connection);
    await repository.saveConnection(connection);
    return connection;
  }
}
