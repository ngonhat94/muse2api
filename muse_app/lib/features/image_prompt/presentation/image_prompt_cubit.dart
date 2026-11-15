import 'dart:typed_data';

import '../../../core/errors/app_failure.dart';

import 'package:bloc/bloc.dart';

import '../../../core/domain/reference_image.dart';
import '../data/prompt_image_loader.dart';
import '../domain/image_prompt_repository.dart';

class ImagePromptState {
  const ImagePromptState({
    this.image,
    this.sending = false,
    this.loading = false,
    this.prompt,
    this.error,
  });
  final ReferenceImage? image;
  final bool sending;
  final bool loading;
  final String? prompt;
  final String? error;
}

class ImagePromptCubit extends Cubit<ImagePromptState> {
  ImagePromptCubit(this.repository) : super(const ImagePromptState());
  final ImagePromptRepository repository;
  int _revision = 0;
  bool _current(int revision) => !isClosed && revision == _revision;
  void clear() {
    _revision++;
    if (!isClosed) emit(const ImagePromptState());
  }

  Future<void> select(String name, Uint8List bytes) async {
    final revision = ++_revision;
    if (isClosed) return;
    emit(const ImagePromptState(loading: true));
    try {
      final image = await const PromptImageLoader().load(name, bytes);
      if (_current(revision)) emit(ImagePromptState(image: image));
    } catch (error) {
      if (_current(revision)) {
        emit(
          ImagePromptState(
            error: error is AppFailure
                ? error.message
                : 'Không đọc được ảnh. Chọn tệp khác.',
          ),
        );
      }
    }
  }

  Future<void> generate() async {
    final image = state.image;
    if (isClosed || image == null || state.sending || state.loading) return;
    final revision = ++_revision;
    emit(ImagePromptState(image: image, sending: true));
    try {
      final prompt = await repository.generate(image);
      if (_current(revision)) {
        emit(ImagePromptState(image: image, prompt: prompt));
      }
    } catch (error) {
      if (_current(revision)) {
        emit(
          ImagePromptState(
            image: image,
            error: error is AppFailure
                ? error.message
                : 'Không lấy được prompt. Kiểm tra mạng rồi gửi lại thủ công.',
          ),
        );
      }
    }
  }
}
