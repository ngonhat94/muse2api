import 'dart:async';
import 'dart:math';

import 'package:bloc/bloc.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../connection/domain/entities/server_connection.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_thread.dart';
import '../../domain/usecases/send_message.dart';
import '../../domain/usecases/manage_chat_history.dart';

sealed class ChatEvent {}

class ChatSubmitted extends ChatEvent {
  ChatSubmitted(this.text, this.connection);
  final String text;
  final ServerConnection connection;
}

class ChatStopped extends ChatEvent {}

class ChatCleared extends ChatEvent {}

class ChatSessionChanged extends ChatEvent {
  ChatSessionChanged(this.connection);
  final ServerConnection? connection;
}

class ChatThreadOpened extends ChatEvent {
  ChatThreadOpened(this.id);
  final String id;
}

class ChatThreadDeleted extends ChatEvent {
  ChatThreadDeleted(this.id);
  final String id;
}

class ChatHistoryFlushed extends ChatEvent {}

class _ReplyReceived extends ChatEvent {
  _ReplyReceived(this.text, this.generation);
  final String text;
  final int generation;
}

class _ReplyFinished extends ChatEvent {
  _ReplyFinished(this.generation, [this.error]);
  final int generation;
  final String? error;
}

class _HistoryChanged extends ChatEvent {
  final bool saved;
  _HistoryChanged(this.generation, [this.error, this.saved = false]);
  final int generation;
  final String? error;
}

