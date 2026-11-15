import '../../../../core/errors/app_failure.dart';

class ServerPrincipal {
  const ServerPrincipal({
    required this.id,
    required this.label,
    required this.role,
    required this.capabilities,
  });
  final String id;
  final String label;
  final String role;
  final Map<String, bool> capabilities;
  bool get isAdmin => role == 'admin';
  bool can(String capability) => capabilities[capability] == true;
}

class ServerConnection {
  const ServerConnection({
    required this.baseUrl,
    required this.apiKey,
    this.isLocal = false,
  });
  final String baseUrl;
  final String apiKey;
  final bool isLocal;
  static final Expando<ServerPrincipal> _principals = Expando();
  ServerPrincipal? get principal => _principals[this];
  bool get isAdmin => isLocal || principal?.isAdmin == true;
  void attachPrincipal(ServerPrincipal value) => _principals[this] = value;

  factory ServerConnection.parse(String address, String key) {
    final uri = Uri.tryParse(address.trim());
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const AppFailure(
        'Nhập URL HTTP/HTTPS của server, không kèm key hoặc query.',
      );
    }
    if (key.trim().isEmpty) throw const AppFailure('Vui lòng nhập API key.');
    final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
    if (path.endsWith('/v1')) {
      throw const AppFailure(
        'Nhập địa chỉ gốc của server, bỏ phần /v1 ở cuối.',
      );
    }
    return ServerConnection(
      baseUrl: uri.replace(path: path).toString(),
      apiKey: key.trim(),
    );
  }

  Uri endpoint(String path) => Uri.parse('$baseUrl$path');
  Map<String, String> get headers => {'Authorization': 'Bearer $apiKey'};
  @override
  String toString() => 'ServerConnection($baseUrl, key: [redacted])';
}
