import '../entities/server_connection.dart';

abstract interface class ConnectionRepository {
  String? get savedAddress;
  Future<void> verify(ServerConnection connection);
  Future<ServerConnection?> readSavedConnection();
  Future<void> saveConnection(ServerConnection connection);
  Future<void> forgetConnection();
}
