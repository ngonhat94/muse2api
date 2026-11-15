import 'package:bloc/bloc.dart';

import '../../../../core/presentation/collection_bloc.dart';
import '../../../connection/domain/entities/server_connection.dart';
import '../../domain/entities/media_item.dart';
import '../../domain/usecases/delete_media.dart';
import '../../domain/usecases/load_media.dart';

class MediaDeleteRequested {
  MediaDeleteRequested(this.connection, List<String> names)
    : names = List.unmodifiable(names);
  final ServerConnection connection;
  final List<String> names;
}

class MediaState extends CollectionState<MediaItem> {
  MediaState({
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

class MediaBloc extends Bloc<Object, MediaState> {
  MediaBloc(this.load) : super(MediaState()) {
    on<CollectionLoaded>((event, emit) async {
      final changed = !matches(event.connection);
      if (!changed && (state.loading || state.deleting)) return;
      final generation = ++_generation;
      _connection = event.connection;
      emit(
        MediaState(
          items: changed ? [] : state.items,
          loading: true,
          stale: !changed && state.stale,
        ),
      );
      try {
        final items = await load(event.connection);
        if (emit.isDone || generation != _generation) return;
        emit(MediaState(items: items));
      } catch (_) {
        if (emit.isDone || generation != _generation) return;
        emit(
          MediaState(
            items: state.items,
            stale: state.stale,
            error: 'Không tải được thư viện. Vui lòng thử lại.',
          ),
        );
      }
    });
    on<MediaDeleteRequested>((event, emit) async {
      if (!matches(event.connection) ||
          state.loading ||
          state.deleting ||
          state.stale) {
        return;
      }
      final generation = _generation;
      final library = state.items;
      emit(MediaState(items: library, deleting: true));
      try {
        final result = await DeleteMedia(load.repository)(
          event.connection,
          event.names,
          library,
        );
        if (emit.isDone || generation != _generation) return;
        final notice = 'Đã xóa ${result.removed} tệp.';
        final error = result.errorCount == 0
            ? null
            : '${result.errorCount} tệp không xóa được. Kiểm tra thư viện rồi thử lại.';
        try {
          final items = await load(event.connection);
          if (emit.isDone || generation != _generation) return;
          emit(MediaState(items: items, notice: notice, error: error));
        } catch (_) {
          if (emit.isDone || generation != _generation) return;
          emit(
            MediaState(
              items: library,
              stale: true,
              notice: notice,
              error:
                  '${error == null ? '' : '$error '}Không tải lại được thư viện; danh sách có thể đã cũ. Hãy làm mới trước khi xóa tiếp.',
            ),
          );
        }
      } catch (_) {
        if (emit.isDone || generation != _generation) return;
        emit(
          MediaState(
            items: library,
            error: 'Không xóa được media. Làm mới thư viện rồi thử lại.',
          ),
        );
      }
    });
    on<CollectionCleared>((event, emit) {
      ++_generation;
      _connection = null;
      emit(MediaState());
    });
    on<CollectionPaused>((event, emit) {});
  }
  final LoadMedia load;
  ServerConnection? _connection;
  int _generation = 0;
  bool matches(ServerConnection connection) =>
      _connection?.baseUrl == connection.baseUrl &&
      _connection?.apiKey == connection.apiKey;
  @override
  Future<void> close() {
    ++_generation;
    return super.close();
  }
}
