// Isolated visual fixture. No network client, stored credentials or real Muse calls.
// flutter build web -t tool/dashboard_preview.dart --output build/dashboard_preview
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:muse_app/app/app.dart';
import 'package:muse_app/app/dependencies.dart';
import 'package:muse_app/core/storage/credential_store.dart';
import 'package:muse_app/features/chat/data/datasources/history_record_store.dart';

class FixtureCredentials implements CredentialStore {
  String? value = jsonEncode({
    'baseUrl': 'https://fixture.invalid',
    'apiKey': 'test-only',
  });
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    this.value = value;
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}

class FixtureHistory implements HistoryRecordStore {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // This tool is a test-only entry point; isolate preferences from real storage.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({});
  final dependencies = AppDependencies(
    await SharedPreferences.getInstance(),
    credentialStore: FixtureCredentials(),
    historyStore: FixtureHistory(),
    clientFactory: () => MockClient((request) async {
      if (request.method != 'GET') {
        return http.Response(
          '{"error":"Visual fixture: actions disabled"}',
          403,
        );
      }
      final body = request.url.path == '/admin/accounts'
          ? {
              'accounts': [
                {
                  'id': 'fixture-a',
                  'label': 'TEST • Muse workspace',
                  'enabled': true,
                  'ok': true,
                  'quota': {
                    'plan': 'Test plan',
                    'weekly_used_pct': 25,
                    'weekly_reset': 'Fixture · Monday',
                    'extra_used_pct': 0,
                    'extra_left': 'Test data',
                    'extra_expires': 'Fixture only',
                    'checked_at': '2026-11-12T00:00:00Z',
                  },
                },
                {
                  'id': 'fixture-b',
                  'label': 'TEST • Unknown quota',
                  'enabled': false,
                },
              ],
            }
          : {'data': []};
      return http.Response(
        jsonEncode(body),
        200,
        headers: {'content-type': 'application/json'},
      );
    }),
  );
  runApp(
    Banner(
      message: 'TEST FIXTURE',
      location: BannerLocation.topEnd,
      textDirection: TextDirection.ltr,
      layoutDirection: TextDirection.ltr,
      child: MuseApp(dependencies: dependencies),
    ),
  );
}
