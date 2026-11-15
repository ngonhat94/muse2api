import '../domain/generation_task.dart';
import '../errors/app_failure.dart';
import '../../features/connection/domain/entities/server_connection.dart';
import 'media_uri.dart';

GenerationTask decodeTask(
  Map<String, dynamic> json, {
  String? kind,
  ServerConnection? connection,
}) {
  final id = json['id'];
  if (id is! String || id.isEmpty) {
    throw const AppFailure('Server không trả về mã tác vụ.');
  }
  final status = switch (json['status']) {
    'queued' => GenerationStatus.queued,
    'processing' => GenerationStatus.processing,
    'completed' ||
    'succeeded' ||
    'success' ||
    'done' => GenerationStatus.completed,
    'failed' => GenerationStatus.failed,
    _ => throw const AppFailure('Trạng thái tác vụ không hợp lệ.'),
  };
  final result = json['result'];
  final url = json['url'] ?? (result is Map ? result['url'] : null);
  final filename = result is Map ? result['filename'] : null;
  final progress = json['progress'];
  final created = json['created_at'];
  final resolvedFilename = filename is String
      ? filename
      : url is String
      ? Uri.tryParse(url)?.pathSegments.lastOrNull
      : null;
  return GenerationTask(
    id: id,
    kind: kind ?? json['kind'] as String? ?? 'image',
    status: status,
    prompt: json['prompt'] as String? ?? '',
    progress: status == GenerationStatus.completed
        ? 100
        : progress is num
        ? progress.toDouble().clamp(0, 100)
        : 0,
    createdAt: created is num
        ? DateTime.fromMillisecondsSinceEpoch(created.toInt() * 1000)
        : null,
    filename: resolvedFilename,
    protectedUri:
        connection != null && url is String && resolvedFilename != null
        ? protectedMediaUri(connection, url, resolvedFilename)
        : null,
  );
}
