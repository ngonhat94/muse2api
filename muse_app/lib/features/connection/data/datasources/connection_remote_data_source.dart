import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/errors/app_failure.dart';
import '../../../../core/network/api_error.dart';
import '../../domain/entities/server_connection.dart';

class ConnectionRemoteDataSource {
  const ConnectionRemoteDataSource(this.clientFactory);
  final http.Client Function() clientFactory;
  Future<void> verify(ServerConnection connection) async {
    final client = clientFactory();
    try {
      final response = await client
          .get(connection.endpoint('/v1/models'), headers: connection.headers)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw apiError(response.statusCode, response.body);
      }
      final body = jsonDecode(response.body);
      if (body is! Map || body['data'] is! List) {
        throw const AppFailure(
          'Địa chỉ này không trả về danh sách model hợp lệ.',
        );
      }
      final me = await client
          .get(connection.endpoint('/v1/me'), headers: connection.headers)
          .timeout(const Duration(seconds: 15));
      if (me.statusCode != 200) throw apiError(me.statusCode, me.body);
      final principal = jsonDecode(utf8.decode(me.bodyBytes));
      if (principal is! Map ||
          principal['id'] is! String ||
          principal['label'] is! String ||
          !['admin', 'user'].contains(principal['role']) ||
          principal['capabilities'] is! Map) {
        throw const AppFailure('Server không trả về quyền truy cập hợp lệ.');
      }
      connection.attachPrincipal(
        ServerPrincipal(
          id: principal['id'] as String,
          label: principal['label'] as String,
          role: principal['role'] as String,
          capabilities: (principal['capabilities'] as Map).map(
            (key, value) => MapEntry(key.toString(), value == true),
          ),
        ),
      );
    } finally {
      client.close();
    }
  }
}
