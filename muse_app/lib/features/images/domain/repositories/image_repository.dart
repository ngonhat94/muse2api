import '../../../../core/domain/reference_image.dart';
import '../../../connection/domain/entities/server_connection.dart';
import '../entities/image_task.dart';

abstract interface class ImageRepository {
  Future<ImageTask> create(
    ServerConnection connection,
    String prompt,
    String ratio,
    String requestKey, {
    List<ReferenceImage> references = const [],
  });
  Future<ImageTask> get(ServerConnection connection, String id);
}
