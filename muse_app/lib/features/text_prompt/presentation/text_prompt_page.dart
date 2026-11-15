import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'text_prompt_cubit.dart';

class TextPromptPage extends StatefulWidget {
  const TextPromptPage({super.key, this.onCreateImage, this.onCreateVideo});
  final ValueChanged<String>? onCreateImage;
  final ValueChanged<String>? onCreateVideo;
  @override
  State<TextPromptPage> createState() => _TextPromptPageState();
}

class _TextPromptPageState extends State<TextPromptPage> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  @override
  void initState() {
    super.initState();
    _controller.text = context.read<TextPromptCubit>().state.text;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<TextPromptCubit, TextPromptState>(
        builder: (context, state) {
          final cubit = context.read<TextPromptCubit>();
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Văn bản thành prompt',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Mở rộng mô tả thành prompt chi tiết bằng Magic Enhance. Không cần kết nối Muse.',
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Chỉ khi bấm Tạo prompt, mô tả mới được gửi tới https://imageprompt.org/api/ai/prompts/magic-enhance. Không gửi thông tin riêng tư hoặc nhạy cảm. Không tự thử lại, không lưu mô tả/kết quả. Xóa không thu hồi dữ liệu đã gửi.',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _controller,
                      focusNode: _focus,
                      minLines: 4,
                      maxLines: 10,
                      maxLength: TextPromptCubit.maxLength,
                      decoration: InputDecoration(
                        labelText: 'Mô tả của bạn',
                        hintText: 'Ví dụ: chú chó màu đen tai cụp dễ thương',
                        errorText: state.error,
                      ),
                      onChanged: cubit.edit,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Giới hạn 4000 ký tự là giới hạn an toàn của app, không phải giới hạn được công bố của dịch vụ. Web có thể bị CORS chặn; hãy dùng bản desktop hoặc trang gốc imageprompt.org.',
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          icon: const Icon(Icons.auto_fix_high_outlined),
                          label: Text(
                            state.sending ? 'Đang tạo prompt…' : 'Tạo prompt',
                          ),
                          onPressed: state.sending
                              ? null
                              : () {
                                  if (state.text.trim().isEmpty) {
                                    _focus.requestFocus();
                                  }
                                  cubit.generate();
                                },
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.clear),
                          label: const Text('Xóa mô tả'),
                          onPressed: () {
                            _controller.clear();
                            cubit.clear();
                          },
                        ),
                      ],
                    ),
                    if (state.sending) ...[
                      const SizedBox(height: 16),
                      Semantics(
                        label: 'Đang tạo prompt',
                        liveRegion: true,
                        child: const LinearProgressIndicator(),
                      ),
                    ],
                    if (state.prompt != null) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Prompt đã mở rộng',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      SelectableText(state.prompt!),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          OutlinedButton.icon(
                            onPressed: widget.onCreateImage == null
                                ? null
                                : () => widget.onCreateImage!(state.prompt!),
                            icon: const Icon(Icons.image_outlined),
                            label: const Text('Dùng để tạo ảnh'),
                          ),
                          OutlinedButton.icon(
                            onPressed: widget.onCreateVideo == null
                                ? null
                                : () => widget.onCreateVideo!(state.prompt!),
                            icon: const Icon(Icons.movie_outlined),
                            label: const Text('Dùng để tạo video'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.copy_outlined),
                          label: const Text('Sao chép prompt'),
                          onPressed: () async {
                            try {
                              await Clipboard.setData(
                                ClipboardData(text: state.prompt!),
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Đã sao chép prompt.'),
                                ),
                              );
                            } catch (_) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Không sao chép được. Hãy chọn và sao chép văn bản.',
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      );
}
