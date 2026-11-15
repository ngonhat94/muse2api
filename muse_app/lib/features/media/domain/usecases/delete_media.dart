import '../../../connection/domain/entities/server_connection.dart';
import '../entities/media_delete_result.dart';
import '../entities/media_item.dart';
import '../entities/media_name.dart';
import '../repositories/media_repository.dart';

class DeleteMedia {
  const DeleteMedia(this.repository);
  final MediaRepository repository;
  Future<MediaDeleteResult> call(
    ServerConnection connection,
    List<String> names,
    List<MediaItem> library,
  ) async {
    final unique = names.toSet().toList();
    if (unique.isEmpty ||
        unique.any(
          (name) =>
              !isDeletableMediaName(name) ||
              !library.any((item) => item.name == name),
        )) {
      throw ArgumentError('Select media from the library');
    }
    if (unique.length == 1) {
      await repository.deleteSingle(connection, unique.single);
      return const MediaDeleteResult(removed: 1, errorCount: 0);
    }
    return repository.deleteBatch(connection, unique);
  }
}
