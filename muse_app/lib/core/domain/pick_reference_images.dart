import 'reference_image.dart';

abstract interface class ReferenceFileSource {
  Future<List<ReferenceImage>> select({
    required int remainingFiles,
    required int remainingBytes,
  });
}

class PickReferenceImages {
  const PickReferenceImages(this.source);
  final ReferenceFileSource source;
  Future<List<ReferenceImage>> call(List<ReferenceImage> current) async {
    final selected = await source.select(
      remainingFiles: ReferenceImage.maxFiles - current.length,
      remainingBytes:
          ReferenceImage.maxTotalBytes -
          current.fold<int>(0, (n, image) => n + image.bytes.length),
    );
    final result = [...current, ...selected];
    ReferenceImage.validate(result);
    return List.unmodifiable(result);
  }
}
