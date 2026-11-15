import 'package:bloc/bloc.dart';

import '../../../connection/domain/entities/server_connection.dart';
import '../../domain/entities/keepalive_status.dart';
import '../../domain/repositories/keepalive_status_repository.dart';

class KeepaliveStatusState {
  const KeepaliveStatusState({this.status, this.busy = false, this.error});
  final KeepaliveStatus? status;
  final bool busy;
  final String? error;
}

/// One instance per connection identity. No polling or mutation endpoints.
class KeepaliveStatusBloc extends Cubit<KeepaliveStatusState> {
  KeepaliveStatusBloc(this.repository, this.connection)
    : super(const KeepaliveStatusState());
  final KeepaliveStatusRepository repository;
  final ServerConnection connection;

  Future<void> refresh() async {
    if (isClosed || state.busy) return;
    emit(KeepaliveStatusState(status: state.status, busy: true));
    try {
      final status = await repository.keepaliveStatus(connection);
      if (!isClosed) emit(KeepaliveStatusState(status: status));
    } catch (_) {
      if (!isClosed) {
        emit(
          KeepaliveStatusState(
            status: state.status,
            error: 'Không tải được trạng thái. Server có thể chưa hỗ trợ; hãy thử tải lại.',
          ),
        );
      }
    }
  }
}
