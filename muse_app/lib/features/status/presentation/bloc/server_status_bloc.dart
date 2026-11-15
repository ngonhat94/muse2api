import 'package:bloc/bloc.dart';

import '../../../connection/domain/entities/server_connection.dart';
import '../../domain/entities/server_status.dart';
import '../../domain/usecases/load_server_status.dart';

class ServerStatusState {
  const ServerStatusState({
    this.connection,
    this.snapshot,
    this.updatedAt,
    this.busy = false,
    this.error,
  });
  final ServerConnection? connection;
  final ServerStatus? snapshot;
  final DateTime? updatedAt;
  final bool busy;
  final String? error;
  bool get stale => snapshot != null && error != null;
}

/// Manual reads only. A generation token prevents responses crossing sessions.
class ServerStatusBloc extends Cubit<ServerStatusState> {
  ServerStatusBloc(this.load) : super(const ServerStatusState());
  final LoadServerStatus load;
  int _generation = 0;

  void connectionChanged(ServerConnection? connection) {
    if (isClosed) return;
    if (state.connection?.baseUrl == connection?.baseUrl &&
        state.connection?.apiKey == connection?.apiKey) {
      return;
    }
    _generation++;
    emit(ServerStatusState(connection: connection));
  }

  Future<void> refresh() async {
    final connection = state.connection;
    if (isClosed || state.busy || connection == null) return;
    final generation = _generation;
    final previous = state;
    emit(
      ServerStatusState(
        connection: connection,
        snapshot: previous.snapshot,
        updatedAt: previous.updatedAt,
        busy: true,
      ),
    );
    try {
      final snapshot = await load(connection);
      if (isClosed || generation != _generation) return;
      emit(
        ServerStatusState(
          connection: connection,
          snapshot: snapshot,
          updatedAt: DateTime.now(),
        ),
      );
    } catch (_) {
      if (isClosed || generation != _generation) return;
      emit(
        ServerStatusState(
          connection: connection,
          snapshot: previous.snapshot,
          updatedAt: previous.updatedAt,
          error: 'Không tải được trạng thái. Kiểm tra kết nối hoặc quyền truy cập; server có thể chưa hỗ trợ. Hãy thử tải lại.',
        ),
      );
    }
  }
}
