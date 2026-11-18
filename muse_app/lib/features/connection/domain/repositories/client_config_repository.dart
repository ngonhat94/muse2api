import '../entities/server_connection.dart';

const defaultServerUrl =
    'https://18610-agq6gp235jkrlip6hyszdk5ctm.instabox.tech';
const bootstrapServerUrl = String.fromEnvironment(
  'MUSE_BOOTSTRAP_URL',
  defaultValue: defaultServerUrl,
);

String validateSharedServerUrl(String value) {
  final uri = Uri.tryParse(value);
  if (value.length > 2048 ||
      RegExp(r'[\s\\\x00-\x1f\x7f]').hasMatch(value) ||
      uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      !RegExp(r'^[A-Za-z0-9.-]+$').hasMatch(uri.host) ||
      uri.userInfo.isNotEmpty ||
      value.contains('@') ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.port == 0 ||
      uri.path.contains('%') ||
      uri.pathSegments.any((part) => part == '.' || part == '..') ||
      uri.path.replaceFirst(RegExp(r'/+$'), '').endsWith('/v1')) {
    throw const FormatException('URL HTTPS không hợp lệ.');
  }
  return value.replaceFirst(RegExp(r'/+$'), '');
}

abstract interface class ClientConfigRepository {
  Future<String> load();
  Future<String> save(ServerConnection connection, String address);
}
