import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muse_app/features/connection/data/datasources/connection_local_data_source.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';

import '../support/memory_credential_store.dart';

void main() {
  test(
    'Restores server/key pair from credential store, not preferences',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final credentials = MemoryCredentialStore();
      final local = ConnectionLocalDataSource(preferences, credentials);
      await local.saveConnection(
        ServerConnection.parse('https://example.com', 'secret'),
      );
      expect(preferences.getKeys(), {'server_address'});
      final restored = await ConnectionLocalDataSource(
        preferences,
        credentials,
      ).readConnection();
      expect(restored!.baseUrl, 'https://example.com');
      expect(restored.apiKey, 'secret');
      await local.forgetConnection();
      expect(await local.readConnection(), isNull);
      expect(local.address, 'https://example.com');
    },
  );
  test(
    'A second server replaces both stored address and key together',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final local = ConnectionLocalDataSource(
        preferences,
        MemoryCredentialStore(),
      );
      await local.saveConnection(
        ServerConnection.parse('https://first.example', 'first-key'),
      );
      await local.saveConnection(
        ServerConnection.parse('https://second.example', 'second-key'),
      );
      final saved = await local.readConnection();
      expect(saved!.baseUrl, 'https://second.example');
      expect(saved.apiKey, 'second-key');
    },
  );
}
