import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../desktop/domain/repositories/desktop_engine.dart';
import '../../../desktop/domain/repositories/desktop_engine_failure.dart';
import '../../../desktop/domain/repositories/desktop_engine_installer.dart';
import '../../domain/entities/server_connection.dart';
import '../../domain/usecases/connect_server.dart';
import '../../domain/usecases/restore_connection.dart';

sealed class ConnectionEvent {}

class ConnectionRequested extends ConnectionEvent {
  ConnectionRequested(this.address, this.apiKey);
  final String address;
  final String apiKey;
  @override
  String toString() => 'ConnectionRequested(key: [redacted])';
}

class LocalConnectionRequested extends ConnectionEvent {}

class DesktopInstallationRequested extends ConnectionEvent {}

class DesktopInstallationCancelled extends ConnectionEvent {}

class _DesktopInstallationProgress extends ConnectionEvent {
  _DesktopInstallationProgress(this.attempt, this.stage);
  final int attempt;
  final DesktopInstallStage stage;
}

class ConnectionRestored extends ConnectionEvent {}

class ConnectionDisconnected extends ConnectionEvent {}

class ConnectionForgotten extends ConnectionEvent {}

class _LocalEngineExited extends ConnectionEvent {
  _LocalEngineExited(this.attempt);
  final int attempt;
}

enum ConnectionStatus { disconnected, connecting, connected }

class ServerConnectionState {
  const ServerConnectionState({
    this.status = ConnectionStatus.disconnected,
    this.connection,
    this.savedConnection,
    this.error,
    this.localMode = false,
    this.installation,
  });
  final ConnectionStatus status;
  final ServerConnection? connection;
  final ServerConnection? savedConnection;
  final String? error;
  final bool localMode;
  final DesktopInstallStage? installation;
}

