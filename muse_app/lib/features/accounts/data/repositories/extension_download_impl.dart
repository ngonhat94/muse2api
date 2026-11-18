import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../../../core/errors/app_failure.dart';
import '../../../connection/domain/entities/server_connection.dart';
import '../../domain/repositories/extension_download.dart';

class ExtensionDownloadImpl implements ExtensionDownload {
  const ExtensionDownloadImpl(this.clientFactory);
  final http.Client Function() clientFactory;

  @override
  Future<Uint8List> fetch(ServerConnection connection) async {
    final client = clientFactory();
    try {
      final request =
          http.Request('GET', connection.endpoint('/admin/extension'))
            ..followRedirects = false
            ..headers.addAll({
              ...connection.headers,
              'Accept': 'application/zip',
            });
      final response = await (() async => http.Response.fromStream(
        await client.send(request),
      ))().timeout(const Duration(seconds: 30));
      if (response.statusCode == 401) {
        throw const AppFailure(
          'Phiên đăng nhập đã hết hạn. Hãy đăng nhập lại để tải extension.',
        );
      }
      if (response.statusCode == 403) {
        throw const AppFailure(
          'Máy chủ không cho phép tải extension với tài khoản này.',
        );
      }
      final bytes = response.bodyBytes;
      if (response.statusCode != 200 ||
          !(response.headers['content-type'] ?? '').toLowerCase().startsWith(
            'application/zip',
          ) ||
          bytes.length < 4 ||
          bytes[0] != 0x50 ||
          bytes[1] != 0x4b ||
          bytes[2] != 3 ||
          bytes[3] != 4) {
        throw const AppFailure(
          'Không tải được gói ZIP hợp lệ. Hãy thử lại hoặc liên hệ quản trị viên.',
        );
      }
      return bytes;
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure(
        'Không tải được extension. Kiểm tra kết nối rồi thử lại.',
      );
    } finally {
      client.close();
    }
  }
}
