import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:muse_app/core/data/media_saver_io.dart';
import 'package:muse_app/core/domain/save_media.dart';

void main() {
  test(
    'atomic publish refuses destination created after final check',
    () async {
      final dir = await Directory.systemTemp.createTemp('publish-race-');
      addTearDown(() => dir.delete(recursive: true));
      final target = File('${dir.path}/race.bin');
      final saver = NativeMediaSaver(
        pickPath: (_) async => target.path,
        replaceExisting: false,
        beforePublish: () async => target.writeAsBytes([9]),
      );
      await expectLater(
        saver.save(
          MediaSaveSource.image(Uint8List.fromList([255, 216, 255])),
          isCurrent: () => true,
        ),
        throwsA(isA<Exception>()),
      );
      expect(await target.readAsBytes(), [9]);
      expect(dir.listSync().length, 1);
    },
  );
}
