import '../../../../core/domain/reference_image.dart';
import '../../../../core/storage/pending_generation_store.dart';

import 'dart:async';
import 'dart:math';

import 'package:bloc/bloc.dart';

import '../../../../core/domain/generation_task.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../connection/domain/entities/server_connection.dart';
import '../../domain/usecases/generate_video.dart';

sealed class VideoEvent {}

class VideoRequested extends VideoEvent {
  VideoRequested(
    this.connection,
    this.prompt,
    this.ratio,
    this.duration, {
    List<ReferenceImage> references = const [],
  }) : references = List.unmodifiable(references);
  final List<ReferenceImage> references;
  final ServerConnection connection;
  final String prompt;
  final String ratio;
  final int duration;
}

class VideoResumed extends VideoEvent {
  VideoResumed(this.connection, this.id);
  final ServerConnection connection;
  final String id;
}

class VideoPollingRetried extends VideoEvent {}

class VideoAdmissionRetried extends VideoEvent {}

class VideosCleared extends VideoEvent {}

class _VideoPolled extends VideoEvent {
  _VideoPolled(this.generation);
  final int generation;
}

class VideoState {
  const VideoState({
    this.task,
    this.busy = false,
    this.error,
    this.admissionUncertain = false,
  });
  final GenerationTask? task;
  final bool busy;
  final String? error;
  final bool admissionUncertain;
}

class VideoBloc extends Bloc<VideoEvent, VideoState> {
  VideoBloc(
    this.generate,
    this.getTask, {
    this.pollInterval = const Duration(seconds: 3),
    this.pendingStore,
  }) : super(const VideoState()) {
    Future<void> submit(
      VideoRequested event,
      Emitter<VideoState> emit, {
      bool retry = false,
    }) async {
      if (state.busy ||
          (state.admissionUncertain && !retry) ||
          event.prompt.trim().isEmpty ||
          (state.task != null && !state.task!.terminal)) {
        return;
      }
      try {
        ReferenceImage.validate(event.references);
      } catch (error) {
        emit(VideoState(error: _message(error)));
        return;
      }
      final generation = ++_generation;
      _timer?.cancel();
      _connection = event.connection;
      if (!retry) {
        _pendingRequest = event;
        _pendingKey = List.generate(
          24,
          (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join();
      }
      emit(const VideoState(busy: true));
      try {
        final task = await generate(
          event.connection,
          event.prompt.trim(),
          event.ratio,
          event.duration,
          requestKey: _pendingKey,
          references: event.references,
        );
        if (!task.terminal) {
          try {
            await pendingStore?.save(event.connection, 'video', task.id);
          } catch (error) {
            if (!emit.isDone && generation == _generation) {
              emit(VideoState(task: task, error: _message(error)));
            }
            return;
          }
        }
        if (!emit.isDone && generation == _generation) {
          _accept(task, emit, generation);
        }
      } catch (error) {
        if (!emit.isDone && generation == _generation) {
          emit(
            VideoState(
              error: '${_message(error)} Kiểm tra Tác vụ trước khi tạo lại.',
              admissionUncertain: true,
            ),
          );
        }
      }
    }

    on<VideoRequested>((event, emit) => submit(event, emit));
    on<VideoAdmissionRetried>((event, emit) async {
      if (!state.admissionUncertain ||
          state.busy ||
          _pendingRequest == null ||
          _pendingKey == null) {
        return;
      }
      await submit(_pendingRequest!, emit, retry: true);
    });
    on<VideoResumed>((event, emit) async {
      final generation = _generation + 1;
      ++_generation;
      _timer?.cancel();
      _connection = event.connection;
      emit(
        VideoState(
          task: GenerationTask(
            id: event.id,
            kind: 'video',
            status: GenerationStatus.queued,
          ),
          busy: true,
        ),
      );
      try {
        await pendingStore?.save(event.connection, 'video', event.id);
      } catch (error) {
        if (!emit.isDone && generation == _generation) {
          emit(VideoState(task: state.task, error: _message(error)));
        }
        return;
      }
      if (!emit.isDone && generation == _generation) {
        add(_VideoPolled(generation));
      }
    });
    on<_VideoPolled>((event, emit) async {
      if (event.generation != _generation ||
          state.task == null ||
          _connection == null) {
        return;
      }
      final task = state.task!;
      try {
        final connection = _connection!;
        final next = await getTask(connection, task.id);
        if (next.terminal) {
          await pendingStore?.remove(connection, 'video', task.id);
        }
        if (!emit.isDone && event.generation == _generation) {
          _accept(next, emit, event.generation);
        }
      } catch (error) {
        if (!emit.isDone && event.generation == _generation) {
          emit(VideoState(task: task, error: _message(error)));
        }
      }
    });
    on<VideoPollingRetried>((event, emit) {
      if (state.busy || state.task == null || state.task!.terminal) return;
      emit(VideoState(task: state.task, busy: true));
      add(_VideoPolled(_generation));
    });
    on<VideosCleared>((event, emit) {
      ++_generation;
      _timer?.cancel();
      _connection = null;
      _pendingKey = null;
      _pendingRequest = null;
      emit(const VideoState());
    });
  }
  final GenerateVideo generate;
  final GetVideoTask getTask;
  final Duration pollInterval;
  final PendingGenerationStore? pendingStore;
  ServerConnection? _connection;
  String? _pendingKey;
  VideoRequested? _pendingRequest;
  int _generation = 0;
  Timer? _timer;
  String _message(Object error) =>
      error is AppFailure ? error.message : 'Không lấy được tác vụ video.';
  void _accept(GenerationTask task, Emitter<VideoState> emit, int generation) {
    emit(
      VideoState(
        task: task,
        busy: !task.terminal,
        error: task.status == GenerationStatus.failed
            ? 'Tạo video thất bại. Kiểm tra tài khoản và quota trên server.'
            : null,
      ),
    );
    if (!task.terminal) {
      _timer = Timer(pollInterval, () {
        if (!isClosed) add(_VideoPolled(generation));
      });
    }
  }

  @override
  Future<void> close() {
    ++_generation;
    _timer?.cancel();
    return super.close();
  }
}
