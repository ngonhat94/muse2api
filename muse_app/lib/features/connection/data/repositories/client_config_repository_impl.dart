import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/server_connection.dart';
import '../../domain/repositories/client_config_repository.dart';

class ClientConfigRepositoryImpl implements ClientConfigRepository {
  ClientConfigRepositoryImpl(this.factory);
  final http.Client Function() factory;
  String _decode(http.Response response) {
    if (response.statusCode != 200) throw const FormatException();
    final data = jsonDecode(response.body);
    return validateSharedServerUrl(data['server_url'] as String);
  }

  @override
  Future<String> load() async {
    final client = factory();
    try {
      final origin = validateSharedServerUrl(bootstrapServerUrl);
      // No Authorization and no redirect chaining to another directory.
      final request = http.Request(
        'GET',
        Uri.parse('$origin/public/client-config'),
      )..followRedirects = false;
      return _decode(
        await http.Response.fromStream(
          await client.send(request).timeout(const Duration(seconds: 5)),
        ).timeout(const Duration(seconds: 5)),
      );
    } catch (_) {
      return defaultServerUrl;
    } finally {
      client.close();
    }
  }

  @override
  Future<String> save(ServerConnection connection, String address) async {
    if (connection.principal?.isAdmin != true ||
        connection.principal?.can('global_settings') != true) {
      throw const AppFailure('Chỉ quản trị viên được lưu cấu hình server.');
    }
    final value = validateSharedServerUrl(address.trim());
    final client = factory();
    try {
      // Always write to the pinned directory, never to an editable destination.
      final origin = validateSharedServerUrl(bootstrapServerUrl);
      if (connection.baseUrl != origin) {
        throw const AppFailure(
          'Đăng nhập server bootstrap để sửa cấu hình chung.',
        );
      }
      final request =
          http.Request('POST', Uri.parse('$origin/admin/client-config'))
            ..followRedirects = false
            ..headers.addAll({
              ...connection.headers,
              'Content-Type': 'application/json',
            })
            ..body = jsonEncode({'server_url': value});
      _decode(
        await http.Response.fromStream(
          await client.send(request).timeout(const Duration(seconds: 5)),
        ).timeout(const Duration(seconds: 10)),
      );
      final read = http.Request(
        'GET',
        Uri.parse('$origin/public/client-config'),
      )..followRedirects = false;
      final saved = _decode(
        await http.Response.fromStream(
          await client.send(read).timeout(const Duration(seconds: 5)),
        ).timeout(const Duration(seconds: 5)),
      );
      if (saved != value) throw const FormatException();
      return saved;
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure('Không lưu hoặc xác minh được cấu hình server.');
    } finally {
      client.close();
    }
  }
}
