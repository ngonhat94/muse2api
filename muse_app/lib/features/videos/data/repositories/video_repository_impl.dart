import '../../../../core/network/reference_payload.dart';
import '../../../../core/domain/reference_image.dart';
import '../../../../core/domain/generation_task.dart';
import '../../../../core/network/json_api_client.dart';
import '../../../../core/network/generation_task_decoder.dart';
import '../../../connection/domain/entities/server_connection.dart';
import '../../domain/repositories/video_repository.dart';

class VideoRepositoryImpl implements VideoRepository {
  const VideoRepositoryImpl(this.api);
  final JsonApiClient api;
  @override
  Future<GenerationTask> create(
    ServerConnection connection,
    String prompt,
    String ratio,
    int duration, {
    String? requestKey,
    List<ReferenceImage> references = const [],
  }) async => decodeTask(
    await api.request(
      connection,
      '/v1/videos',
      method: 'POST',
      requestKey: requestKey,
      body: {
        'prompt': prompt,
        'model': 'muse-video',
        'size': ratio,
        'duration': duration,
        if (references.isNotEmpty) 'images': referencePayload(references),
      },
    ),
    kind: 'video',
    connection: connection,
  );
  @override
  Future<GenerationTask> get(ServerConnection connection, String id) async =>
      decodeTask(
        await api.request(connection, '/v1/videos/${Uri.encodeComponent(id)}'),
        kind: 'video',
        connection: connection,
      );
}
