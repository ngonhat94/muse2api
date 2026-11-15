import 'package:flutter/material.dart';

import '../../../../core/domain/save_media.dart';
import '../../../../core/presentation/media_save_button.dart';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/reference_image.dart';
import '../../../../core/presentation/generation_workspace.dart';
import '../../../../core/presentation/reference_picker.dart';
import '../../../connection/presentation/bloc/connection_bloc.dart';
import '../../domain/entities/image_task.dart';
import '../bloc/image_bloc.dart';

class ImagePage extends StatefulWidget {
  const ImagePage({
    super.key,
    required this.onConfigure,
    this.promptController,
    this.initialPrompt = '',
  });
  final VoidCallback onConfigure;
  final TextEditingController? promptController;
  final String initialPrompt;
  @override
  State<ImagePage> createState() => _ImagePageState();
}

class _ImagePageState extends State<ImagePage> {
  final _form = GlobalKey<FormState>();
  final _promptFocus = FocusNode();
  late final TextEditingController _prompt;
  List<ReferenceImage> _references = [];
  String _ratio = '1:1';
  bool _reading = false;
  @override
  void initState() {
    super.initState();
    _prompt =
        widget.promptController ??
        TextEditingController(text: widget.initialPrompt);
  }

  @override
  void didUpdateWidget(ImagePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPrompt != widget.initialPrompt) {
      _prompt.text = widget.initialPrompt;
    }
  }

  @override
  void dispose() {
    _promptFocus.dispose();
    if (widget.promptController == null) _prompt.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<ConnectionBloc, ServerConnectionState>(
    builder: (context, connection) => BlocBuilder<ImageBloc, ImageState>(
      builder: (context, state) {
        final task = state.task;
        final editing = _references.isNotEmpty;
        final locked =
            state.busy ||
            state.admissionUncertain ||
            (task != null && !task.terminal);
        final status = state.busy
            ? task == null
                  ? 'Đang gửi yêu cầu…'
                  : task.status == ImageTaskStatus.queued
                  ? 'Đang chờ tài khoản rảnh…'
                  : 'Muse đang tạo ảnh · ${task.progress.round()}%'
            : null;
        return GenerationWorkspace(
          title: 'Tạo & chỉnh ảnh',
          description: 'Mô tả ảnh mới hoặc thêm ảnh tham chiếu để chỉnh sửa cùng Muse Image.',
          form: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _prompt,
                  focusNode: _promptFocus,
                  enabled: !locked,
                  minLines: 4,
                  maxLines: 8,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Nhập mô tả hoặc yêu cầu chỉnh sửa.'
                      : null,
                  decoration: InputDecoration(
                    labelText: editing ? 'Yêu cầu chỉnh sửa' : 'Mô tả ảnh',
                    alignLabelWithHint: true,
                    hintText: editing
                        ? 'Giữ chủ thể, đổi nền thành một thành phố ban đêm…'
                        : 'Một chú Shiba đội mũ phi hành gia, ánh đèn neon…',
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Tỉ lệ khung hình',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['1:1', '16:9', '9:16', '4:3', '3:4']
                      .map(
                        (ratio) => ChoiceChip(
                          label: Text(ratio),
                          selected: ratio == _ratio,
                          onSelected: locked
                              ? null
                              : (_) => setState(() => _ratio = ratio),
                        ),
                      )
                      .toList(),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Divider(height: 1),
                ),
                ReferencePicker(
                  enabled: !locked,
                  onChanged: (images) => setState(() => _references = images),
                  onLoadingChanged: (reading) =>
                      setState(() => _reading = reading),
                ),
                const SizedBox(height: 24),
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        state.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
                FilledButton.icon(
                  onPressed: state.busy || state.admissionUncertain || _reading
                      ? null
                      : () {
                          final server = connection.connection;
                          if (server == null) {
                            widget.onConfigure();
                            return;
                          }
                          if (task != null && !task.terminal) {
                            context.read<ImageBloc>().add(
                              ImagePollingRetried(),
                            );
                            return;
                          }
                          if (!_form.currentState!.validate()) {
                            _promptFocus.requestFocus();
                            return;
                          }
                          context.read<ImageBloc>().add(
                            ImageRequested(
                              server,
                              _prompt.text,
                              _ratio,
                              references: _references,
                            ),
                          );
                        },
                  icon: Icon(
                    editing
                        ? Icons.edit_outlined
                        : Icons.add_photo_alternate_outlined,
                  ),
                  label: Text(
                    connection.connection == null
                        ? 'Kết nối server'
                        : state.busy
                        ? 'Đang xử lý…'
                        : task != null && !task.terminal
                        ? 'Tiếp tục theo dõi'
                        : editing
                        ? 'Chỉnh ảnh'
                        : 'Tạo ảnh',
                  ),
                ),
                if (state.admissionUncertain) ...[
                  OutlinedButton(
                    onPressed: () =>
                        context.read<ImageBloc>().add(ImageAdmissionRetried()),
                    child: const Text('Thử lại cùng yêu cầu'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final bloc = context.read<ImageBloc>();
                      final uncertainState = bloc.state;
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Bỏ yêu cầu chưa xác nhận?'),
                          content: const Text(
                            'Server có thể đã nhận yêu cầu này. Hãy kiểm tra Tác vụ trước. Bỏ yêu cầu không hủy tác vụ; tạo mới có thể tạo ảnh trùng và tốn quota.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Giữ yêu cầu'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Đã kiểm tra, bỏ yêu cầu'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true &&
                          mounted &&
                          !bloc.isClosed &&
                          identical(bloc.state, uncertainState) &&
                          bloc.state.admissionUncertain) {
                        bloc.add(ImagesCleared(discardUncertain: true));
                      }
                    },
                    child: const Text('Bỏ yêu cầu để tạo mới…'),
                  ),
                ],
                if (task != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: SelectableText(
                      'Tác vụ ${task.id}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
          preview: GenerationPreview(
            video: false,
            busy: state.busy,
            status: status,
            child: task?.bytes == null
                ? null
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.memory(
                          task!.bytes!,
                          semanticLabel: 'Ảnh do Muse tạo',
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) => const Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Không đọc được ảnh. Kiểm tra kết quả trong Thư viện.',
                            ),
                          ),
                        ),
                      ),
                      MediaSaveButton(
                        source: MediaSaveSource.image(task.bytes!),
                      ),
                    ],
                  ),
          ),
        );
      },
    ),
  );
}
