import 'dart:async';

import 'package:http/http.dart' as http;

import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/server_connection.dart';
import '../../domain/repositories/connection_repository.dart';
import '../datasources/connection_local_data_source.dart';
import '../datasources/connection_remote_data_source.dart';

class ConnectionRepositoryImpl implements ConnectionRepository {
  const ConnectionRepositoryImpl(this.remote, this.local);
  final ConnectionRemoteDataSource remote;
  final ConnectionLocalDataSource local;
  @override
  String? get savedAddress => local.address;
  @override
  Future<ServerConnection?> readSavedConnection() => local.readConnection();
  @override
  Future<void> forgetConnection() => local.forgetConnection();
  @override
  Future<void> verify(ServerConnection connection) async {
    try {
      await remote.verify(connection);
    } on AppFailure {
      rethrow;
    } on TimeoutException {
      throw const AppFailure('Server phản hồi quá chậm. Vui lòng thử lại sau.');
    } on http.ClientException {
      // Browsers cannot distinguish offline/TLS/CORS failures. Never infer 401.
      throw const AppFailure(
        'Không kết nối được với server. Kiểm tra mạng rồi thử lại; nếu vẫn lỗi, liên hệ quản trị viên kiểm tra server và cấu hình CORS/HTTPS.',
      );
    } catch (_) {
      throw const AppFailure(
        'Server trả về phản hồi không hợp lệ. Vui lòng thử lại hoặc liên hệ quản trị viên.',
      );
    }
  }

  @override
  Future<void> saveConnection(ServerConnection connection) async {
    try {
      await local.saveConnection(connection);
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure(
        'Không lưu được API key trên thiết bị. Kiểm tra quyền lưu trữ rồi thử lại.',
      );
    }
  }
}
