import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/domain/generation_task.dart';
import '../../../../core/domain/reference_image.dart';
import '../../../../core/presentation/generation_workspace.dart';
import '../../../../core/presentation/media_preview.dart';
import '../../../../core/presentation/reference_picker.dart';
import '../../../connection/presentation/bloc/connection_bloc.dart';
import '../bloc/video_bloc.dart';

class VideoPage extends StatefulWidget {
  const VideoPage({
    super.key,
    required this.onConfigure,
    this.promptController,
    required this.onTasks,
  });
  final VoidCallback onConfigure;
  final TextEditingController? promptController;
  final VoidCallback onTasks;
  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  final _form = GlobalKey<FormState>();
  final _focus = FocusNode();
  late final TextEditingController _prompt;
  @override
  void initState() {
    super.initState();
    _prompt = widget.promptController ?? TextEditingController();
  }

  List<ReferenceImage> _references = [];
  bool _reading = false;
  String _ratio = '16:9';
  int _duration = 6;
  @override
  void dispose() {
    _focus.dispose();
    if (widget.promptController == null) _prompt.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<ConnectionBloc, ServerConnectionState>(
    builder: (context, connection) => BlocBuilder<VideoBloc, VideoState>(
      builder: (context, state) {
        final task = state.task;
        final server = connection.connection;
        final locked =
            state.busy ||
            (task != null && !task.terminal) ||
            state.admissionUncertain;
        final status = state.busy
            ? task == null
                  ? 'Đang gửi yêu cầu…'
                  : task.status == GenerationStatus.queued
                  ? 'Đang chờ tài khoản rảnh…'
                  : 'Muse đang tạo video · mốc ${task.progress.round()}%'
            : null;
        return GenerationWorkspace(
          title: 'Tạo video',
          description: 'Bắt đầu bằng mô tả hoặc dùng ảnh của bạn làm khung hình đầu tiên.',
          form: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _prompt,
                  focusNode: _focus,
                  enabled: !locked,
                  minLines: 4,
                  maxLines: 8,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Mô tả chuyển động bạn muốn tạo.'
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả video',
                    alignLabelWithHint: true,
                    hintText: 'Máy quay tiến chậm về phía chủ thể, ánh sáng chiều ấm…',
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
                  children: ['16:9', '9:16']
                      .map(
                        (ratio) => ChoiceChip(
                          label: Text(ratio),
                          selected: _ratio == ratio,
                          onSelected: locked
                              ? null
                              : (_) => setState(() => _ratio = ratio),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 24),
                Text(
                  'Thời lượng yêu cầu',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [5, 6, 8, 10]
                      .map(
                        (seconds) => ChoiceChip(
                          label: Text('$seconds giây'),
                          selected: _duration == seconds,
                          onSelected: locked
                              ? null
                              : (_) => setState(() => _duration = seconds),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                Text(
                  'Thời lượng thực tế phụ thuộc kết quả từ Muse.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Divider(height: 1),
                ),
                ReferencePicker(
                  video: true,
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
                  onPressed: state.busy || _reading
                      ? null
                      : () {
                          if (server == null) {
                            widget.onConfigure();
                            return;
                          }
                          if (state.admissionUncertain) {
                            widget.onTasks();
                            return;
                          }
                          if (task != null && !task.terminal) {
                            context.read<VideoBloc>().add(
                              VideoPollingRetried(),
                            );
                            return;
                          }
                          if (!_form.currentState!.validate()) {
                            _focus.requestFocus();
                            return;
                          }
                          context.read<VideoBloc>().add(
                            VideoRequested(
                              server,
                              _prompt.text,
                              _ratio,
                              _duration,
                              references: _references,
                            ),
                          );
                        },
                  icon: const Icon(Icons.movie_creation_outlined),
                  label: Text(
                    server == null
                        ? 'Kết nối server'
                        : state.busy
                        ? 'Đang xử lý…'
                        : state.admissionUncertain
                        ? 'Kiểm tra tác vụ'
                        : task != null && !task.terminal
                        ? 'Tiếp tục theo dõi'
                        : 'Tạo video',
                  ),
                ),
                if (state.admissionUncertain)
                  OutlinedButton(
                    onPressed: () =>
                        context.read<VideoBloc>().add(VideoAdmissionRetried()),
                    child: const Text('Thử lại cùng yêu cầu'),
                  ),
                if (state.admissionUncertain)
                  TextButton(
                    onPressed: () =>
                        context.read<VideoBloc>().add(VideosCleared()),
                    child: const Text('Đã kiểm tra tác vụ, cho phép tạo lại'),
                  ),
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
            video: true,
            busy: state.busy,
            status: status,
            child:
                task?.status == GenerationStatus.completed &&
                    task?.protectedUri != null &&
                    server != null
                ? MediaPreview(
                    uri: task!.protectedUri!,
                    connection: server,
                    video: true,
                  )
                : null,
          ),
        );
      },
    ),
  );
}
