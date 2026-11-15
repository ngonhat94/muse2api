import '../../../../core/domain/reference_image.dart';
import '../../../../core/storage/pending_generation_store.dart';

import 'dart:async';
import 'dart:math';

import 'package:bloc/bloc.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../connection/domain/entities/server_connection.dart';
import '../../domain/entities/image_task.dart';
import '../../domain/usecases/generate_image.dart';

sealed class ImageEvent {}

class ImageRequested extends ImageEvent {
  ImageRequested(
    this.connection,
    this.prompt,
    this.ratio, {
    List<ReferenceImage> references = const [],
  }) : references = List.unmodifiable(references);
  final List<ReferenceImage> references;
  final ServerConnection connection;
  final String prompt;
  final String ratio;
}

class ImagePollingRetried extends ImageEvent {}

class ImageAdmissionRetried extends ImageEvent {}

class ImagesCleared extends ImageEvent {
  ImagesCleared({
    this.discardUncertain = false,
    this.connectionChanged = false,
  });
  final bool discardUncertain;
  final bool connectionChanged;
}

class _ImagePolled extends ImageEvent {
  _ImagePolled(this.generation);
  final int generation;
}

class ImageState {
  const ImageState({
    this.task,
    this.busy = false,
    this.error,
    this.admissionUncertain = false,
  });
  final ImageTask? task;
  final bool busy;
  final String? error;
  final bool admissionUncertain;
}

class ImageBloc extends Bloc<ImageEvent, ImageState> {
  ImageBloc(
    this.generate,
    this.getTask, {
    this.pollInterval = const Duration(seconds: 3),
    this.pendingStore,
  }) : super(const ImageState()) {
    Future<void> submit(
      ImageRequested event,
      Emitter<ImageState> emit, {
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
        emit(ImageState(error: _message(error)));
        return;
      }
      final generation = ++_generation;
      _timer?.cancel();
      final prompt = event.prompt.trim();
      if (!retry) {
        _pendingRequest = event;
        _pendingKey = List.generate(
          24,
          (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join();
      }
      _connection = event.connection;
      emit(const ImageState(busy: true));
      try {
        final task = await generate(
          event.connection,
          prompt,
          event.ratio,
          _pendingKey!,
          references: event.references,
        );
        if (!task.terminal) {
          try {
            await pendingStore?.save(event.connection, 'image', task.id);
          } catch (error) {
            if (!emit.isDone && generation == _generation) {
              emit(ImageState(task: task, error: _message(error)));
            }
            return;
          }
        }
        if (emit.isDone || generation != _generation) return;
        _accept(task, emit, generation);
      } catch (error) {
        if (!emit.isDone && generation == _generation) {
          emit(
            ImageState(
              error:
                  '${_message(error)} Server có thể đã nhận yêu cầu. Kiểm tra Tác vụ trước khi bỏ yêu cầu; tạo mới có thể bị trùng.',
              admissionUncertain: true,
            ),
          );
        }
      }
    }

    on<ImageRequested>((event, emit) => submit(event, emit));
    on<ImageAdmissionRetried>((event, emit) async {
      if (!state.admissionUncertain ||
          state.busy ||
          _pendingRequest == null ||
          _pendingKey == null) {
        return;
      }
      await submit(_pendingRequest!, emit, retry: true);
    });
    on<_ImagePolled>((event, emit) async {
      final task = state.task;
      if (event.generation != _generation ||
          task == null ||
          _connection == null ||
          task.terminal) {
        return;
      }
      try {
        final connection = _connection!;
        final next = await getTask(connection, task.id);
        if (next.terminal) {
          await pendingStore?.remove(connection, 'image', task.id);
        }
        if (emit.isDone || event.generation != _generation) return;
        _accept(next, emit, event.generation);
      } catch (error) {
        if (!emit.isDone && event.generation == _generation) {
          emit(ImageState(task: task, error: _message(error)));
        }
      }
    });
    on<ImagePollingRetried>((event, emit) {
      if (state.busy || state.task == null || state.task!.terminal) return;
      emit(ImageState(task: state.task, busy: true));
      add(_ImagePolled(_generation));
    });
    on<ImagesCleared>((event, emit) {
      if ((state.busy || state.admissionUncertain) &&
          !event.discardUncertain &&
          !event.connectionChanged) {
        return;
      }
      ++_generation;
      _timer?.cancel();
      _connection = null;
      _pendingKey = null;
      _pendingRequest = null;
      emit(const ImageState());
    });
  }
  final GenerateImage generate;
  final GetImageTask getTask;
  final Duration pollInterval;
  final PendingGenerationStore? pendingStore;
  Timer? _timer;
  int _generation = 0;
  ServerConnection? _connection;
  String? _pendingKey;
  ImageRequested? _pendingRequest;
  String _message(Object error) => error is AppFailure
      ? error.message
      : 'Không thể tạo ảnh. Vui lòng thử lại.';
  void _accept(ImageTask task, Emitter<ImageState> emit, int generation) {
    emit(
      ImageState(
        task: task,
        busy: !task.terminal,
        error: task.status == ImageTaskStatus.failed
            ? 'Tạo ảnh thất bại. Kiểm tra tài khoản Muse và quota trên server rồi tạo lại.'
            : null,
      ),
    );
    if (!task.terminal) {
      _timer = Timer(pollInterval, () {
        if (!isClosed) add(_ImagePolled(generation));
      });
    }
  }

  @override
  Future<void> close() {
    ++_generation;
    _timer?.cancel();
    _connection = null;
    return super.close();
  }
}
