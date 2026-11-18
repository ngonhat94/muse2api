import '../domain/repositories/browser_account_import.dart';
import '../../connection/domain/entities/server_connection.dart';

class BrowserImport implements BrowserAccountImport {
  @override
  BrowserImportCapability get capability => BrowserImportCapability.native;
  @override
  bool get supported => false;
  @override
  Future<bool> available() async => false;
  @override
  Future<String> prepare() async => throw UnsupportedError('desktop web only');
  @override
  Future<String> approve(String id, ServerConnection c) async => 'unavailable';
  @override
  Future<String> commit(String id, ServerConnection c) async => 'unavailable';
  @override
  void cancel(String id) {}
}
