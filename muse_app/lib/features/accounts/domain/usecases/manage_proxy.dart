import '../../../connection/domain/entities/server_connection.dart';
import '../entities/account_proxy.dart';
import '../repositories/proxy_repository.dart';

class ManageProxy {
  const ManageProxy(this.repository);
  final ProxyRepository repository;
  Future<void> save(ServerConnection c, String id, ProxyConfiguration? proxy) =>
      repository.save(c, id, proxy);
  Future<ProxyCheck> test(
    ServerConnection c,
    String id,
    ProxyConfiguration proxy,
  ) => repository.test(c, id, proxy);
}
