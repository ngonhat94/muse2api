import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muse_app/core/storage/pending_generation_store.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';

void main() {
  const a = ServerConnection(
    baseUrl: 'https://one.example',
    apiKey: 'PRIVATE_KEY',
  );
  const otherKey = ServerConnection(
    baseUrl: 'https://one.example',
    apiKey: 'OTHER_KEY',
  );
  const otherHost = ServerConnection(
    baseUrl: 'https://two.example',
    apiKey: 'PRIVATE_KEY',
  );
  test('pending IDs survive store recreation, isolated by server and credential; safe schema', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = PendingGenerationStore(prefs);
    await Future.wait([
      store.save(a, 'image', 'i-1'),
      store.save(a, 'video', 'v-1'),
    ]);
    await store.save(a, 'image', 'i-1');
    final relaunched = PendingGenerationStore(prefs);
    expect((await relaunched.list(a)).map((e) => e.id), ['i-1', 'v-1']);
    expect(await relaunched.list(otherKey), isEmpty);
    expect(await relaunched.list(otherHost), isEmpty);
    final raw = prefs.getKeys().map((k) => '$k:${prefs.getString(k)}').join();
    expect(raw, isNot(contains('PRIVATE_KEY')));
    expect(raw, isNot(contains('https://')));
    final data = jsonDecode(prefs.getString(prefs.getKeys().single)!);
    expect(data['tasks'].first, {'kind': 'image', 'id': 'i-1'});
    await relaunched.remove(a, 'image', 'i-1');
    expect((await relaunched.list(a)).single.id, 'v-1');
  });
}
