import 'dart:async';

import 'package:test/test.dart';
import 'package:muse_app/core/errors/app_failure.dart';
import 'package:muse_app/features/chat/domain/entities/chat_message.dart';
import 'package:muse_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:muse_app/features/chat/domain/usecases/send_message.dart';
import 'package:muse_app/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:muse_app/features/connection/domain/entities/server_connection.dart';

class FakeChatRepository implements ChatRepository {
  StreamController<String>? reply;
  List<ChatMessage> history = [];
  int calls = 0;
  bool cancelled = false;
  @override
  Stream<String> streamReply(
    ServerConnection connection,
    List<ChatMessage> messages,
  ) {
    calls++;
    history = messages;
    reply = StreamController(
      onCancel: () {
        cancelled = true;
      },
    );
    return reply!.stream;
  }
}

Future<void> tick() => Future<void>.delayed(Duration.zero);
const connection = ServerConnection(baseUrl: 'http://localhost', apiKey: 'key');
void main() {
  test(
    'Accumulates deltas, sends history, and blocks duplicate submissions',
    () async {
      final repository = FakeChatRepository();
      final bloc = ChatBloc(SendMessage(repository));
      addTearDown(bloc.close);
      bloc.add(ChatSubmitted('Hello', connection));
      bloc.add(ChatSubmitted('Duplicate', connection));
      await tick();
      expect(repository.calls, 1);
      repository.reply!.add('Xin ');
      repository.reply!.add('chào');
      await tick();
      expect(bloc.state.messages.last.content, 'Xin chào');
      await repository.reply!.close();
      await tick();
      expect(bloc.state.isStreaming, false);
      bloc.add(ChatSubmitted('Next', connection));
      await tick();
      expect(repository.history.map((message) => message.content), [
        'Hello',
        'Xin chào',
        'Next',
      ]);
    },
  );
  test(
    'Stop cancels transport; late chunks cannot contaminate a new conversation',
    () async {
      final repository = FakeChatRepository();
      final bloc = ChatBloc(SendMessage(repository));
      addTearDown(bloc.close);
      bloc.add(ChatSubmitted('Hello', connection));
      await tick();
      final oldReply = repository.reply!;
      oldReply.add('partial');
      await tick();
      bloc.add(ChatStopped());
      await tick();
      expect(repository.cancelled, true);
      expect(bloc.state.messages.last.content, 'partial');
      bloc.add(ChatCleared());
      await tick();
      oldReply.add('late');
      await tick();
      expect(bloc.state.messages, isEmpty);
      expect(bloc.state.isStreaming, false);
      await oldReply.close();
    },
  );
  test(
    'Streaming error preserves partial content and releases sending state',
    () async {
      final repository = FakeChatRepository();
      final bloc = ChatBloc(SendMessage(repository));
      addTearDown(bloc.close);
      bloc.add(ChatSubmitted('Hello', connection));
      await tick();
      repository.reply!.add('partial');
      await tick();
      repository.reply!.addError(const AppFailure('Offline'));
      await tick();
      expect(bloc.state.error, 'Offline');
      expect(bloc.state.isStreaming, false);
      expect(bloc.state.messages.last.content, 'partial');
      expect(repository.cancelled, true);
      await repository.reply!.close();
    },
  );
}
