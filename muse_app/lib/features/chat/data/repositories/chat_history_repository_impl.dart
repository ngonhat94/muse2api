import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../connection/domain/entities/server_connection.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_thread.dart';
import '../../domain/repositories/chat_history_repository.dart';
import '../datasources/history_record_store.dart';

class ChatHistoryRepositoryImpl implements ChatHistoryRepository {
  ChatHistoryRepositoryImpl(this.store);
  final HistoryRecordStore store;
  Future<void> _queue = Future.value();
  String _key(ServerConnection c) =>
      'muse_chat_${sha256.convert(utf8.encode('${c.baseUrl}\u0000${c.apiKey}'))}';
  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _queue.then((_) => action());
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<List<ChatThread>> _read(ServerConnection c) async {
    try {
      final raw = await store.read(_key(c));
      if (raw == null) return [];
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['version'] != 1) throw const FormatException();
      final threads = (json['threads'] as List).map((item) {
        final e = item as Map<String, dynamic>;
        return ChatThread(
          id: e['id'] as String,
          updatedAt: DateTime.parse(e['updated_at'] as String),
          messages: (e['messages'] as List)
              .map(
                (m) => ChatMessage(
                  role: MessageRole.values.byName(m['role'] as String),
                  content: m['content'] as String,
                ),
              )
              .toList(),
        );
      }).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return threads;
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure(
        'Không đọc được lịch sử trên thiết bị. Dữ liệu cũ chưa bị ghi đè.',
      );
    }
  }

  Future<void> _write(ServerConnection c, List<ChatThread> threads) async {
    final raw = jsonEncode({
      'version': 1,
      'threads': threads
          .map(
            (t) => {
              'id': t.id,
              'updated_at': t.updatedAt.toUtc().toIso8601String(),
              'messages': t.messages
                  .map((m) => {'role': m.role.name, 'content': m.content})
                  .toList(),
            },
          )
          .toList(),
    });
    if (utf8.encode(raw).length > 2 * 1024 * 1024) {
      throw const AppFailure(
        'Lịch sử vượt 2 MiB. Xóa bớt cuộc trò chuyện để tiếp tục lưu.',
      );
    }
    try {
      await store.write(_key(c), raw);
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure(
        'Chưa lưu được lịch sử trên thiết bị. Nội dung vẫn còn trong phiên hiện tại.',
      );
    }
  }

  @override
  Future<List<ChatThread>> list(ServerConnection c) => _serial(() => _read(c));
  @override
  Future<void> save(ServerConnection c, ChatThread thread) => _serial(() async {
    final threads = await _read(c);
    threads.removeWhere((t) => t.id == thread.id);
    threads.insert(0, thread);
    await _write(c, threads);
  });
  @override
  Future<void> delete(ServerConnection c, String id) => _serial(() async {
    final threads = await _read(c);
    threads.removeWhere((t) => t.id == id);
    await _write(c, threads);
  });
}
