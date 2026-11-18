import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/storage/credential_store.dart';
import '../../domain/entities/server_connection.dart';

class ConnectionLocalDataSource {
  ConnectionLocalDataSource(this.preferences, this.credentials);
  Future<void> _writes = Future.value();
  Future<void> _serial(Future<void> Function() action) {
    final result = _writes.then((_) => action());
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  final SharedPreferences preferences;
  final CredentialStore credentials;
  static const _addressKey = 'server_address';
  String? get address => preferences.getString(_addressKey);
  Future<ServerConnection?> readConnection() async {
    if (preferences.getBool('explicit_logout') == true) return null;
    final value = await credentials.read();
    if (value == null) return null;
    final json = jsonDecode(value) as Map<String, dynamic>;
    return ServerConnection.parse(
      json['baseUrl'] as String,
      json['apiKey'] as String,
    );
  }

  Future<void> saveConnection(ServerConnection connection) => _serial(() async {
    // Save the pair in one record; never restore a key against a different URL.
    await credentials.write(
      jsonEncode({'baseUrl': connection.baseUrl, 'apiKey': connection.apiKey}),
    );
    // Address is a convenience for the form; the secure record is authoritative.
    await preferences.setString(_addressKey, connection.baseUrl);
    if (!await preferences.remove('explicit_logout')) {
      throw StateError('Could not remember login state');
    }
  });

  Future<void> forgetConnection() => _serial(() async {
    // Persist the signed-out boundary first, including when secure deletion fails.
    if (!await preferences.setBool('explicit_logout', true)) {
      throw StateError('Could not persist logout');
    }
    await credentials.delete();
  });
}
