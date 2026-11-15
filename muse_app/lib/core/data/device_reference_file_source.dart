import 'package:file_selector/file_selector.dart';

import '../domain/pick_reference_images.dart';
import '../domain/reference_image.dart';
import '../errors/app_failure.dart';

class DeviceReferenceFileSource implements ReferenceFileSource {
  const DeviceReferenceFileSource();
  @override
  Future<List<ReferenceImage>> select({
    required int remainingFiles,
    required int remainingBytes,
  }) async {
    final files = await openFiles(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'Ảnh',
          extensions: ['png', 'jpg', 'jpeg', 'webp', 'gif'],
          uniformTypeIdentifiers: ['public.image'],
        ),
      ],
    );
    if (files.length > remainingFiles) {
      throw const AppFailure('Tối đa 10 ảnh tham chiếu. Chọn ít ảnh hơn.');
    }
    var remaining = remainingBytes;
    final images = <ReferenceImage>[];
    for (final file in files) {
      final length = await file.length();
      if (length > ReferenceImage.maxFileBytes) {
        throw AppFailure('${file.name}: ảnh vượt 40 MiB.');
      }
      if (length > remaining) {
        throw const AppFailure('Tổng ảnh vượt 100 MiB. Chọn ít ảnh hơn.');
      }
      final image = ReferenceImage.fromBytes(
        file.name,
        await file.readAsBytes(),
      );
      remaining -= image.bytes.length;
      if (remaining < 0) {
        throw const AppFailure('Tổng ảnh vượt 100 MiB. Chọn ít ảnh hơn.');
      }
      images.add(image);
    }
    return images;
  }
}
