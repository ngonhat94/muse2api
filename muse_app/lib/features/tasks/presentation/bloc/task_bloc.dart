import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../../../core/domain/generation_task.dart';
import '../../../../core/presentation/collection_bloc.dart';
import '../../../connection/domain/entities/server_connection.dart';
import '../../domain/usecases/load_tasks.dart';

class TaskDeleteRequested {
  TaskDeleteRequested(this.connection, this.id);
  final ServerConnection connection;
  final String id;
}

class TaskClearRequested {
  TaskClearRequested(this.connection);
  final ServerConnection connection;
}

class TaskCancelRequested {
  TaskCancelRequested(this.connection, this.id);
  final ServerConnection connection;
  final String id;
}

class TaskState extends CollectionState<GenerationTask> {
  TaskState({
    super.items,
    super.loading,
    super.error,
    this.deleting = false,
    this.stale = false,
    this.notice,
  });
  final bool deleting;
  final bool stale;
  final String? notice;
}

class TaskBloc extends Bloc<Object, TaskState> {
  TaskBloc(this.load) : super(TaskState()) {
    on<CollectionLoaded>((event, emit) async {
      final changed = !matches(event.connection);
      if (!changed && (state.loading || state.deleting)) return;
      final generation = ++_generation;
      _timer?.cancel();
      _poll = event.poll;
      _connection = event.connection;
      emit(
        TaskState(
          items: changed ? [] : state.items,
          loading: true,
          stale: !changed && state.stale,
        ),
      );
      try {
        final items = await load(event.connection);
        if (emit.isDone || generation != _generation) return;
        emit(TaskState(items: items));
      } catch (_) {
        if (emit.isDone || generation != _generation) return;
        emit(
          TaskState(
            items: state.items,
            stale: state.stale,
            error: 'Không tải được tác vụ. Vui lòng làm mới để thử lại.',
          ),
        );
      }
      _schedule();
    });
    on<CollectionPaused>((event, emit) {
      _poll = false;
      _timer?.cancel();
    });
    on<CollectionCleared>((event, emit) {
      _poll = false;
      _timer?.cancel();
      ++_generation;
      _connection = null;
      emit(TaskState());
    });
    on<TaskDeleteRequested>((event, emit) async {
      if (!state.items.any((task) => task.id == event.id)) return;
      await _mutate(event.connection, emit, () async {
        await load.repository.delete(event.connection, event.id);
        return 1;
      });
    });
    on<TaskClearRequested>(
      (event, emit) => _mutate(
        event.connection,
        emit,
        () => load.repository.clear(event.connection),
      ),
    );
    on<TaskCancelRequested>((event, emit) async {
      if (!state.items.any((task) => task.id == event.id && !task.terminal)) {
        return;
      }
      await _mutate(
        event.connection,
        emit,
        () async {
          await load.repository.cancel(event.connection, event.id);
          return 0;
        },
        successNotice: 'Đã hủy tác vụ.',
        failureMessage: 'Không hủy được tác vụ. Làm mới danh sách rồi thử lại.',
      );
    });
  }
  Future<void> _mutate(
    ServerConnection connection,
    Emitter<TaskState> emit,
    Future<int> Function() action, {
    String? successNotice,
    String failureMessage =
        'Không xóa được tác vụ. Làm mới danh sách rồi thử lại.',
  }) async {
    if (state.deleting ||
        state.loading ||
        state.stale ||
        !matches(connection)) {
      return;
    }
    final generation = _generation;
    final previous = state.items;
    _timer?.cancel();
    emit(TaskState(items: previous, deleting: true));
    try {
      final removed = await action();
      if (emit.isDone || generation != _generation) return;
      final notice = successNotice ?? 'Đã xóa $removed tác vụ.';
      try {
        final items = await load(connection);
        if (emit.isDone || generation != _generation) return;
        emit(TaskState(items: items, notice: notice));
      } catch (_) {
        if (emit.isDone || generation != _generation) return;
        emit(
          TaskState(
            items: previous,
            stale: true,
            notice: notice,
            error: 'Không tải lại được tác vụ; danh sách có thể đã cũ. Hãy làm mới trước khi xóa tiếp.',
          ),
        );
      }
    } catch (_) {
      if (emit.isDone || generation != _generation) return;
      emit(TaskState(items: previous, error: failureMessage));
    } finally {
      if (generation == _generation) _schedule();
    }
  }

  void _schedule() {
    _timer?.cancel();
    final connection = _connection;
    if (!_poll || isClosed || connection == null) return;
    _timer = Timer(const Duration(seconds: 5), () {
      if (!isClosed && _poll) add(CollectionLoaded(connection, poll: true));
    });
  }

  @override
  Future<void> close() {
    ++_generation;
    _timer?.cancel();
    return super.close();
  }

  Timer? _timer;
  bool _poll = false;
  final LoadTasks load;
  int _generation = 0;
  ServerConnection? _connection;
  bool matches(ServerConnection connection) =>
      _connection?.baseUrl == connection.baseUrl &&
      _connection?.apiKey == connection.apiKey;
}
