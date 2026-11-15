import 'package:bloc/bloc.dart';

import '../domain/pick_reference_images.dart';
import '../domain/reference_image.dart';
import '../errors/app_failure.dart';

class ReferenceState {
  ReferenceState({
    List<ReferenceImage> images = const [],
    this.loading = false,
    this.error,
  }) : images = List.unmodifiable(images);
  final List<ReferenceImage> images;
  final bool loading;
  final String? error;
}

class ReferenceCubit extends Cubit<ReferenceState> {
  ReferenceCubit(this.pickImages) : super(ReferenceState());
  final PickReferenceImages pickImages;
  Future<void> pick() async {
    if (state.loading) return;
    emit(ReferenceState(images: state.images, loading: true));
    try {
      final images = await pickImages(state.images);
      if (!isClosed) emit(ReferenceState(images: images));
    } catch (error) {
      if (!isClosed) {
        emit(
          ReferenceState(
            images: state.images,
            error: error is AppFailure
                ? error.message
                : 'Không đọc được ảnh. Vui lòng chọn lại.',
          ),
        );
      }
    }
  }

  void remove(int index) {
    if (state.loading) return;
    final images = [...state.images]..removeAt(index);
    emit(ReferenceState(images: images));
  }

  void move(int index, int destination) {
    if (state.loading ||
        destination < 0 ||
        destination >= state.images.length) {
      return;
    }
    final images = [...state.images];
    final image = images.removeAt(index);
    images.insert(destination, image);
    emit(ReferenceState(images: images));
  }
}
