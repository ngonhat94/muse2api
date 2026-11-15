import '../../../../core/network/json_api_client.dart';
import '../../../connection/domain/entities/server_connection.dart';
import '../../domain/entities/account_proxy.dart';
import '../../domain/repositories/proxy_repository.dart';

class ProxyRepositoryImpl implements ProxyRepository {
  const ProxyRepositoryImpl(this.api);
  final JsonApiClient api;
  Map<String, dynamic> _json(ProxyConfiguration p) => {
    'server': p.server,
    'username': p.username,
    'password': ?p.password,
  };
  @override
  Future<void> save(
    ServerConnection c,
    String id,
    ProxyConfiguration? p,
  ) async {
    await api.request(
      c,
      '/admin/accounts/${Uri.encodeComponent(id)}',
      method: 'PATCH',
      body: {'proxy': p == null ? null : _json(p)},
    );
  }

  @override
  Future<ProxyCheck> test(
    ServerConnection c,
    String id,
    ProxyConfiguration p,
  ) async {
    final json = await api.request(
      c,
      '/admin/accounts/${Uri.encodeComponent(id)}/proxy/test',
      method: 'POST',
      body: {'proxy': _json(p)},
      timeout: const Duration(seconds: 60),
    );
    return ProxyCheck(
      reachable: json['proxy_reachable'] == true,
      sessionConfirmed: json['ok'] == true && json['session_ok'] == true,
      exitIp: json['exit_ip'] as String?,
    );
  }
}
