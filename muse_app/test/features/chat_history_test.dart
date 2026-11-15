import 'dart:async';

import 'package:test/test.dart';
import 'package:muse_app/core/errors/app_failure.dart';
import 'package:muse_app/features/chat/data/datasources/history_record_store.dart';
import 'package:muse_app/features/chat/data/repositories/chat_history_repository_impl.dart';
import 'package:muse_app/features/chat/domain/entities/chat_message.dart';
import 'package:muse_app/features/chat/domain/entities/chat_thread.dart';
import 'package:muse_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:muse_app/features/chat/domain/repositories/chat_history_repository.dart';
import 'package:muse_app/features/chat/domain/usecases/manage_chat_history.dart';
import 'package:muse_app/features/chat/domain/usecases/send_message.dart';
import 'package:muse_app/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';

const server = ServerConnection(
  baseUrl: 'https://example.com',
  apiKey: 'fixture-secret',
);
const other = ServerConnection(
  baseUrl: 'https://other.example',
  apiKey: 'fixture-secret',
);

class MemoryHistory implements HistoryRecordStore {
  final values = <String, String>{};
  bool fail = false;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    await Future<void>.delayed(const Duration(milliseconds: 1));
    if (fail) throw StateError('disk');
    values[key] = value;
  }
}

ChatThread thread(String id, [String text = 'Hello']) => ChatThread(
  id: id,
  updatedAt: DateTime.utc(2026, 11, 7),
  messages: [ChatMessage(role: MessageRole.user, content: text)],
);

class Replies implements ChatRepository {
  StreamController<String>? reply;
  List<ChatMessage> sent = [];
  @override
  Stream<String> streamReply(ServerConnection c, List<ChatMessage> messages) {
    sent = messages;
    reply = StreamController();
    return reply!.stream;
  }
}

class DelayedCancellationReplies implements ChatRepository {
  final cancelling = Completer<void>();
  final cancelled = Completer<void>();
  late final reply = StreamController<String>(
    onCancel: () {
      cancelling.complete();
      return cancelled.future;
    },
  );

  @override
  Stream<String> streamReply(ServerConnection c, List<ChatMessage> messages) =>
      reply.stream;
}

Future<ChatState> waitFor(ChatBloc bloc, bool Function(ChatState) predicate) =>
    bloc.stream.firstWhere(predicate).timeout(const Duration(seconds: 3));
Future<void> session(ChatBloc bloc, ServerConnection connection) async {
  final ready = waitFor(bloc, (s) => !s.historyLoading);
  bloc.add(ChatSessionChanged(connection));
  await ready;
}

Future<void> talk(ChatBloc bloc, Replies replies, String text) async {
  final started = waitFor(bloc, (s) => s.isStreaming);
  bloc.add(ChatSubmitted(text, server));
  await started;
  await Future<void>.delayed(Duration.zero);
  final finished = waitFor(
    bloc,
    (s) =>
        !s.isStreaming && s.messages.lastOrNull?.role == MessageRole.assistant,
  );
  replies.reply!.add('Answer');
  await replies.reply!.close();
  await finished;
}

class DelayedDeletionHistory implements ChatHistoryRepository {
  DelayedDeletionHistory(this.repository);
  final ChatHistoryRepository repository;
  final deleting = Completer<void>();
  final deleted = Completer<void>();
  final completed = Completer<void>();

  @override
  Future<List<ChatThread>> list(ServerConnection c) => repository.list(c);
  @override
  Future<void> save(ServerConnection c, ChatThread t) => repository.save(c, t);
  @override
  Future<void> delete(ServerConnection c, String id) async {
    deleting.complete();
    await deleted.future;
    await repository.delete(c, id);
    completed.complete();
  }
}

class SlowHistory implements ChatHistoryRepository {
  final pending = Completer<List<ChatThread>>();
  @override
  Future<List<ChatThread>> list(ServerConnection c) =>
      c.baseUrl == server.baseUrl ? pending.future : Future.value([]);
  @override
  Future<void> save(ServerConnection c, ChatThread t) async {}
  @override
  Future<void> delete(ServerConnection c, String id) async {}
}

