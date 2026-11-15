import 'package:bloc/bloc.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../connection/domain/entities/server_connection.dart';
import '../../domain/entities/account_proxy.dart';
import '../../domain/usecases/manage_proxy.dart';

sealed class ProxyEvent {}

class ProxyEdited extends ProxyEvent {}

class ProxyTestRequested extends ProxyEvent {
  ProxyTestRequested(this.configuration);
  final ProxyConfiguration configuration;
}

class ProxySaved extends ProxyEvent {
  ProxySaved(this.configuration);
  final ProxyConfiguration? configuration;
}

class ProxyState {
  const ProxyState({
    this.busy = false,
    this.saved = false,
    this.check,
    this.error,
  });
  final bool busy;
  final bool saved;
  final ProxyCheck? check;
  final String? error;
}

class ProxyBloc extends Bloc<ProxyEvent, ProxyState> {
  ProxyBloc(this.manage, this.connection, this.accountId)
    : super(const ProxyState()) {
    on<ProxyEdited>((event, emit) {
      if (!state.busy) emit(const ProxyState());
    });
    on<ProxyTestRequested>((event, emit) async {
      if (state.busy) return;
      emit(const ProxyState(busy: true));
      try {
        final check = await manage.test(
          connection,
          accountId,
          event.configuration,
        );
        if (!emit.isDone) emit(ProxyState(check: check));
      } catch (error) {
        if (!emit.isDone) emit(ProxyState(error: _message(error)));
      }
    });
    on<ProxySaved>((event, emit) async {
      if (state.busy) return;
      emit(const ProxyState(busy: true));
      try {
        await manage.save(connection, accountId, event.configuration);
        if (!emit.isDone) emit(const ProxyState(saved: true));
      } catch (error) {
        if (!emit.isDone) emit(ProxyState(error: _message(error)));
      }
    });
  }
  final ManageProxy manage;
  final ServerConnection connection;
  final String accountId;
  String _message(Object error) => error is AppFailure
      ? error.message
      : 'Không cập nhật được proxy. Vui lòng thử lại.';
}
