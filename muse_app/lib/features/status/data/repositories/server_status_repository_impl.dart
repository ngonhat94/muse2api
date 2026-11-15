import '../../../../core/network/json_api_client.dart';
import '../../../connection/domain/entities/server_connection.dart';
import '../../domain/entities/server_status.dart';
import '../../domain/repositories/server_status_repository.dart';

class ServerStatusRepositoryImpl implements ServerStatusRepository {
  const ServerStatusRepositoryImpl(this.api);
  final JsonApiClient api;
  @override
  Future<ServerStatus> load(ServerConnection connection) async {
    final data = await api.request(connection, '/admin/status');
    final stats = data['stats'] is Map ? data['stats'] as Map : const {};
    int? count(dynamic value) => value is int && value >= 0 ? value : null;
    return ServerStatus(
      browserRunning: data['browser_running'] is bool
          ? data['browser_running'] as bool
          : null,
      mediaCount: count(data['media_count']),
      totalAccounts: count(stats['total']),
      enabledAccounts: count(stats['enabled']),
      disabledAccounts: count(stats['disabled']),
      healthyAccounts: count(stats['healthy']),
      errorAccounts: count(stats['error']),
      expiringAccounts: count(stats['expiring']),
      expiredAccounts: count(stats['expired']),
    );
  }
}
