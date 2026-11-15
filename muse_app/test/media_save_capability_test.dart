import 'package:flutter_test/flutter_test.dart';
import 'package:muse_app/core/domain/save_media.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';

void main() {
  const connection = ServerConnection(
    baseUrl: 'https://fixture.example/prefix',
    apiKey: 'synthetic-secret',
  );

  test(
    'save accepts exact server media capability and keeps its safe name',
    () {
      final source = MediaSaveSource.remote(
        connection,
        connection.endpoint('/v1/media/movie.mp4?cap=synthetic.capability'),
      );
      expect(source.suggestedName, 'movie.mp4');
    },
  );

  for (final suffix in [
    '',
    '?cap=',
    '?cap=one&cap=two',
    '?cap=one&key=synthetic-secret',
    '?cap=one#fragment',
  ]) {
    test('save rejects absent or ambiguous capability: $suffix', () {
      expect(
        () => MediaSaveSource.remote(
          connection,
          connection.endpoint('/v1/media/movie.mp4$suffix'),
        ).suggestedName,
        throwsA(isA<Exception>()),
      );
    });
  }
}
