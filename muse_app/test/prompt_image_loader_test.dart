import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:muse_app/features/image_prompt/data/prompt_image_loader.dart';

final png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAIAAAD8GO2jAAAAKklEQVR4nO3NQQkAAAgEsAtuGjMawBQ+hMH+y3SdikAgEAgEAoFAIPgSLF13SHk5j18ZAAAAAElFTkSuQmCC',
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('rejects corrupt signature-only images', () async {
    await expectLater(
      const PromptImageLoader().load(
        'fake.png',
        Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
      ),
      throwsException,
    );
  });
  test('rejects empty and unsupported bytes', () async {
    for (final bytes in [
      Uint8List(0),
      Uint8List.fromList([1, 2, 3]),
    ]) {
      await expectLater(
        const PromptImageLoader().load('fake.png', bytes),
        throwsException,
      );
    }
  });
  test('limits actual byte length to 10 MiB before decode', () async {
    await expectLater(
      const PromptImageLoader().load(
        'large.png',
        Uint8List(10 * 1024 * 1024 + 1),
      ),
      throwsA(predicate((e) => e.toString().contains('10 MiB'))),
    );
  });
  test('validates real image bytes independently of extension', () async {
    final image = await const PromptImageLoader().load('photo.exe', png);
    expect(image.mime, 'image/png');
    expect(image.bytes, png);
  });
}
