import '../../../connection/domain/entities/server_connection.dart';

bool canManageUsers(ServerConnection? connection) =>
    connection?.principal?.isAdmin == true &&
    connection?.principal?.can('manage_users') == true;

class AdminUser {
  const AdminUser({
    required this.id,
    required this.label,
    required this.enabled,
    this.keyRevealable = false,
  });
  final String id;
  final String label;
  final bool enabled;
  final bool keyRevealable;
}

abstract class AdminUsersRepository {
  Future<List<AdminUser>> list(ServerConnection connection);
  Future<String> create(ServerConnection connection, String label);
  Future<String> reveal(ServerConnection connection, String id);
  Future<String> rotate(ServerConnection connection, String id);
  Future<void> setEnabled(ServerConnection connection, String id, bool enabled);
  Future<void> revoke(ServerConnection connection, String id);
}
