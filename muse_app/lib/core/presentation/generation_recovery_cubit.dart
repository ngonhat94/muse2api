import 'package:bloc/bloc.dart';

import '../storage/pending_generation_store.dart';
import '../domain/generation_task.dart';
import '../errors/app_failure.dart';
import '../../features/connection/domain/entities/server_connection.dart';
import '../../features/images/domain/entities/image_task.dart';
import '../../features/images/domain/usecases/generate_image.dart';
import '../../features/videos/domain/usecases/generate_video.dart';

class RecoveryEntry {
  const RecoveryEntry(
    this.kind,
    this.id,
    this.status, {
    this.image,
    this.video,
  });
  final String kind, id, status;
  final ImageTask? image;
  final GenerationTask? video;
}

/// Recovery never has access to a generation use case: every retry is GET only.
class GenerationRecoveryCubit extends Cubit<List<RecoveryEntry>> {
  GenerationRecoveryCubit(this.store, this.images, this.videos) : super([]);
  final PendingGenerationStore store;
  final GetImageTask images;
  final GetVideoTask? videos;
  ServerConnection? connection;
  int _revision = 0;
  Future<void> connect(ServerConnection? server) async {
    final revision = ++_revision;
    connection = server;
    emit([]);
    if (server == null) return;
    try {
      final tasks = await store.list(server);
      if (isClosed || revision != _revision) return;
      emit(tasks.map((e) => RecoveryEntry(e.kind, e.id, 'pending')).toList());
      await Future.wait(tasks.map((e) => retry(e.kind, e.id)));
    } catch (_) {
      if (!isClosed && revision == _revision) {
        emit([const RecoveryEntry('', '', 'storage_error')]);
      }
    }
  }

  Future<void> refresh() => connect(connection);

  Future<void> retry(String kind, String id) async {
    final server = connection;
    final revision = _revision;
    if (server == null || !state.any((e) => e.kind == kind && e.id == id)) {
      return;
    }
    void update(RecoveryEntry entry) {
      if (!isClosed && revision == _revision) {
        emit(
          state.map((e) => e.kind == kind && e.id == id ? entry : e).toList(),
        );
      }
    }

    update(RecoveryEntry(kind, id, 'checking'));
    try {
      final image = kind == 'image' ? await images(server, id) : null;
      final video = kind == 'video' ? await videos!(server, id) : null;
      if ((image?.id ?? video?.id) != id) {
        throw const AppFailure('Mã tác vụ phản hồi không khớp.');
      }
      final terminal = image?.terminal ?? video!.terminal;
      final failed =
          image?.status == ImageTaskStatus.failed ||
          video?.status == GenerationStatus.failed;
      if (terminal) await store.remove(server, kind, id);
      update(
        RecoveryEntry(
          kind,
          id,
          terminal ? (failed ? 'failed' : 'completed') : 'pending',
          image: image,
          video: video,
        ),
      );
    } catch (error) {
      // 404 identifies an unknown/deleted record, not a failed generation.
      final missing = error is AppFailure && error.message.contains('HTTP 404');
      update(RecoveryEntry(kind, id, missing ? 'unknown' : 'unreachable'));
    }
  }

  @override
  Future<void> close() {
    ++_revision;
    return super.close();
  }
}
