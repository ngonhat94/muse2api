import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:muse_app/core/errors/app_failure.dart';
import 'package:muse_app/core/network/session_client.dart';
import 'package:muse_app/features/accounts/data/repositories/extension_download_impl.dart';
import 'package:muse_app/features/accounts/domain/repositories/extension_download.dart';
import 'package:muse_app/features/accounts/presentation/bloc/extension_download_cubit.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';

class PendingDownload implements ExtensionDownload {
  final result = Completer<Uint8List>();
  int calls = 0;
  @override
  Future<Uint8List> fetch(ServerConnection connection) {
    calls++;
    return result.future;
  }
}

void main() {
  const connection = ServerConnection(
    baseUrl: 'https://configured.test/prefix',
    apiKey: 'synthetic-key',
  );
  test(
    'ZIP 401 uses session rejection and closes client; 403 does not reject',
    () async {
      for (final status in [401, 403]) {
        var rejections = 0;
        final client = SessionClient(
          MockClient((_) async => http.Response('private body', status)),
          (_, _) => rejections++,
        );
        final repository = ExtensionDownloadImpl(() => client);
        await expectLater(
          repository.fetch(connection),
          throwsA(isA<AppFailure>()),
        );
        expect(rejections, status == 401 ? 1 : 0);
        expect(client.isClosed, true);
      }
    },
  );
  test('late 401 from invalidated session cannot reject replacement', () async {
    var active = true;
    var rejections = 0;
    final response = Completer<http.Response>();
    final client = SessionClient(
      MockClient((_) => response.future),
      (_, _) => rejections++,
      isCurrent: () => active,
    );
    final pending = ExtensionDownloadImpl(() => client).fetch(connection);
    await Future<void>.delayed(Duration.zero);
    active = false;
    client.close();
    response.complete(http.Response('private', 401));
    await expectLater(pending, throwsA(isA<AppFailure>()));
    expect(rejections, 0);
  });
  for (final role in ['admin', 'user']) {
    test(
      '$role downloads from active backend using bearer header only',
      () async {
        connection.attachPrincipal(
          ServerPrincipal(
            id: role,
            label: role,
            role: role,
            capabilities: const {},
          ),
        );
        final repository = ExtensionDownloadImpl(
          () => MockClient((request) async {
            expect(request.method, 'GET');
            expect(
              request.url.toString(),
              'https://configured.test/prefix/admin/extension',
            );
            expect(request.url.hasQuery, false);
            expect(request.headers['Authorization'], 'Bearer synthetic-key');
            expect(request.followRedirects, false);
            return http.Response.bytes(
              [80, 75, 3, 4, 0],
              200,
              headers: {'content-type': 'application/zip'},
            );
          }),
        );
        expect(await repository.fetch(connection), [80, 75, 3, 4, 0]);
      },
    );
  }
  for (final status in [401, 403, 404, 302, 500, 200]) {
    test(
      'rejects status $status or invalid ZIP without exposing body',
      () async {
        final repo = ExtensionDownloadImpl(
          () => MockClient(
            (_) async => http.Response(
              'SECRET SERVER BODY',
              status,
              headers: {'content-type': 'text/html'},
            ),
          ),
        );
        try {
          await repo.fetch(connection);
          fail('must reject');
        } on AppFailure catch (error) {
          expect(error.message, isNot(contains('SECRET')));
        }
      },
    );
  }
  test('duplicate requests blocked and late logout result discarded', () async {
    final repo = PendingDownload();
    final cubit = ExtensionDownloadCubit(repo);
    var current = true;
    final pending = cubit.load(connection, () => current);
    await cubit.load(connection, () => current);
    expect(repo.calls, 1);
    current = false;
    cubit.reset();
    repo.result.complete(Uint8List.fromList([80, 75, 3, 4]));
    await pending;
    expect(cubit.state.bytes, isNull);
    expect(cubit.state.busy, false);
    await cubit.close();
  });
}
