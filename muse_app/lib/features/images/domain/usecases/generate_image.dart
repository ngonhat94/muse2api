import '../../../../core/domain/reference_image.dart';
import '../../../connection/domain/entities/server_connection.dart';
import '../entities/image_task.dart';
import '../repositories/image_repository.dart';

class GenerateImage {
  const GenerateImage(this.repository);
  final ImageRepository repository;
  Future<ImageTask> call(
    ServerConnection connection,
    String prompt,
    String ratio,
    String key, {
    List<ReferenceImage> references = const [],
  }) =>
      repository.create(connection, prompt, ratio, key, references: references);
}

class GetImageTask {
  const GetImageTask(this.repository);
  final ImageRepository repository;
  Future<ImageTask> call(ServerConnection connection, String id) =>
      repository.get(connection, id);
}
