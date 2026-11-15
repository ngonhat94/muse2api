import '../../../connection/domain/entities/server_connection.dart';
import '../entities/keepalive_status.dart';

abstract interface class KeepaliveStatusRepository {
  Future<KeepaliveStatus> keepaliveStatus(ServerConnection connection);
}
