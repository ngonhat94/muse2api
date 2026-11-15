import 'package:flutter_test/flutter_test.dart';
import 'package:muse_app/features/media/domain/entities/media_item.dart';
import 'package:muse_app/features/media/domain/usecases/query_library.dart';

void main() {
  test('filters type and case-insensitive trimmed names; newest puts unknown last with stable ties', () {
    final old = MediaItem(
      name: 'Sun.png',
      isVideo: false,
      bytes: 1,
      createdAt: DateTime.utc(2025),
    );
    final recent = MediaItem(
      name: 'SUN.mp4',
      isVideo: true,
      bytes: 1,
      createdAt: DateTime.utc(2026),
    );
    const unknown = MediaItem(name: 'sunset.png', isVideo: false, bytes: 1);
    const other = MediaItem(name: 'moon.png', isVideo: false, bytes: 1);
    final input = [unknown, old, recent, other];
    expect(queryLibrary(input).map((e) => e.name), [
      'SUN.mp4',
      'Sun.png',
      'sunset.png',
      'moon.png',
    ]);
    expect(
      queryLibrary(
        input,
        type: LibraryType.images,
        search: ' SUN ',
      ).map((e) => e.name),
      ['Sun.png', 'sunset.png'],
    );
    expect(queryLibrary(input, type: LibraryType.videos).single, recent);
    expect(queryLibrary(input, newest: false), input);
    expect(input.first, unknown);
  });
}
