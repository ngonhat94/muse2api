import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/storage/credential_store.dart';
import '../../domain/entities/server_connection.dart';

class ConnectionLocalDataSource {
  const ConnectionLocalDataSource(this.preferences, this.credentials);
  final SharedPreferences preferences;
  final CredentialStore credentials;
  static const _addressKey = 'server_address';
  String? get address => preferences.getString(_addressKey);
  Future<ServerConnection?> readConnection() async {
    final value = await credentials.read();
    if (value == null) return null;
    final json = jsonDecode(value) as Map<String, dynamic>;
    return ServerConnection.parse(
      json['baseUrl'] as String,
      json['apiKey'] as String,
    );
  }

  Future<void> saveConnection(ServerConnection connection) async {
    // Save the pair in one record; never restore a key against a different URL.
    await credentials.write(
      jsonEncode({'baseUrl': connection.baseUrl, 'apiKey': connection.apiKey}),
    );
    // Address is a convenience for the form; the secure record is authoritative.
    await preferences.setString(_addressKey, connection.baseUrl);
  }

  Future<void> forgetConnection() => credentials.delete();
}
