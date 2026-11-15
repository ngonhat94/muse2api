import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../features/connection/domain/entities/server_connection.dart';
import '../errors/app_failure.dart';

sealed class CollectionEvent {}

class CollectionLoaded extends CollectionEvent {
  CollectionLoaded(this.connection, {this.poll = false});
  final ServerConnection connection;
  final bool poll;
}

class CollectionPaused extends CollectionEvent {}

class CollectionCleared extends CollectionEvent {}

class CollectionState<T> {
  CollectionState({List<T> items = const [], this.loading = false, this.error})
    : items = List.unmodifiable(items);
  final List<T> items;
  final bool loading;
  final String? error;
}

class CollectionBloc<T> extends Bloc<CollectionEvent, CollectionState<T>> {
  CollectionBloc(this.load) : super(CollectionState<T>()) {
    on<CollectionLoaded>((event, emit) async {
      if (state.loading) return;
      final generation = ++_generation;
      _timer?.cancel();
      final connectionChanged =
          _connection?.baseUrl != event.connection.baseUrl ||
          _connection?.apiKey != event.connection.apiKey;
      _connection = event.connection;
      _poll = event.poll;
      emit(
        CollectionState(
          items: connectionChanged ? [] : state.items,
          loading: true,
        ),
      );
      try {
        final items = await load(event.connection);
        if (emit.isDone || generation != _generation) return;
        emit(CollectionState(items: items));
      } catch (error) {
        if (emit.isDone || generation != _generation) return;
        emit(
          CollectionState(
            items: state.items,
            error: error is AppFailure
                ? error.message
                : 'Không tải được dữ liệu.',
          ),
        );
      }
      if (_poll && generation == _generation && !isClosed) {
        _timer = Timer(const Duration(seconds: 5), () {
          if (!isClosed && _poll) {
            add(CollectionLoaded(event.connection, poll: true));
          }
        });
      }
    });
    on<CollectionPaused>((event, emit) {
      _poll = false;
      _timer?.cancel();
    });
    on<CollectionCleared>((event, emit) {
      ++_generation;
      _timer?.cancel();
      _poll = false;
      _connection = null;
      emit(CollectionState<T>());
    });
  }
  final Future<List<T>> Function(ServerConnection) load;
  Timer? _timer;
  bool _poll = false;
  int _generation = 0;
  ServerConnection? _connection;
  @override
  Future<void> close() {
    ++_generation;
    _timer?.cancel();
    return super.close();
  }
}
