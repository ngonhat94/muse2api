import '../../features/connection/domain/entities/server_connection.dart';
import '../errors/app_failure.dart';

/// Rebuild media addresses from the selected server, never an upstream hostname.
Uri mediaUri(ServerConnection connection, String filename) {
  if (filename.isEmpty ||
      filename.contains('/') ||
      filename.contains('\\') ||
      filename.contains('..')) {
    throw const AppFailure('Tên media không hợp lệ.');
  }
  return connection.endpoint('/v1/media/${Uri.encodeComponent(filename)}');
}

/// Accepts only a short-lived server capability scoped to [filename].
/// Relative backend URLs are rebuilt against the configured proxy prefix.
Uri protectedMediaUri(
  ServerConnection connection,
  String value,
  String filename,
) {
  final plain = mediaUri(connection, filename);
  final supplied = Uri.tryParse(value);
  if (supplied == null ||
      supplied.userInfo.isNotEmpty ||
      supplied.hasFragment) {
    throw const AppFailure('Địa chỉ media được bảo vệ không hợp lệ.');
  }
  final parameters = supplied.queryParametersAll;
  final capability = parameters['cap'];
  if (parameters.length != 1 ||
      capability == null ||
      capability.length != 1 ||
      capability.single.isEmpty ||
      capability.single.length > 2048 ||
      !RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(capability.single)) {
    throw const AppFailure('Media thiếu quyền truy cập ngắn hạn hợp lệ.');
  }
  if (supplied.pathSegments.isEmpty || supplied.pathSegments.last != filename) {
    throw const AppFailure('Địa chỉ media không khớp tệp được yêu cầu.');
  }
  if (supplied.hasScheme || supplied.host.isNotEmpty) {
    final root = Uri.parse(connection.baseUrl);
    if (supplied.scheme != root.scheme ||
        supplied.host != root.host ||
        supplied.port != root.port ||
        supplied.path != plain.path) {
      throw const AppFailure('Media không thuộc server đang kết nối.');
    }
  }
  return plain.replace(queryParameters: {'cap': capability.single});
}
