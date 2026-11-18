import 'package:bloc/bloc.dart';

import '../../domain/entities/server_connection.dart';
import '../../domain/repositories/client_config_repository.dart';

class ClientConfigState {
  const ClientConfigState({this.busy = false, this.message});
  final bool busy;
  final String? message;
}

class ClientConfigCubit extends Cubit<ClientConfigState> {
  ClientConfigCubit(this.repository, this.connection)
    : super(const ClientConfigState());
  final ClientConfigRepository repository;
  final ServerConnection connection;
  Future<void> save(String address) async {
    if (state.busy) return;
    emit(const ClientConfigState(busy: true));
    try {
      await repository.save(connection, address);
      if (!isClosed)
        emit(
          const ClientConfigState(
            message: 'Đã lưu cấu hình chung. Phiên hiện tại không đổi; ngắt kết nối rồi mở lại ứng dụng để dùng địa chỉ mới.',
          ),
        );
    } catch (_) {
      if (!isClosed)
        emit(
          const ClientConfigState(
            message: 'Không lưu được. Kiểm tra URL HTTPS và quyền quản trị server bootstrap.',
          ),
        );
    }
  }
}
