import '../../../../core/domain/reference_image.dart';
import '../../../connection/domain/entities/server_connection.dart';
import '../../domain/entities/image_task.dart';
import '../../domain/repositories/image_repository.dart';
import '../datasources/image_remote_data_source.dart';

class ImageRepositoryImpl implements ImageRepository {
  const ImageRepositoryImpl(this.remote);
  final ImageRemoteDataSource remote;
  @override
  Future<ImageTask> create(
    ServerConnection connection,
    String prompt,
    String ratio,
    String key, {
    List<ReferenceImage> references = const [],
  }) => remote.create(connection, prompt, ratio, key, references: references);
  @override
  Future<ImageTask> get(ServerConnection connection, String id) =>
      remote.get(connection, id);
}
