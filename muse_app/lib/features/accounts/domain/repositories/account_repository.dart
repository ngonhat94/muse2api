import '../../../connection/domain/entities/server_connection.dart';
import '../entities/muse_account.dart';

enum AccountAction { enable, disable, test, quota, remove, keepalive }

abstract interface class AccountRepository {
  Future<List<MuseAccount>> list(ServerConnection connection);
  Future<String> import(
    ServerConnection connection,
    String label,
    String cookieHeader,
  );
  Future<String> act(
    ServerConnection connection,
    String id,
    AccountAction action,
  );
}
