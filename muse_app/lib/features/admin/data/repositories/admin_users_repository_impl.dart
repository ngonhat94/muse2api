import '../../../../core/errors/app_failure.dart';
import '../../../../core/network/json_api_client.dart';
import '../../../connection/domain/entities/server_connection.dart';
import '../../domain/repositories/admin_users_repository.dart';

class AdminUsersRepositoryImpl implements AdminUsersRepository {
  const AdminUsersRepositoryImpl(this.api);
  final JsonApiClient api;

  void _authorize(ServerConnection connection) {
    if (!canManageUsers(connection)) {
      throw const AppFailure('Bạn không có quyền quản lý người dùng.');
    }
  }

  String _path(String id) => '/admin/users/${Uri.encodeComponent(id)}';
  String _key(Map<String, dynamic> response) {
    final key = response['api_key'];
    if (key is! String || key.isEmpty) {
      throw const AppFailure('Server không trả về API key mới.');
    }
    return key;
  }

  @override
  Future<List<AdminUser>> list(ServerConnection connection) async {
    _authorize(connection);
    final response = await api.request(connection, '/admin/users');
    final users = response['users'];
    if (users is! List) {
      throw const AppFailure('Danh sách người dùng không hợp lệ.');
    }
    return users
        .whereType<Map>()
        .map(
          (user) => AdminUser(
            id: user['id'] as String,
            label: user['label'] as String,
            enabled: user['enabled'] == true,
            keyRevealable: user['key_revealable'] == true,
          ),
        )
        .toList();
  }

  @override
  Future<String> create(ServerConnection connection, String label) async {
    _authorize(connection);
    return _key(
      await api.request(
        connection,
        '/admin/users',
        method: 'POST',
        body: {'label': label},
      ),
    );
  }

  @override
  Future<String> reveal(ServerConnection connection, String id) async {
    _authorize(connection);
    return _key(
      await api.request(connection, '${_path(id)}/key/reveal', method: 'POST'),
    );
  }

  @override
  Future<String> rotate(ServerConnection connection, String id) async {
    _authorize(connection);
    return _key(
      await api.request(connection, '${_path(id)}/key', method: 'POST'),
    );
  }

  @override
  Future<void> setEnabled(
    ServerConnection connection,
    String id,
    bool enabled,
  ) async {
    _authorize(connection);
    await api.request(
      connection,
      _path(id),
      method: 'PATCH',
      body: {'enabled': enabled},
    );
  }

  @override
  Future<void> revoke(ServerConnection connection, String id) async {
    _authorize(connection);
    await api.request(connection, '${_path(id)}/key', method: 'DELETE');
  }
}
