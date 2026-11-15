import '../../../connection/domain/entities/server_connection.dart';
import '../entities/account_proxy.dart';

abstract interface class ProxyRepository {
  Future<void> save(
    ServerConnection connection,
    String id,
    ProxyConfiguration? proxy,
  );
  Future<ProxyCheck> test(
    ServerConnection connection,
    String id,
    ProxyConfiguration proxy,
  );
}
