import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../features/connection/domain/entities/server_connection.dart';
import '../errors/app_failure.dart';
import 'api_error.dart';

class JsonApiClient {
  const JsonApiClient(this.clientFactory);
  final http.Client Function() clientFactory;
  Future<Map<String, dynamic>> request(
    ServerConnection connection,
    String path, {
    String method = 'GET',
    String? requestKey,
    Map<String, dynamic>? body,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final client = clientFactory();
    try {
      final request = http.Request(method, connection.endpoint(path))
        ..headers.addAll({
          ...connection.headers,
          'Accept': 'application/json',
          'Idempotency-Key': ?requestKey,
          if (body != null) 'Content-Type': 'application/json',
        });
      if (body != null) request.body = jsonEncode(body);
      final response = await (() async => http.Response.fromStream(
        await client.send(request),
      ))().timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw apiError(response.statusCode, response.body);
      }
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure(
        'Không nhận được phản hồi từ server. Kiểm tra kết nối rồi thử lại.',
      );
    } finally {
      client.close();
    }
  }
}
