import '../../../connection/domain/entities/server_connection.dart';

abstract interface class BrowserAccountImport {
  bool get supported;
  Future<bool> available();
  Future<String> prepare();
  Future<String> approve(String id, ServerConnection connection);
  Future<String> commit(String id, ServerConnection connection);
  void cancel(String id);
}
