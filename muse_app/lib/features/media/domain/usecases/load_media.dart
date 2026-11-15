import '../../../connection/domain/entities/server_connection.dart';
import '../entities/media_item.dart';
import '../repositories/media_repository.dart';

class LoadMedia {
  const LoadMedia(this.repository);
  final MediaRepository repository;
  Future<List<MediaItem>> call(ServerConnection connection) =>
      repository.list(connection);
}
