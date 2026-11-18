import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muse_app/core/network/session_client.dart';

void main() {
  test(
    'only authenticated 401 reports rejection, never 403 or public request',
    () async {
      final rejected = <String>[];
      for (final status in [200, 401, 403, 500]) {
        for (final authenticated in [false, true]) {
          final client = SessionClient(
            MockClient((_) async => http.Response('{}', status)),
            (uri, authorization) => rejected.add('$uri $authorization'),
          );
          final response = await client.get(
            Uri.parse('https://fixture.example/v1/tasks'),
            headers: {if (authenticated) 'Authorization': 'Bearer synthetic'},
          );
          expect(response.statusCode, status);
          client.close();
        }
      }
      expect(rejected, ['https://fixture.example/v1/tasks Bearer synthetic']);
    },
  );
}