class ConnectionBloc extends Bloc<ConnectionEvent, ServerConnectionState> {
  ConnectionBloc(
    this.connect, {
    this.restore,
    this.forget,
    this.desktop,
    this.readLocalPreference,
    this.saveLocalPreference,
  }) : super(const ServerConnectionState()) {
    _exitSubscription = desktop?.unexpectedExit.listen((_) {
      final connection = state.connection;
      if (!isClosed &&
          state.localMode &&
          ((state.status == ConnectionStatus.connecting &&
                  state.installation == null) ||
              connection?.isLocal == true)) {
        add(_LocalEngineExited(_attempt));
      }
    });
    on<_LocalEngineExited>((event, emit) {
      if (event.attempt != _attempt || !state.localMode) return;
      ++_attempt;
      emit(
        ServerConnectionState(
          savedConnection: state.savedConnection,
          localMode: true,
          error: 'Engine trên máy này đã dừng. Chọn Khởi động lại để tiếp tục; dữ liệu đã lưu vẫn được giữ.',
        ),
      );
    });
    on<ConnectionRestored>((event, emit) async {
      if (state.status != ConnectionStatus.disconnected) return;
      final attempt = ++_attempt;
      try {
        final local = await readLocalPreference?.call();
        ServerConnection? saved;
        try {
          saved = await restore?.call();
        } catch (_) {
          // Local startup does not require reading a remote server's Keychain
          // record. Keep that record intact for later remote use.
          if (desktop?.supported != true || local != true) rethrow;
        }
        if (emit.isDone || attempt != _attempt) return;
        emit(ServerConnectionState(savedConnection: saved));
        if (desktop?.supported == true &&
            (local == true || (local == null && saved == null))) {
          add(LocalConnectionRequested());
        } else if (saved != null) {
          add(ConnectionRequested(saved.baseUrl, saved.apiKey));
        }
      } catch (error) {
        if (!emit.isDone && attempt == _attempt) {
          emit(
            ServerConnectionState(
              error: error is AppFailure
                  ? error.message
                  : 'Không đọc được thông tin đã lưu. Vui lòng kết nối lại.',
            ),
          );
        }
      }
    });
    on<LocalConnectionRequested>((event, emit) async {
      if (state.status == ConnectionStatus.connecting ||
          state.connection?.isLocal == true) {
        return;
      }
      if (desktop?.supported != true) {
        emit(
          ServerConnectionState(
            savedConnection: state.savedConnection,
            error: 'Chế độ trên máy này chỉ có trong bản desktop.',
          ),
        );
        return;
      }
      final attempt = ++_attempt;
      final saved = state.savedConnection;
      emit(
        ServerConnectionState(
          status: ConnectionStatus.connecting,
          savedConnection: saved,
          localMode: true,
        ),
      );
      try {
        final connection = await desktop!.start();
        if (emit.isDone || attempt != _attempt) return;
        await saveLocalPreference?.call(true);
        if (!emit.isDone && attempt == _attempt) {
          emit(
            ServerConnectionState(
              status: ConnectionStatus.connected,
              connection: connection,
              savedConnection: saved,
              localMode: true,
            ),
          );
        }
      } catch (error) {
        if (!emit.isDone && attempt == _attempt) {
          await desktop!.stop();
          if (!emit.isDone && attempt == _attempt) {
            emit(
              ServerConnectionState(
                savedConnection: saved,
                localMode: true,
                error: error is DesktopEngineFailure
                    ? error.message
                    : const DesktopEngineFailure(
                        DesktopEngineFailureCode.startupFailed,
                      ).message,
              ),
            );
          }
        }
      }
    });
    on<_DesktopInstallationProgress>((event, emit) {
      if (event.attempt != _attempt || state.installation == null) return;
      emit(
        ServerConnectionState(
          status: ConnectionStatus.connecting,
          savedConnection: state.savedConnection,
          localMode: true,
          installation: event.stage,
        ),
      );
    });
    on<DesktopInstallationRequested>((event, emit) async {
      final installer = _installer;
      if (installer == null ||
          state.status == ConnectionStatus.connecting ||
          state.connection != null) {
        return;
      }
      final attempt = ++_attempt;
      final saved = state.savedConnection;
      emit(
        ServerConnectionState(
          status: ConnectionStatus.connecting,
          savedConnection: saved,
          localMode: true,
          installation: DesktopInstallStage.preparing,
        ),
      );
      try {
        await installer.install((stage) {
          if (!isClosed && attempt == _attempt) {
            add(_DesktopInstallationProgress(attempt, stage));
          }
        });
        if (emit.isDone || attempt != _attempt) return;
        emit(ServerConnectionState(savedConnection: saved, localMode: true));
        add(LocalConnectionRequested());
      } catch (error) {
        if (!emit.isDone && attempt == _attempt) {
          emit(
            ServerConnectionState(
              savedConnection: saved,
              localMode: true,
              error: error is DesktopEngineFailure
                  ? error.message
                  : const DesktopEngineFailure(
                      DesktopEngineFailureCode.installFailed,
                    ).message,
            ),
          );
        }
      }
    });
    on<DesktopInstallationCancelled>(
      (event, emit) => _cancelInstallation(emit),
    );
    on<ConnectionRequested>((event, emit) async {
      if (state.status == ConnectionStatus.connecting) return;
      final attempt = ++_attempt;
      final saved = state.savedConnection;
      emit(
        ServerConnectionState(
          status: ConnectionStatus.connecting,
          savedConnection: saved,
        ),
      );
      try {
        await desktop?.stop();
        if (emit.isDone || attempt != _attempt) return;
        final connection = await connect(event.address, event.apiKey);
        if (emit.isDone || attempt != _attempt) return;
        await saveLocalPreference?.call(false);
        if (!emit.isDone && attempt == _attempt) {
          emit(
            ServerConnectionState(
              status: ConnectionStatus.connected,
              connection: connection,
              savedConnection: connection,
            ),
          );
        }
      } catch (error) {
        if (!emit.isDone && attempt == _attempt) {
          emit(
            ServerConnectionState(
              savedConnection: saved,
              error: error is AppFailure
                  ? error.message
                  : 'Không thể kết nối server.',
            ),
          );
        }
      }
    });
    on<ConnectionDisconnected>((event, emit) async {
      if (state.installation != null) {
        await _cancelInstallation(emit);
        return;
      }
      ++_attempt;
      final local = state.localMode;
      emit(
        ServerConnectionState(
          savedConnection: state.savedConnection,
          localMode: local,
        ),
      );
      await desktop?.stop();
    });
    on<ConnectionForgotten>((event, emit) async {
      if (state.status == ConnectionStatus.connecting || forget == null) return;
      final attempt = ++_attempt;
      try {
        await forget!();
        if (!emit.isDone && attempt == _attempt) {
          emit(
            ServerConnectionState(
              status: state.connection?.isLocal == true
                  ? state.status
                  : ConnectionStatus.disconnected,
              connection: state.connection?.isLocal == true
                  ? state.connection
                  : null,
              localMode: state.localMode,
            ),
          );
        }
      } catch (_) {
        if (!emit.isDone && attempt == _attempt) {
          emit(
            ServerConnectionState(
              status: state.status,
              connection: state.connection,
              savedConnection: state.savedConnection,
              localMode: state.localMode,
              error: 'Không xóa được API key đã lưu. Vui lòng thử lại.',
            ),
          );
        }
      }
    });
  }
  final ConnectServer connect;
  final RestoreConnection? restore;
  final ForgetConnection? forget;
  final DesktopEngine? desktop;
  final Future<bool?> Function()? readLocalPreference;
  final Future<void> Function(bool)? saveLocalPreference;
  StreamSubscription<void>? _exitSubscription;
  bool get supportsLocal => desktop?.supported == true;
  DesktopEngineInstaller? get _installer => desktop is DesktopEngineInstaller
      ? desktop as DesktopEngineInstaller
      : null;
  bool get supportsInstallation => supportsLocal && _installer != null;
  int _attempt = 0;
  Future<void> _cancelInstallation(Emitter<ServerConnectionState> emit) async {
    if (state.installation == null ||
        state.installation == DesktopInstallStage.cancelling) {
      return;
    }
    final attempt = ++_attempt;
    final saved = state.savedConnection;
    emit(
      ServerConnectionState(
        status: ConnectionStatus.connecting,
        savedConnection: saved,
        localMode: true,
        installation: DesktopInstallStage.cancelling,
      ),
    );
    try {
      await _installer?.cancelInstall();
    } catch (_) {
      /* Do not expose process output. */
    }
    if (!emit.isDone && attempt == _attempt) {
      emit(ServerConnectionState(savedConnection: saved, localMode: true));
    }
  }

  @override
  Future<void> close() async {
    ++_attempt;
    await _exitSubscription?.cancel();
    await _installer?.cancelInstall();
    await desktop?.stop();
    return super.close();
  }
}
