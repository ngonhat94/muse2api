import '../../../../core/domain/reference_image.dart';
import '../../../../core/domain/generation_task.dart';
import '../../../connection/domain/entities/server_connection.dart';

abstract interface class VideoRepository {
  Future<GenerationTask> create(
    ServerConnection connection,
    String prompt,
    String ratio,
    int duration, {
    String? requestKey,
    List<ReferenceImage> references = const [],
  });
  Future<GenerationTask> get(ServerConnection connection, String id);
}
