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
    } catch (_) {
      throw const AppFailure(
        'Không kết nối được. Kiểm tra URL, mạng và cấu hình CORS/HTTPS của server.',
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
