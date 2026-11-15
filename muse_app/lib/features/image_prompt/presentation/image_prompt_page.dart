import 'package:file_selector/file_selector.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/prompt_image_loader.dart';
import 'image_prompt_cubit.dart';

class ImagePromptPage extends StatefulWidget {
  const ImagePromptPage({
    super.key,
    this.pickImage,
    this.onCreateImage,
    this.onCreateVideo,
  });
  final ValueChanged<String>? onCreateImage;
  final ValueChanged<String>? onCreateVideo;
  final Future<XFile?> Function()? pickImage;
  @override
  State<ImagePromptPage> createState() => _ImagePromptPageState();
}

class _ImagePromptPageState extends State<ImagePromptPage> {
  bool _picking = false;
  int _pickRevision = 0;
  String? _localError;
  bool _dragging = false;
  Future<void> _drop(DropDoneDetails details) async {
    if (details.files.length != 1 || details.files.single is! DropItemFile) {
      setState(() => _localError = 'Chỉ thả một tệp ảnh, không phải thư mục.');
      return;
    }
    await _pickFile(() async => details.files.single);
  }

  Future<void> _pickFile(Future<XFile?> Function() source) async {
    final revision = ++_pickRevision;
    setState(() {
      _picking = true;
      _localError = null;
    });
    final cubit = context.read<ImagePromptCubit>();
    try {
      final file = await source();
      if (!mounted || revision != _pickRevision || file == null) return;
      cubit.clear();
      if (await file.length() > PromptImageLoader.maxBytes) {
        if (!mounted || revision != _pickRevision) return;
        cubit.clear();
        setState(() => _localError = 'Ảnh vượt 10 MiB. Chọn tệp nhỏ hơn.');
        return;
      }
      final bytes = await file.readAsBytes();
      if (mounted && revision == _pickRevision) {
        await cubit.select(file.name, bytes);
      }
    } catch (_) {
      if (mounted && revision == _pickRevision) {
        setState(() => _localError = 'Không mở được tệp. Thử chọn ảnh lại.');
      }
    } finally {
      if (mounted && revision == _pickRevision) {
        setState(() => _picking = false);
      }
    }
  }

  Future<void> _pick() => _pickFile(
    widget.pickImage ??
        () => openFile(
          acceptedTypeGroups: const [
            XTypeGroup(
              label: 'Ảnh',
              extensions: ['png', 'jpg', 'jpeg', 'webp', 'gif'],
              mimeTypes: ['image/png', 'image/jpeg', 'image/webp', 'image/gif'],
            ),
          ],
        ),
  );
  Future<void> _copy(String prompt) async {
    try {
      await Clipboard.setData(ClipboardData(text: prompt));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Đã sao chép prompt.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Không sao chép được. Hãy chọn và sao chép văn bản bên dưới.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<ImagePromptCubit, ImagePromptState>(
    builder: (context, state) {
      final cubit = context.read<ImagePromptCubit>();
      final error = _localError ?? state.error;
      return Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Align(
            alignment: Alignment.topLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ảnh thành prompt',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Chọn ảnh, xem trước rồi lấy mô tả bằng tiếng Anh. Không cần kết nối Muse.',
                  ),
                  const SizedBox(height: 24),
                  DropTarget(
                    onDragDone: _drop,
                    onDragEntered: (_) => setState(() => _dragging = true),
                    onDragExited: (_) => setState(() => _dragging = false),
                    child: Card(
                      shape: _dragging
                          ? RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            )
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (state.image case final image?) ...[
                              Semantics(
                                label: 'Xem trước ảnh đã chọn',
                                image: true,
                                child: Image.memory(
                                  image.bytes,
                                  height: 240,
                                  fit: BoxFit.contain,
                                  cacheWidth: 600,
                                  errorBuilder: (_, _, _) => const Text(
                                    'Không hiển thị được ảnh. Chọn ảnh khác.',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(image.name),
                              const SizedBox(height: 16),
                            ] else ...[
                              const Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 40,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Thả một ảnh vào đây hoặc chọn từ thiết bị',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                            ],
                            const Text(
                              'PNG, JPEG, WebP hoặc GIF · tối đa 10 MiB. Ảnh chỉ được gửi khi bấm Lấy prompt.',
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _picking || state.loading
                                      ? null
                                      : _pick,
                                  icon: const Icon(Icons.folder_open),
                                  label: Text(
                                    _picking || state.loading
                                        ? 'Đang đọc ảnh…'
                                        : state.image == null
                                        ? 'Chọn ảnh'
                                        : 'Đổi ảnh',
                                  ),
                                ),
                                if (state.image != null ||
                                    state.loading ||
                                    state.sending)
                                  TextButton.icon(
                                    onPressed: () {
                                      _pickRevision++;
                                      setState(() {
                                        _localError = null;
                                        _picking = false;
                                      });
                                      cubit.clear();
                                    },
                                    icon: const Icon(Icons.close),
                                    label: const Text('Xóa ảnh'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Khi bấm Lấy prompt, toàn bộ ảnh được gửi tới imageprompt.org (dịch vụ bên thứ ba). Không gửi ảnh riêng tư. Không sử dụng cookie hay khóa API Muse.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Bản web có thể bị CORS chặn. Khi đó dùng bản desktop hoặc imageprompt.org; ứng dụng không tự thử lại.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed:
                        state.image == null ||
                            state.sending ||
                            state.loading ||
                            _picking
                        ? null
                        : cubit.generate,
                    icon: state.sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome_outlined),
                    label: Text(
                      state.sending ? 'Đang lấy prompt…' : 'Lấy prompt',
                    ),
                  ),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          error,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  if (state.prompt case final prompt?) ...[
                    const SizedBox(height: 32),
                    Text(
                      'Prompt tiếng Anh',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    SelectableText(prompt),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OutlinedButton.icon(
                          onPressed: widget.onCreateImage == null
                              ? null
                              : () => widget.onCreateImage!(prompt),
                          icon: const Icon(Icons.image_outlined),
                          label: const Text('Dùng để tạo ảnh'),
                        ),
                        OutlinedButton.icon(
                          onPressed: widget.onCreateVideo == null
                              ? null
                              : () => widget.onCreateVideo!(prompt),
                          icon: const Icon(Icons.movie_outlined),
                          label: const Text('Dùng để tạo video'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => _copy(prompt),
                      icon: const Icon(Icons.copy_outlined),
                      label: const Text('Sao chép prompt'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
