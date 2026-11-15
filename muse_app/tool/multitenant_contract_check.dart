import 'dart:io';

import 'package:muse_app/core/domain/save_media.dart';
import 'package:muse_app/core/network/media_uri.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';

void main() {
  const connection = ServerConnection(
    baseUrl: 'https://example.com/muse',
    apiKey: 'm2u_fixture-secret',
  );
  final uri = protectedMediaUri(
    connection,
    '/v1/media/movie.mp4?cap=fixture.capability',
    'movie.mp4',
  );
  assert(
    uri.toString() ==
        'https://example.com/muse/v1/media/movie.mp4?cap=fixture.capability',
  );
  assert(!uri.toString().contains(connection.apiKey));
  assert(MediaSaveSource.remote(connection, uri).suggestedName == 'movie.mp4');

  for (final unsafe in [
    '/v1/media/movie.mp4',
    '/v1/media/movie.mp4?key=m2u_fixture-secret',
    'https://evil.example/v1/media/movie.mp4?cap=x.y',
    '/v1/media/other.mp4?cap=x.y',
  ]) {
    var rejected = false;
    try {
      protectedMediaUri(connection, unsafe, 'movie.mp4');
    } catch (_) {
      rejected = true;
    }
    assert(rejected, 'unsafe media URL accepted: $unsafe');
  }
  stdout.writeln('PASS: protected media capability URL validation');
}
