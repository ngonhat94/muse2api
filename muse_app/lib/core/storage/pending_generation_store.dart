import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/connection/domain/entities/server_connection.dart';
import '../errors/app_failure.dart';

class PendingGeneration {
  const PendingGeneration(this.kind, this.id);
  final String kind;
  final String id;
}

/// Only opaque task identifiers are persisted; never prompts, images or credentials.
class PendingGenerationStore {
  PendingGenerationStore(this.preferences);
  final SharedPreferences preferences;
  Future<void> _queue = Future.value();
  String _key(ServerConnection c) =>
      'pending_generation_v1_${sha256.convert(utf8.encode('${c.baseUrl}\u0000${c.apiKey}'))}';
  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  List<PendingGeneration> _read(ServerConnection c) {
    final raw = preferences.getString(_key(c));
    if (raw == null) return [];
    try {
      final data = jsonDecode(raw);
      if (data is! Map || data['version'] != 1 || data['tasks'] is! List) {
        throw const FormatException();
      }
      return (data['tasks'] as List).map((e) {
        if (e is! Map ||
            !['image', 'video'].contains(e['kind']) ||
            e['id'] is! String ||
            (e['id'] as String).isEmpty ||
            (e['id'] as String).length > 512) {
          throw const FormatException();
        }
        return PendingGeneration(e['kind'] as String, e['id'] as String);
      }).toList();
    } catch (_) {
      throw const AppFailure(
        'Không đọc được danh sách tác vụ đã lưu. Dữ liệu cũ chưa bị ghi đè.',
      );
    }
  }

  Future<List<PendingGeneration>> list(ServerConnection c) =>
      _serial(() async => _read(c));
  Future<void> _write(ServerConnection c, List<PendingGeneration> tasks) async {
    final ok = await preferences.setString(
      _key(c),
      jsonEncode({
        'version': 1,
        'tasks': tasks.map((e) => {'kind': e.kind, 'id': e.id}).toList(),
      }),
    );
    if (!ok) {
      throw const AppFailure(
        'Chưa lưu được mã tác vụ. Giữ mã tác vụ để theo dõi thủ công.',
      );
    }
  }

  Future<void> save(ServerConnection c, String kind, String id) =>
      _serial(() async {
        final tasks = _read(c);
        if (!tasks.any((e) => e.kind == kind && e.id == id)) {
          tasks.add(PendingGeneration(kind, id));
        }
        await _write(c, tasks);
      });
  Future<void> remove(ServerConnection c, String kind, String id) =>
      _serial(() async {
        final tasks = _read(c)
          ..removeWhere((e) => e.kind == kind && e.id == id);
        await _write(c, tasks);
      });
}
