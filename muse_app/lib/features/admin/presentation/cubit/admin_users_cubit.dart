import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../connection/domain/entities/server_connection.dart';
import '../../domain/repositories/admin_users_repository.dart';

class AdminUsersState {
  const AdminUsersState({
    this.users = const [],
    this.loading = false,
    this.mutating = false,
    this.error,
    this.oneTimeKey,
  });
  final List<AdminUser> users;
  final bool loading;
  final bool mutating;
  final String? error;
  // Memory only. Never serialize or send this state to logging/storage.
  final String? oneTimeKey;
}

class AdminUsersCubit extends Cubit<AdminUsersState> {
  AdminUsersCubit(this.repository) : super(const AdminUsersState());
  final AdminUsersRepository repository;
  ServerConnection? _connection;
  int _generation = 0;

  void connect(ServerConnection? connection) {
    _generation++;
    _connection = connection;
    emit(const AdminUsersState());
    if (canManageUsers(connection)) load();
  }

  bool _current(int generation) =>
      !isClosed && generation == _generation && canManageUsers(_connection);

  Future<void> load() async {
    final connection = _connection;
    if (!canManageUsers(connection) || state.loading) return;
    final generation = _generation;
    emit(
      AdminUsersState(
        users: state.users,
        loading: true,
        mutating: state.mutating,
        oneTimeKey: state.oneTimeKey,
      ),
    );
    try {
      final users = await repository.list(connection!);
      if (_current(generation)) {
        emit(
          AdminUsersState(
            users: users,
            mutating: state.mutating,
            oneTimeKey: state.oneTimeKey,
          ),
        );
      }
    } catch (_) {
      if (_current(generation)) {
        emit(
          AdminUsersState(
            users: state.users,
            mutating: state.mutating,
            oneTimeKey: state.oneTimeKey,
            error: 'Không tải được người dùng. Hãy thử tải lại.',
          ),
        );
      }
    }
  }

  Future<void> create(String label) async {
    if (label.trim().isEmpty) {
      emit(AdminUsersState(users: state.users, error: 'Nhập tên người dùng.'));
      return;
    }
    await _mutate((connection) => repository.create(connection, label.trim()));
  }

  Future<void> rotate(AdminUser user) =>
      _mutate((connection) => repository.rotate(connection, user.id));
  Future<void> toggle(AdminUser user) => _mutate((connection) async {
    await repository.setEnabled(connection, user.id, !user.enabled);
    return null;
  });
  Future<void> revoke(AdminUser user) => _mutate((connection) async {
    await repository.revoke(connection, user.id);
    return null;
  });

  Future<void> _mutate(
    Future<String?> Function(ServerConnection) operation,
  ) async {
    final connection = _connection;
    if (!canManageUsers(connection) || state.mutating || state.loading) return;
    final generation = _generation;
    emit(AdminUsersState(users: state.users, mutating: true));
    try {
      final key = await operation(connection!);
      if (!_current(generation)) return;
      emit(
        AdminUsersState(users: state.users, mutating: true, oneTimeKey: key),
      );
      await load();
      if (_current(generation)) {
        emit(
          AdminUsersState(
            users: state.users,
            error: state.error,
            oneTimeKey: state.oneTimeKey,
          ),
        );
      }
    } catch (_) {
      if (_current(generation)) {
        // Do not expose raw server errors: they may include credentials.
        emit(
          AdminUsersState(
            users: state.users,
            error: const AppFailure(
              'Không thể hoàn tất thao tác. Kiểm tra kết nối rồi thử lại.',
            ).message,
          ),
        );
      }
    }
  }

  void dismissKey() => emit(
    AdminUsersState(
      users: state.users,
      loading: state.loading,
      mutating: state.mutating,
      error: state.error,
    ),
  );

  @override
  Future<void> close() {
    _generation++;
    _connection = null;
    return super.close();
  }
}
