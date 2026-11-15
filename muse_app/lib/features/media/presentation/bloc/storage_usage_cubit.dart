import 'package:bloc/bloc.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../connection/domain/entities/server_connection.dart';
import '../../domain/entities/storage_usage.dart';
import '../../domain/repositories/storage_repository.dart';

class StorageUsageState {
  const StorageUsageState({this.loading = false, this.usage, this.error});
  final bool loading;
  final StorageUsage? usage;
  final String? error;
}

class StorageUsageCubit extends Cubit<StorageUsageState> {
  StorageUsageCubit(this.repository) : super(const StorageUsageState());
  final StorageRepository repository;
  ServerConnection? _connection;
  int _attempt = 0;
  void bind(ServerConnection? connection) {
    if (identical(_connection, connection)) return;
    _connection = connection;
    ++_attempt;
    emit(const StorageUsageState());
  }

  Future<void> refresh() async {
    final connection = _connection;
    if (connection == null ||
        state.loading ||
        !(connection.principal?.can('media') ?? connection.isLocal)) {
      return;
    }
    final attempt = ++_attempt;
    emit(const StorageUsageState(loading: true));
    try {
      final usage = await repository.loadStorage(connection);
      if (!isClosed && attempt == _attempt) {
        emit(StorageUsageState(usage: usage));
      }
    } catch (error) {
      if (!isClosed && attempt == _attempt) {
        // AppFailure contains sanitized transport messages; never arbitrary exceptions.
        emit(
          StorageUsageState(
            error: error is AppFailure ? error.message : 'Không tải được lưu trữ. Dữ liệu chưa rõ; thử làm mới hoặc liên hệ quản trị viên.',
          ),
        );
      }
    }
  }
}