void main() {
  test('History round trips and scopes by server plus API key without persisting credentials', () async {
    final store = MemoryHistory();
    final repo = ChatHistoryRepositoryImpl(store);
    await repo.save(server, thread('a'));
    expect((await repo.list(server)).single.messages.single.content, 'Hello');
    expect(await repo.list(other), isEmpty);
    expect(
      await repo.list(
        const ServerConnection(
          baseUrl: 'https://example.com',
          apiKey: 'changed',
        ),
      ),
      isEmpty,
    );
    expect(store.values.keys.single, isNot(contains('fixture-secret')));
    expect(store.values.values.single, isNot(contains('fixture-secret')));
  });
  test('Concurrent saves serialize and deletion cannot be undone by an older write', () async {
    final repo = ChatHistoryRepositoryImpl(MemoryHistory());
    await Future.wait([
      repo.save(server, thread('a')),
      repo.save(server, thread('b')),
      repo.save(server, thread('a', 'Updated')),
    ]);
    expect((await repo.list(server)).length, 2);
    final save = repo.save(server, thread('a', 'Final'));
    final delete = repo.delete(server, 'a');
    await Future.wait([save, delete]);
    expect((await repo.list(server)).map((t) => t.id), ['b']);
  });
  test('Corrupt records are preserved instead of overwritten', () async {
    final store = MemoryHistory();
    final repo = ChatHistoryRepositoryImpl(store);
    await repo.save(server, thread('a'));
    final key = store.values.keys.single;
    store.values[key] = 'broken';
    await expectLater(repo.list(server), throwsA(isA<AppFailure>()));
    await expectLater(
      repo.save(server, thread('b')),
      throwsA(isA<AppFailure>()),
    );
    expect(store.values[key], 'broken');
  });
  test('Storage quota failure retains the last successful record', () async {
    final store = MemoryHistory();
    final repo = ChatHistoryRepositoryImpl(store);
    await repo.save(server, thread('a'));
    final before = Map.of(store.values);
    await expectLater(
      repo.save(server, thread('b', 'x' * (2 * 1024 * 1024))),
      throwsA(isA<AppFailure>()),
    );
    expect(store.values, before);
  });
  test('New conversation keeps previous chat and reopening restores latest messages', () async {
    final repo = ChatHistoryRepositoryImpl(MemoryHistory());
    final replies = Replies();
    final bloc = ChatBloc(
      SendMessage(replies),
      history: ManageChatHistory(repo),
    );
    await session(bloc, server);
    await talk(bloc, replies, 'First');
    final firstId = bloc.state.activeId!;
    final cleared = waitFor(bloc, (s) => s.messages.isEmpty);
    bloc.add(ChatCleared());
    await cleared;
    expect(bloc.state.threads.single.id, firstId);
    await talk(bloc, replies, 'Second');
    await bloc.close();
    final reopened = ChatBloc(
      SendMessage(Replies()),
      history: ManageChatHistory(repo),
    );
    addTearDown(reopened.close);
    await session(reopened, server);
    expect(reopened.state.messages.first.content, 'Second');
    expect(reopened.state.threads.length, 2);
    final opened = waitFor(reopened, (s) => s.activeId == firstId);
    reopened.add(ChatThreadOpened(firstId));
    await opened;
    expect(reopened.state.messages.first.content, 'First');
  });
  test(
    'Changing server removes old history from view and subsequent context',
    () async {
      final repo = ChatHistoryRepositoryImpl(MemoryHistory());
      await repo.save(server, thread('old', 'Private first-server content'));
      final replies = Replies();
      final bloc = ChatBloc(
        SendMessage(replies),
        history: ManageChatHistory(repo),
      );
      addTearDown(bloc.close);
      await session(bloc, server);
      expect(bloc.state.messages, isNotEmpty);
      await session(bloc, other);
      expect(bloc.state.messages, isEmpty);
      expect(bloc.state.threads, isEmpty);
      final started = waitFor(bloc, (s) => s.isStreaming);
      bloc.add(ChatSubmitted('New server', other));
      await started;
      await Future<void>.delayed(Duration.zero);
      expect(replies.sent.single.content, 'New server');
    },
  );
  test('Deleting active streaming thread prevents late content and saved snapshots from resurrecting it', () async {
    final repo = ChatHistoryRepositoryImpl(MemoryHistory());
    final replies = Replies();
    final bloc = ChatBloc(
      SendMessage(replies),
      history: ManageChatHistory(repo),
    );
    addTearDown(bloc.close);
    await session(bloc, server);
    final started = waitFor(bloc, (s) => s.isStreaming);
    bloc.add(ChatSubmitted('Delete me', server));
    await started;
    await Future<void>.delayed(Duration.zero);
    final old = replies.reply!;
    old.add('partial');
    await Future<void>.delayed(Duration.zero);
    final id = bloc.state.activeId!;
    final deleted = waitFor(bloc, (s) => s.messages.isEmpty);
    bloc.add(ChatThreadDeleted(id));
    await deleted;
    old.add('late');
    await Future<void>.delayed(Duration.zero);
    expect(await repo.list(server), isEmpty);
    expect(bloc.state.messages, isEmpty);
    await old.close();
  });
  test(
    'Stopping persists the partial reply for restoration without late chunks',
    () async {
      final repo = ChatHistoryRepositoryImpl(MemoryHistory());
      final replies = Replies();
      final bloc = ChatBloc(
        SendMessage(replies),
        history: ManageChatHistory(repo),
      );
      addTearDown(bloc.close);
      await session(bloc, server);
      final started = waitFor(bloc, (s) => s.isStreaming);
      bloc.add(ChatSubmitted('Keep my reply', server));
      await started;
      await Future<void>.delayed(Duration.zero);
      final partial = waitFor(
        bloc,
        (s) => s.messages.last.content == 'Partial',
      );
      replies.reply!.add('Partial');
      await partial;
      final stopped = waitFor(bloc, (s) => !s.isStreaming);
      bloc.add(ChatStopped());
      await stopped;
      replies.reply!.add(' must not be saved');
      await Future<void>.delayed(Duration.zero);
      await replies.reply!.close();
      final saved = (await repo.list(server)).single;
      expect(saved.messages.map((m) => m.content), [
        'Keep my reply',
        'Partial',
      ]);
      await session(bloc, other);
      expect(bloc.state.messages, isEmpty);
      await session(bloc, server);
      expect(bloc.state.activeId, saved.id);
      expect(bloc.state.messages.map((m) => m.content), [
        'Keep my reply',
        'Partial',
      ]);
      expect(bloc.state.isStreaming, false);
    },
  );
  test('Deleting a streaming thread cannot clear a server opened during cancellation', () async {
    final repo = ChatHistoryRepositoryImpl(MemoryHistory());
    final history = DelayedDeletionHistory(repo);
    final replies = DelayedCancellationReplies();
    await repo.save(server, thread('old', 'Old server'));
    // Matching IDs must still be isolated by connection.
    await repo.save(other, thread('old', 'Other server'));
    final bloc = ChatBloc(
      SendMessage(replies),
      history: ManageChatHistory(history),
    );
    addTearDown(() async {
      if (!replies.cancelled.isCompleted) replies.cancelled.complete();
      if (!history.deleted.isCompleted) history.deleted.complete();
      await bloc.close();
    });
    await session(bloc, server);
    final started = waitFor(bloc, (s) => s.isStreaming);
    bloc.add(ChatSubmitted('Delete this reply', server));
    await started;
    await Future<void>.delayed(Duration.zero);
    bloc.add(ChatThreadDeleted('old'));
    await replies.cancelling.future;

    final loading = waitFor(bloc, (s) => s.historyLoading);
    bloc.add(ChatSessionChanged(other));
    await loading;
    final restored = waitFor(bloc, (s) => !s.historyLoading);
    replies.cancelled.complete();
    await restored;
    await history.deleting.future;
    expect(bloc.state.messages.single.content, 'Other server');
    history.deleted.complete();
    await history.completed.future;
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.activeId, 'old');
    expect(bloc.state.messages.single.content, 'Other server');
    expect(bloc.state.threads.single.id, 'old');
    expect(await repo.list(server), isEmpty);
    expect(
      (await repo.list(other)).single.messages.single.content,
      'Other server',
    );
  });
  test(
    'Save failure is visible and does not discard current messages',
    () async {
      final store = MemoryHistory()..fail = true;
      final repo = ChatHistoryRepositoryImpl(store);
      final replies = Replies();
      final bloc = ChatBloc(
        SendMessage(replies),
        history: ManageChatHistory(repo),
      );
      addTearDown(bloc.close);
      await session(bloc, server);
      final failed = waitFor(bloc, (s) => s.historyError != null);
      bloc.add(ChatSubmitted('Keep me', server));
      await failed;
      expect(bloc.state.messages.first.content, 'Keep me');
      expect(store.values, isEmpty);
    },
  );

  test(
    'Save warning stays visible during streaming until a write succeeds',
    () async {
      final store = MemoryHistory()..fail = true;
      final repo = ChatHistoryRepositoryImpl(store);
      final replies = Replies();
      final bloc = ChatBloc(
        SendMessage(replies),
        history: ManageChatHistory(repo),
      );
      addTearDown(bloc.close);
      await session(bloc, server);
      final failed = waitFor(bloc, (s) => s.historyError != null);
      bloc.add(ChatSubmitted('Keep me', server));
      await failed;
      replies.reply!.add('partial');
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.historyError, isNotNull);
      store.fail = false;
      final saved = waitFor(bloc, (s) => s.historyError == null);
      bloc.add(ChatHistoryFlushed());
      await saved;
      expect(bloc.state.isStreaming, true);
      expect((await repo.list(server)).single.messages.last.content, 'partial');
    },
  );

  test('Late history restoration from a previous server cannot enter the new session', () async {
    final repository = SlowHistory();
    final bloc = ChatBloc(
      SendMessage(Replies()),
      history: ManageChatHistory(repository),
    );
    addTearDown(bloc.close);
    final loading = waitFor(bloc, (s) => s.historyLoading);
    bloc.add(ChatSessionChanged(server));
    await loading;
    await session(bloc, other);
    repository.pending.complete([thread('private', 'Old server content')]);
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.messages, isEmpty);
    expect(bloc.state.threads, isEmpty);
  });

  test(
    'Failed deletion retains active identity and messages for retry',
    () async {
      final store = MemoryHistory();
      final repo = ChatHistoryRepositoryImpl(store);
      await repo.save(server, thread('keep', 'Keep this chat'));
      final bloc = ChatBloc(
        SendMessage(Replies()),
        history: ManageChatHistory(repo),
      );
      addTearDown(bloc.close);
      await session(bloc, server);
      store.fail = true;
      final failed = waitFor(bloc, (s) => s.historyError != null);
      bloc.add(ChatThreadDeleted('keep'));
      await failed;
      expect(bloc.state.activeId, 'keep');
      expect(bloc.state.messages.first.content, 'Keep this chat');
    },
  );
}
