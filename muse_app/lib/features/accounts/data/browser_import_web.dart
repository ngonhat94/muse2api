import 'dart:async';
import 'dart:js_interop';
import 'dart:math';

import 'package:web/web.dart' as web;

import '../domain/repositories/browser_account_import.dart';
import '../../connection/domain/entities/server_connection.dart';

@JS('chrome.runtime.sendMessage')
external void _send(JSString extension, JSAny message, JSFunction callback);
@JS('chrome.runtime.lastError')
external JSAny? get _lastError;

class BrowserImport implements BrowserAccountImport {
  static const extensionId = 'lloaecnfmnmampknhgnpagabengejlaj';
  @override
  bool get supported =>
      web.window.location.origin == 'https://muapp-3d6.pages.dev' &&
      !RegExp(
        r'Android|iPhone|iPad|Mobile',
        caseSensitive: false,
      ).hasMatch(web.window.navigator.userAgent);
  Future<Map<String, dynamic>> _request(
    Map<String, dynamic> message,
    Duration timeout,
  ) async {
    if (!supported) return {};
    final completer = Completer<Map<String, dynamic>>();
    try {
      _send(
        extensionId.toJS,
        message.jsify()!,
        ((JSAny? response) {
          final failed = _lastError != null;
          if (completer.isCompleted) return;
          try {
            final value = failed ? null : response?.dartify();
            completer.complete(
              value is Map ? Map<String, dynamic>.from(value) : {},
            );
          } catch (_) {
            completer.complete({});
          }
        }).toJS,
      );
    } catch (_) {
      return {};
    }
    return completer.future.timeout(timeout, onTimeout: () => {});
  }

  @override
  Future<bool> available() async =>
      (await _request({
        'type': 'muse.ping',
      }, const Duration(seconds: 2)))['version'] ==
      1;
  @override
  Future<String> prepare() async {
    final random = Random.secure();
    return List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Future<String> _code(
    String id,
    Map<String, dynamic> message,
    int seconds,
  ) async {
    final response = await _request({
      'id': id,
      ...message,
    }, Duration(seconds: seconds));
    return response['id'] == id && response['code'] is String
        ? response['code'] as String
        : 'uncertain';
  }

  @override
  Future<String> approve(String id, ServerConnection c) =>
      _code(id, {'type': 'muse.prepare', 'base': c.baseUrl}, 95);
  @override
  Future<String> commit(String id, ServerConnection c) =>
      _code(id, {'type': 'muse.commit', 'key': c.apiKey}, 25);
  @override
  void cancel(String id) {
    unawaited(
      _request({'id': id, 'type': 'muse.cancel'}, const Duration(seconds: 2)),
    );
  }
}
