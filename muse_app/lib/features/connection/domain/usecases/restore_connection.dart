import '../entities/server_connection.dart';
import '../repositories/connection_repository.dart';

class RestoreConnection {
  const RestoreConnection(this.repository);
  final ConnectionRepository repository;
  Future<ServerConnection?> call() => repository.readSavedConnection();
}

class ForgetConnection {
  const ForgetConnection(this.repository);
  final ConnectionRepository repository;
  Future<void> call() => repository.forgetConnection();
}
