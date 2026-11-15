import '../../../../core/network/json_api_client.dart';
import '../../domain/entities/storage_usage.dart';
import '../../domain/repositories/storage_repository.dart';
import '../../domain/entities/media_delete_result.dart';
import '../../domain/entities/media_name.dart';
import '../../../connection/domain/entities/server_connection.dart';
import '../../domain/entities/media_item.dart';
import '../../domain/repositories/media_repository.dart';
import '../../../../core/network/media_uri.dart';

class MediaRepositoryImpl implements MediaRepository, StorageRepository {
  @override
  Future<StorageUsage> loadStorage(ServerConnection connection) async {
    final json = await api.request(connection, '/v1/storage');
    int number(dynamic value, {int min = 0}) {
      if (value is! int || value < min || value > 9007199254740991) {
        throw const FormatException('Invalid storage snapshot');
      }
      return value;
    }

    final limits = json['limits'];
    if (limits is! Map) throw const FormatException('Missing limits');
    return StorageUsage(
      bytes: number(json['bytes']),
      files: number(json['files']),
      limitBytes: number(limits['bytes'], min: 1),
      limitFiles: number(limits['files'], min: 1),
      retentionDays: number(limits['retention_days'], min: 1),
    );
  }

  const MediaRepositoryImpl(this.api);
  final JsonApiClient api;
  @override
  Future<MediaDeleteResult> deleteBatch(
    ServerConnection connection,
    List<String> names,
  ) async {
    if (names.isEmpty || names.any((name) => !isDeletableMediaName(name))) {
      throw ArgumentError('Invalid media names');
    }
    final json = await api.request(
      connection,
      '/admin/media/delete',
      method: 'POST',
      body: {'names': names},
    );
    return MediaDeleteResult(
      removed: (json['removed'] as num).toInt(),
      errorCount: (json['errors'] as List).length,
    );
  }

  @override
  Future<void> deleteSingle(ServerConnection connection, String name) async {
    if (!isDeletableMediaName(name)) throw ArgumentError('Invalid media name');
    await api.request(
      connection,
      '/admin/media/${Uri.encodeComponent(name)}',
      method: 'DELETE',
    );
  }

  @override
  Future<List<MediaItem>> list(ServerConnection connection) async {
    final json = await api.request(connection, '/admin/media');
    return (json['media'] as List).map((item) {
      final e = item as Map<String, dynamic>;
      final name = e['name'] as String;
      final url = e['url'];
      if (url is! String) throw const FormatException('Missing media URL');
      return MediaItem(
        name: name,
        isVideo: e['kind'] == 'video',
        bytes: (e['bytes'] as num?)?.toInt() ?? 0,
        createdAt: e['mtime'] is num
            ? DateTime.fromMillisecondsSinceEpoch(
                (e['mtime'] as num).toInt() * 1000,
              )
            : null,
        protectedUri: protectedMediaUri(connection, url, name),
      );
    }).toList();
  }
}
