import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'credential_store.dart';
import 'secure_storage_access.dart';

class SecureCredentialStore implements CredentialStore {
  const SecureCredentialStore([this.storage = const FlutterSecureStorage()]);
  final FlutterSecureStorage storage;
  static const _key = 'muse_server_connection';
  @override
  Future<String?> read() => secureStorageAccess(() => storage.read(key: _key));
  @override
  Future<void> write(String value) =>
      secureStorageAccess(() => storage.write(key: _key, value: value));
  @override
  Future<void> delete() => secureStorageAccess(() => storage.delete(key: _key));
}
