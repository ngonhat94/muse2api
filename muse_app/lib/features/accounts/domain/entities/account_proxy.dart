import '../../../../core/errors/app_failure.dart';

class SavedAccountProxy {
  const SavedAccountProxy({
    required this.server,
    this.username = '',
    this.hasPassword = false,
  });
  final String server;
  final String username;
  final bool hasPassword;
}

class ProxyConfiguration {
  const ProxyConfiguration._(this.server, this.username, this.password);
  final String server;
  final String username;
  final String? password;
  static String normalizeServer(String input) {
    final raw = input.trim();
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        !['http', 'socks5', 'socks5h'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        !['', '/'].contains(uri.path) ||
        uri.hasQuery ||
        uri.hasFragment ||
        RegExp(r'\s').hasMatch(raw) ||
        uri.host.contains('%') ||
        uri.host.contains('\\')) {
      throw const AppFailure(
        'Dùng http://host:port hoặc socks5://host:port, không kèm tài khoản trong URL.',
      );
    }
    final port = uri.hasPort
        ? uri.port
        : uri.scheme == 'http'
        ? 80
        : 1080;
    if (port < 1 || port > 65535) {
      throw const AppFailure('Cổng proxy phải nằm trong khoảng 1–65535.');
    }
    final host = uri.host.contains(':') && !uri.host.startsWith('[')
        ? '[${uri.host}]'
        : uri.host;
    return '${uri.scheme}://$host:$port';
  }

  static void validateUsername(String username) {
    if (username.contains(':') ||
        username.runes.any((c) => c < 32 || c > 255)) {
      throw const AppFailure(
        'Tên đăng nhập không được chứa dấu hai chấm, ký tự điều khiển hoặc ký tự ngoài Latin-1.',
      );
    }
  }

  factory ProxyConfiguration.parse(
    String raw,
    String username,
    String password, {
    SavedAccountProxy? previous,
    bool clearPassword = false,
  }) {
    final server = normalizeServer(raw);
    validateUsername(username);
    if (password.runes.any((c) => c > 255)) {
      throw const AppFailure('Mật khẩu proxy cần dùng ký tự Latin-1.');
    }
    final same = previous?.server == server && previous?.username == username;
    if (password.isEmpty && !clearPassword && !same && username.isNotEmpty) {
      throw const AppFailure(
        'Nhập mật khẩu khi thay đổi địa chỉ hoặc tên đăng nhập proxy.',
      );
    }
    return ProxyConfiguration._(
      server,
      username,
      clearPassword
          ? ''
          : password.isNotEmpty
          ? password
          : same
          ? null
          : '',
    );
  }
  @override
  String toString() => 'ProxyConfiguration($server, credentials: [redacted])';
}

class ProxyCheck {
  const ProxyCheck({
    required this.reachable,
    required this.sessionConfirmed,
    this.exitIp,
  });
  final bool reachable;
  final bool sessionConfirmed;
  final String? exitIp;
  bool get passed => reachable && sessionConfirmed;
}
