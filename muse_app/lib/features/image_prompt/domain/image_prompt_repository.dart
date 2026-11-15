import '../../../core/domain/reference_image.dart';

abstract interface class ImagePromptRepository {
  Future<String> generate(ReferenceImage image);
}
