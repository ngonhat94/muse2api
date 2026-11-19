import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:muse_app/features/accounts/domain/repositories/browser_account_import.dart';
import 'package:muse_app/features/accounts/presentation/bloc/browser_import_cubit.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';

class FixtureBridge implements BrowserAccountImport {
  @override
  BrowserImportCapability capability = BrowserImportCapability.supported;
  @override
  bool get supported => capability == BrowserImportCapability.supported;
  int pings = 0;
  bool installed = true;
  String approval = 'approved';
  String result = 'imported';
  Completer<String>? gate;
  int commits = 0;
  ServerConnection? received;
  final cancelled = <String>[];
  @override
  Future<bool> available() async {
    pings++;
    return installed;
  }

  @override
  Future<String> prepare() async => 'a' * 64;
  @override
  Future<String> approve(String id, ServerConnection c) async =>
      gate == null ? approval : await gate!.future;
  @override
  Future<String> commit(String id, ServerConnection c) async {
    commits++;
    received = c;
    return result;
  }

  @override
  void cancel(String id) => cancelled.add(id);
}

const connection = ServerConnection(
  baseUrl: 'https://muse.dntrip.xyz',
  apiKey: 'synthetic-key',
);
Future<void> tick() => Future<void>.delayed(Duration.zero);
void main() {
  test('capability preserves exact origin policy and detects mobile', () {
    expect(
      browserImportCapabilityFor(
        origin: 'https://muapp-3d6.pages.dev',
        userAgent: 'Chrome desktop',
      ),
      BrowserImportCapability.supported,
    );
    expect(
      browserImportCapabilityFor(
        origin: 'https://muse.dntrip.xyz',
        userAgent: 'Chrome desktop',
      ),
      BrowserImportCapability.supported,
    );
    for (final origin in [
      'https://preview.pages.dev',
      'http://muse.dntrip.xyz',
      'https://preview.muse.dntrip.xyz',
      'https://muse.dntrip.xyz.evil.example',
      'https://muse.dntrip.xyz:8443',
      'https://unknown.example',
      'http://muapp-3d6.pages.dev',
      '$approvedBrowserImportOrigin.evil.example',
    ]) {
      expect(
        browserImportCapabilityFor(origin: origin, userAgent: 'Chrome desktop'),
        BrowserImportCapability.unsupportedOrigin,
      );
    }
    for (final agent in ['Android', 'iPhone', 'iPad', 'Mobile']) {
      expect(
        browserImportCapabilityFor(
          origin: approvedBrowserImportOrigin,
          userAgent: agent,
        ),
        BrowserImportCapability.unsupportedDevice,
      );
    }
  });
  test('unsupported origin/device never ping, approve or commit', () async {
    for (final capability in [
      BrowserImportCapability.unsupportedOrigin,
      BrowserImportCapability.unsupportedDevice,
      BrowserImportCapability.native,
    ]) {
      final bridge = FixtureBridge()..capability = capability;
      final cubit = BrowserImportCubit(bridge);
      await cubit.run(connection, () => true);
      expect(bridge.pings, 0);
      expect(bridge.commits, 0);
      expect(cubit.state.busy, isFalse);
      expect(cubit.state.message, contains('thủ công'));
      expect(cubit.state.message, isNot(contains('Chưa tìm thấy extension')));
      expect(cubit.state.message, isNot(contains(connection.apiKey)));
      await cubit.close();
    }
  });

  test(
    'imports once using exact captured session, no credential in state',
    () async {
      final bridge = FixtureBridge();
      final cubit = BrowserImportCubit(bridge);
      await cubit.run(connection, () => true);
      expect(bridge.commits, 1);
      expect(identical(bridge.received, connection), isTrue);
      expect(cubit.state.imported, isTrue);
      expect(cubit.state.message, isNot(contains(connection.apiKey)));
      await cubit.close();
    },
  );
  test('missing extension and denial never submit', () async {
    for (final approval in ['cancelled', 'expired', 'invalid_destination']) {
      final bridge = FixtureBridge()..approval = approval;
      final cubit = BrowserImportCubit(bridge);
      await cubit.run(connection, () => true);
      expect(bridge.commits, 0);
      expect(cubit.state.busy, isFalse);
      await cubit.close();
    }
    final bridge = FixtureBridge()..installed = false;
    final cubit = BrowserImportCubit(bridge);
    await cubit.run(connection, () => true);
    expect(bridge.commits, 0);
    expect(cubit.state.message, contains('thủ công'));
    await cubit.close();
  });
  test('duplicate guarded; disconnected approval cannot upload; reset releases busy', () async {
    final bridge = FixtureBridge()..gate = Completer<String>();
    final cubit = BrowserImportCubit(bridge);
    var current = true;
    final first = cubit.run(connection, () => current);
    await tick();
    await cubit.run(connection, () => current);
    expect(bridge.commits, 0);
    current = false;
    cubit.reset();
    bridge.gate!.complete('approved');
    await first;
    expect(bridge.commits, 0);
    expect(cubit.state.busy, isFalse);
    expect(bridge.cancelled, isNotEmpty);
    await cubit.close();
  });
  test('in-flight close ignores late approval', () async {
    final bridge = FixtureBridge()..gate = Completer<String>();
    final cubit = BrowserImportCubit(bridge);
    final pending = cubit.run(connection, () => true);
    await tick();
    await cubit.close();
    bridge.gate!.complete('approved');
    await pending;
    expect(bridge.commits, 0);
  });
  test('uncertain result does not retry mutation', () async {
    final bridge = FixtureBridge()..result = 'uncertain';
    final cubit = BrowserImportCubit(bridge);
    await cubit.run(connection, () => true);
    expect(bridge.commits, 1);
    expect(cubit.state.imported, isFalse);
    expect(cubit.state.message, contains('tải lại'));
    await cubit.close();
  });
}
