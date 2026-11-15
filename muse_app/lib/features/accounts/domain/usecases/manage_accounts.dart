import '../entities/account_import_draft.dart';
import '../../../connection/domain/entities/server_connection.dart';
import '../entities/muse_account.dart';
import '../repositories/account_repository.dart';
import '../repositories/account_cookies_repository.dart';

class ManageAccounts {
  const ManageAccounts(this.repository);
  final AccountRepository repository;
  Future<List<MuseAccount>> list(ServerConnection connection) =>
      repository.list(connection);
  Future<String> import(
    ServerConnection connection,
    String label,
    String cookieHeader,
  ) async {
    AccountImportDraft.parse(label, cookieHeader);
    return repository.import(connection, label, cookieHeader);
  }

  Future<String> updateCookies(
    ServerConnection connection,
    String id,
    String cookieHeader,
  ) => (repository as AccountCookiesRepository).updateCookies(
    connection,
    id,
    cookieHeader,
  );
  Future<String> act(
    ServerConnection connection,
    String id,
    AccountAction action,
  ) => repository.act(connection, id, action);
}
