import '../../domain/entities/account_import_draft.dart';

import 'package:bloc/bloc.dart';

import '../../domain/repositories/batch_keepalive_repository.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../connection/domain/entities/server_connection.dart';
import '../../domain/entities/muse_account.dart';
import '../../domain/repositories/account_repository.dart';
import '../../domain/usecases/manage_accounts.dart';

sealed class AccountEvent {}

class AccountsLoaded extends AccountEvent {
  AccountsLoaded(this.connection);
  final ServerConnection connection;
}

class AccountImported extends AccountEvent {
  AccountImported(this.connection, this.label, this.cookies);
  final ServerConnection connection;
  final String label;
  String cookies;
  @override
  String toString() => 'AccountImported([redacted])';
}

class AccountActed extends AccountEvent {
  AccountActed(this.connection, this.id, this.action);
  final ServerConnection connection;
  final String id;
  final AccountAction action;
}

class AccountCookiesUpdated extends AccountEvent {
  AccountCookiesUpdated(this.connection, this.id, this.cookies);
  final ServerConnection connection;
  final String id;
  String cookies;
  @override
  String toString() => 'AccountCookiesUpdated([redacted])';
}

class AccountsBatchKeepaliveRequested extends AccountEvent {
  AccountsBatchKeepaliveRequested(this.connection);
  final ServerConnection connection;
}

class AccountsCleared extends AccountEvent {}

class AccountState {
  AccountState({
    List<MuseAccount> items = const [],
    this.busy = false,
    this.message,
    this.error,
    this.imported = false,
    this.batchCompleted = false,
  }) : items = List.unmodifiable(items);
  final List<MuseAccount> items;
  final bool busy;
  final String? message;
  final String? error;
  final bool imported;
  final bool batchCompleted;
}

class AccountBloc extends Bloc<AccountEvent, AccountState> {
  AccountBloc(this.manage) : super(AccountState()) {
    on<AccountsLoaded>((event, emit) {
      if (!identical(_connection, event.connection)) {
        ++_generation;
        _connection = event.connection;
        emit(AccountState());
      }
      return _run(event.connection, emit);
    });
    on<AccountsBatchKeepaliveRequested>(_batchKeepalive);
    on<AccountImported>((event, emit) async {
      final cookies = event.cookies;
      event.cookies = '';
      if (state.busy ||
          _mutationPending ||
          !identical(_connection, event.connection)) {
        return;
      }
      try {
        AccountImportDraft.parse(event.label, cookies);
      } on AppFailure catch (error) {
        emit(AccountState(items: state.items, error: error.message));
        return;
      }
      await _run(
        event.connection,
        emit,
        action: () => manage.import(event.connection, event.label, cookies),
        imported: true,
        failureMessage: 'Chưa xác nhận được kết quả nhập tài khoản. Server có thể đã nhận yêu cầu; tải lại danh sách trước khi thử lại.',
      );
    });
    on<AccountActed>((event, emit) async {
      if (event.action == AccountAction.keepalive) {
        await _keepalive(event, emit);
        return;
      }
      await _run(
        event.connection,
        emit,
        action: () => manage.act(event.connection, event.id, event.action),
      );
    });
    on<AccountCookiesUpdated>((event, emit) async {
      if (state.busy ||
          _mutationPending ||
          !identical(_connection, event.connection) ||
          !state.items.any((a) => a.id == event.id)) {
        event.cookies = '';
        return;
      }
      final cookies = event.cookies;
      event.cookies = '';
      await _run(
        event.connection,
        emit,
        action: () => manage.updateCookies(event.connection, event.id, cookies),
        sanitize: true,
      );
    });
    on<AccountsCleared>((event, emit) {
      ++_generation;
      _connection = null;
      emit(AccountState());
    });
  }
  final ManageAccounts manage;
  int _generation = 0;
  bool _mutationPending = false;
  ServerConnection? _connection;
  Future<void> _batchKeepalive(
    AccountsBatchKeepaliveRequested event,
    Emitter<AccountState> emit,
  ) async {
    if (state.busy ||
        _mutationPending ||
        !identical(_connection, event.connection) ||
        manage.repository is! BatchKeepaliveRepository) {
      return;
    }
    final generation = ++_generation;
    emit(AccountState(items: state.items, busy: true));
    BatchKeepaliveResult result;
    _mutationPending = true;
    try {
      result = await (manage.repository as BatchKeepaliveRepository)
          .keepaliveAll(event.connection);
    } catch (_) {
      if (!emit.isDone && generation == _generation) {
        emit(
          AccountState(
            items: state.items,
            error: 'Chưa xác nhận được kết quả đợt duy trì phiên. Server có thể vẫn đang chạy. Không tự thử lại; tải trạng thái để kiểm tra.',
          ),
        );
      }
      return;
    } finally {
      _mutationPending = false;
    }
    if (emit.isDone || generation != _generation) return;
    if (result.busy) {
      emit(AccountState(items: state.items, error: result.message));
      return;
    }
    var items = state.items;
    String? error;
    try {
      items = await manage.list(event.connection);
    } catch (_) {
      error = 'Không tải lại được danh sách. Kết quả đợt duy trì phiên ở trên không thay đổi; hãy tải lại danh sách.';
    }
    if (!emit.isDone && generation == _generation) {
      emit(
        AccountState(
          items: items,
          message: result.message,
          error: error,
          batchCompleted: true,
        ),
      );
    }
  }