class ChatState {
  ChatState({
    List<ChatMessage> messages = const [],
    List<ChatThread> threads = const [],
    this.activeId,
    this.isStreaming = false,
    this.historyLoading = false,
    this.error,
    this.historyError,
  }) : messages = List.unmodifiable(messages),
       threads = List.unmodifiable(threads);
  final List<ChatMessage> messages;
  final List<ChatThread> threads;
  final String? activeId;
  final bool isStreaming;
  final bool historyLoading;
  final String? error;
  final String? historyError;
}

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc(this.sendMessage, {this.history}) : super(ChatState()) {
    on<ChatSessionChanged>((event, emit) async {
      unawaited(_persist());
      final generation = ++_generation;
      _timer?.cancel();
      _timer = null;
      _sessionInitialized = true;
      _connection = event.connection;
      _activeId = null;
      _threads = [];
      _historyError = null;
      emit(
        ChatState(historyLoading: event.connection != null && history != null),
      );
      final previousSubscription = _subscription;
      _subscription = null;
      await previousSubscription?.cancel();
      if (event.connection == null ||
          history == null ||
          emit.isDone ||
          generation != _generation) {
        return;
      }
      try {
        final threads = await history!.list(event.connection!);
        if (emit.isDone || generation != _generation) return;
        _threads = threads;
        _activeId = threads.firstOrNull?.id;
        emit(_state(messages: threads.firstOrNull?.messages ?? []));
      } catch (error) {
        if (!emit.isDone && generation == _generation) {
          emit(_state(historyError: _message(error)));
        }
      }
    });
    on<ChatSubmitted>((event, emit) async {
      final text = event.text.trim();
      if (state.isStreaming ||
          state.historyLoading ||
          text.isEmpty ||
          (_sessionInitialized && _connection == null)) {
        return;
      }
      if (_connection != null &&
          (_connection!.baseUrl != event.connection.baseUrl ||
              _connection!.apiKey != event.connection.apiKey)) {
        return;
      }
      _connection ??= event.connection;
      _activeId ??=
          '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 30)}';
      final generation = ++_generation;
      final previous = _subscription;
      _subscription = null;
      final messages = [
        ...state.messages.where((m) => m.content.isNotEmpty),
        ChatMessage(role: MessageRole.user, content: text),
      ];
      emit(
        _state(
          messages: [
            ...messages,
            const ChatMessage(role: MessageRole.assistant, content: ''),
          ],
          streaming: true,
        ),
      );
      unawaited(_persist());
      await previous?.cancel();
      if (emit.isDone || generation != _generation) return;
      _subscription = sendMessage(event.connection, messages).listen(
        (chunk) {
          if (!isClosed) add(_ReplyReceived(chunk, generation));
        },
        onError: (Object error) {
          if (!isClosed) add(_ReplyFinished(generation, _message(error)));
        },
        onDone: () {
          if (!isClosed) add(_ReplyFinished(generation));
        },
        cancelOnError: true,
      );
    });
    on<_ReplyReceived>((event, emit) {
      if (event.generation != _generation || !state.isStreaming) return;
      final messages = [...state.messages];
      messages[messages.length - 1] = ChatMessage(
        role: MessageRole.assistant,
        content: messages.last.content + event.text,
      );
      emit(_state(messages: messages, streaming: true));
      _timer ??= Timer(const Duration(seconds: 2), () {
        _timer = null;
        if (!isClosed) add(ChatHistoryFlushed());
      });
    });
    on<_ReplyFinished>((event, emit) {
      if (event.generation != _generation || !state.isStreaming) return;
      _timer?.cancel();
      _timer = null;
      emit(
        _state(
          messages: state.messages.where((m) => m.content.isNotEmpty).toList(),
          error: event.error,
        ),
      );
      unawaited(_persist());
    });
    on<ChatStopped>((event, emit) async {
      ++_generation;
      _timer?.cancel();
      _timer = null;
      emit(
        _state(
          messages: state.messages.where((m) => m.content.isNotEmpty).toList(),
        ),
      );
      unawaited(_persist());
      await _subscription?.cancel();
    });
    on<ChatCleared>((event, emit) async {
      unawaited(_persist());
      ++_generation;
      _timer?.cancel();
      _timer = null;
      _activeId = null;
      emit(_state(messages: []));
      await _subscription?.cancel();
    });
    on<ChatThreadOpened>((event, emit) async {
      if (state.historyLoading || event.id == _activeId) return;
      unawaited(_persist());
      final thread = _threads.where((t) => t.id == event.id).firstOrNull;
      if (thread == null) return;
      ++_generation;
      _timer?.cancel();
      _timer = null;
      _activeId = thread.id;
      emit(_state(messages: thread.messages));
      await _subscription?.cancel();
    });
    on<ChatThreadDeleted>((event, emit) async {
      final connection = _connection;
      if (connection == null || history == null) return;
      final active = event.id == _activeId;
      final generation = active ? ++_generation : _generation;
      if (active) {
        _timer?.cancel();
        _timer = null;
        _activeId = null;
        await _subscription?.cancel();
      }
      try {
        await history!.delete(connection, event.id);
        if (emit.isDone || generation != _generation) return;
        _threads = _threads.where((t) => t.id != event.id).toList();
        emit(
          _state(
            messages: active ? [] : state.messages,
            streaming: !active && state.isStreaming,
          ),
        );
      } catch (error) {
        if (!emit.isDone && generation == _generation) {
          if (active) _activeId = event.id;
          emit(_state(historyError: _message(error)));
        }
      }
    });
    on<ChatHistoryFlushed>((event, emit) async {
      await _persist();
    });
    on<_HistoryChanged>((event, emit) {
      if (event.generation != _generation) return;
      if (event.saved) _historyError = null;
      emit(
        _state(
          messages: state.messages,
          streaming: state.isStreaming,
          error: state.error,
          historyError: event.error,
        ),
      );
    });
  }
  final SendMessage sendMessage;
  final ManageChatHistory? history;
  StreamSubscription<String>? _subscription;
  Timer? _timer;
  int _generation = 0;
  bool _sessionInitialized = false;
  bool _closing = false;
  ServerConnection? _connection;
  String? _activeId;
  List<ChatThread> _threads = [];
  String? _historyError;
  String _message(Object error) => error is AppFailure
      ? error.message
      : 'Không thể hoàn tất thao tác. Vui lòng thử lại.';
  ChatState _state({
    List<ChatMessage>? messages,
    bool streaming = false,
    String? error,
    String? historyError,
  }) {
    if (historyError != null) _historyError = historyError;
    return ChatState(
      messages: messages ?? state.messages,
      threads: _threads,
      activeId: _activeId,
      isStreaming: streaming,
      error: error,
      historyError: _historyError,
    );
  }

  Future<void> _persist() async {
    final connection = _connection;
    final id = _activeId;
    final generation = _generation;
    if (history == null ||
        connection == null ||
        id == null ||
        state.messages.isEmpty) {
      return;
    }
    final messages = state.messages.where((m) => m.content.isNotEmpty).toList();
    if (messages.isEmpty) return;
    final thread = ChatThread(
      id: id,
      updatedAt: DateTime.now(),
      messages: messages,
    );
    _threads = [thread, ..._threads.where((t) => t.id != id)];
    if (!isClosed && !_closing) add(_HistoryChanged(generation));
    try {
      await history!.save(connection, thread);
      if (!isClosed && !_closing) add(_HistoryChanged(generation, null, true));
    } catch (error) {
      if (!isClosed && !_closing) {
        add(_HistoryChanged(generation, _message(error)));
      }
    }
  }

  @override
  Future<void> close() async {
    _closing = true;
    _timer?.cancel();
    ++_generation;
    await _subscription?.cancel();
    await _persist();
    return super.close();
  }
}
