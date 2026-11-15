import '../../../connection/domain/entities/server_connection.dart';
import '../entities/media_item.dart';
import '../entities/media_delete_result.dart';

abstract interface class MediaRepository {
  Future<List<MediaItem>> list(ServerConnection connection);
  Future<void> deleteSingle(ServerConnection connection, String name);
  Future<MediaDeleteResult> deleteBatch(
    ServerConnection connection,
    List<String> names,
  );
}
