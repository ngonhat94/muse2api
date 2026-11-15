import 'package:bloc/bloc.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/text_prompt_repository.dart';

class TextPromptState {
  const TextPromptState({
    this.text = '',
    this.sending = false,
    this.prompt,
    this.error,
  });
  final String text;
  final bool sending;
  final String? prompt;
  final String? error;
}

class TextPromptCubit extends Cubit<TextPromptState> {
  TextPromptCubit(this.repository) : super(const TextPromptState());
  final TextPromptRepository repository;
  // Local safety cap; not a claimed service limit.
  static const maxLength = 4000;
  int _revision = 0;
  bool _current(int revision) => !isClosed && revision == _revision;
  void edit(String text) {
    if (isClosed) return;
    _revision++;
    emit(TextPromptState(text: text));
  }

  void clear() => edit('');
  Future<void> generate() async {
    if (isClosed || state.sending) return;
    final text = state.text;
    if (text.trim().isEmpty || text.length > maxLength) {
      emit(
        TextPromptState(text: text, error: 'Nhập mô tả từ 1 đến 4000 ký tự.'),
      );
      return;
    }
    final revision = ++_revision;
    emit(TextPromptState(text: text, sending: true));
    try {
      final prompt = await repository.enhance(text);
      if (_current(revision)) emit(TextPromptState(text: text, prompt: prompt));
    } catch (error) {
      if (_current(revision)) {
        emit(
          TextPromptState(
            text: text,
            error: error is AppFailure
                ? error.message
                : 'Không lấy được prompt. Kiểm tra mạng rồi gửi lại thủ công.',
          ),
        );
      }
    }
  }
}
