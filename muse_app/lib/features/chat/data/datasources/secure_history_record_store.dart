import '../../../../core/storage/secure_storage_access.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'history_record_store.dart';

class SecureHistoryRecordStore implements HistoryRecordStore {
  const SecureHistoryRecordStore([this.storage = const FlutterSecureStorage()]);
  final FlutterSecureStorage storage;
  @override
  Future<String?> read(String key) =>
      secureStorageAccess(() => storage.read(key: key));
  @override
  Future<void> write(String key, String value) =>
      secureStorageAccess(() => storage.write(key: key, value: value));
}
