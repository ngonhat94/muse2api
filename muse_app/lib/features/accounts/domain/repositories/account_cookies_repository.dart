import '../../../connection/domain/entities/server_connection.dart';

abstract interface class AccountCookiesRepository {
  Future<String> updateCookies(
    ServerConnection connection,
    String id,
    String cookieHeader,
  );
}
