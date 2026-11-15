import '../../../../core/domain/reference_image.dart';
import '../../../../core/domain/generation_task.dart';
import '../../../connection/domain/entities/server_connection.dart';
import '../repositories/video_repository.dart';

class GenerateVideo {
  const GenerateVideo(this.repository);
  final VideoRepository repository;
  Future<GenerationTask> call(
    ServerConnection connection,
    String prompt,
    String ratio,
    int duration, {
    String? requestKey,
    List<ReferenceImage> references = const [],
  }) => repository.create(
    connection,
    prompt,
    ratio,
    duration,
    requestKey: requestKey,
    references: references,
  );
}

class GetVideoTask {
  const GetVideoTask(this.repository);
  final VideoRepository repository;
  Future<GenerationTask> call(ServerConnection connection, String id) =>
      repository.get(connection, id);
}
