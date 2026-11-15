import '../../../connection/domain/entities/server_connection.dart';
import '../entities/storage_usage.dart';

abstract interface class StorageRepository {
  Future<StorageUsage> loadStorage(ServerConnection connection);
}
