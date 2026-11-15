import '../../../../core/network/reference_payload.dart';
import '../../../../core/domain/reference_image.dart';

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/errors/app_failure.dart';
import '../../../../core/network/api_error.dart';
import '../../../connection/domain/entities/server_connection.dart';
import '../../domain/entities/image_task.dart';
import '../models/image_task_model.dart';

class ImageRemoteDataSource {
  const ImageRemoteDataSource(this.clientFactory);
  final http.Client Function() clientFactory;
  Future<ImageTask> create(
    ServerConnection connection,
    String prompt,
    String ratio,
    String key, {
    List<ReferenceImage> references = const [],
  }) => _request(
    connection,
    '/v1/images/tasks',
    body: {
      'prompt': prompt, 'model': 'muse-image', 'size': ratio, 'n': 1,
      // The server returns bytes when complete, so previews also work behind proxies.
      'response_format': 'b64_json',
      if (references.isNotEmpty) 'images': referencePayload(references),
    },
    requestKey: key,
  );
  Future<ImageTask> get(ServerConnection connection, String id) =>
      _request(connection, '/v1/images/tasks/${Uri.encodeComponent(id)}');
  Future<ImageTask> _request(
    ServerConnection connection,
    String path, {
    Map<String, dynamic>? body,
    String? requestKey,
  }) async {
    final client = clientFactory();
    try {
      final headers = {
        ...connection.headers,
        'Accept': 'application/json',
        if (body != null) 'Content-Type': 'application/json',
        'Idempotency-Key': ?requestKey,
      };
      final response =
          await (body == null
                  ? client.get(connection.endpoint(path), headers: headers)
                  : client.post(
                      connection.endpoint(path),
                      headers: headers,
                      body: jsonEncode(body),
                    ))
              .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 && response.statusCode != 202) {
        throw apiError(response.statusCode, response.body);
      }
      return ImageTaskModel.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure(
        'Không lấy được tác vụ ảnh. Kiểm tra kết nối rồi thử lại.',
      );
    } finally {
      client.close();
    }
  }
}