  Future<void> _keepalive(
    AccountActed event,
    Emitter<AccountState> emit,
  ) async {
    if (state.busy ||
        _mutationPending ||
        !identical(_connection, event.connection) ||
        !state.items.any((a) => a.id == event.id)) {
      return;
    }
    final generation = ++_generation;
    emit(AccountState(items: state.items, busy: true));
    String? message;
    String? error;
    _mutationPending = true;
    try {
      message = await manage.act(event.connection, event.id, event.action);
    } catch (e) {
      error = e is AppFailure
          ? e.message
          : 'Chưa xác nhận được duy trì phiên. Tải lại trước khi thử lại.';
    } finally {
      _mutationPending = false;
    }
    if (emit.isDone || generation != _generation) return;
    var items = state.items;
    try {
      items = await manage.list(event.connection);
    } catch (_) {
      error = [
        ?error,
        'Không tải lại được danh sách. Kết quả duy trì phiên ở trên không thay đổi; hãy tải lại danh sách.',
      ].join('\n');
    }
    if (!emit.isDone && generation == _generation) {
      emit(AccountState(items: items, message: message, error: error));
    }
  }

  Future<void> _run(
    ServerConnection connection,
    Emitter<AccountState> emit, {
    Future<String> Function()? action,
    bool imported = false,
    bool sanitize = false,
    String? failureMessage,
  }) async {
    if (state.busy || (action != null && _mutationPending)) return;
    final generation = ++_generation;
    final changed =
        _connection?.baseUrl != connection.baseUrl ||
        _connection?.apiKey != connection.apiKey;
    _connection = connection;
    emit(AccountState(items: changed ? [] : state.items, busy: true));
    String? message;
    if (action != null) _mutationPending = true;
    try {
      if (action != null) message = await action();
      if (emit.isDone || generation != _generation) return;
      final items = await manage.list(connection);
      if (!emit.isDone && generation == _generation) {
        emit(
          AccountState(
            items: items,
            message: message,
            imported: imported && message != null,
          ),
        );
      }
    } catch (error) {
      if (!emit.isDone && generation == _generation) {
        emit(
          AccountState(
            items: state.items,
            message: message,
            imported: imported && message != null,
            error: imported && message != null
                ? 'Đã nhập tài khoản nhưng chưa tải lại được danh sách. Hãy tải lại danh sách, không gửi lại yêu cầu nhập.'
                : failureMessage ??
                      (sanitize
                          ? 'Chưa xác nhận được cập nhật cookie. Tải lại tài khoản trước khi thử lại.'
                          : error is AppFailure
                          ? error.message
                          : 'Không cập nhật được tài khoản.'),
          ),
        );
      }
    } finally {
      if (action != null) _mutationPending = false;
    }
  }
}
