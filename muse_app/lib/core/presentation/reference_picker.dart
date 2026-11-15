import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/pick_reference_images.dart';
import '../domain/reference_image.dart';
import 'reference_cubit.dart';

class ReferencePicker extends StatelessWidget {
  const ReferencePicker({
    super.key,
    required this.onChanged,
    this.enabled = true,
    this.video = false,
    this.onLoadingChanged,
  });
  final ValueChanged<List<ReferenceImage>> onChanged;
  final bool enabled;
  final bool video;
  final ValueChanged<bool>? onLoadingChanged;
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => ReferenceCubit(context.read<PickReferenceImages>()),
    child: BlocConsumer<ReferenceCubit, ReferenceState>(
      listener: (_, state) {
        onChanged(state.images);
        onLoadingChanged?.call(state.loading);
      },
      builder: (context, state) {
        final blocked = !enabled || state.loading;
        final colors = Theme.of(context).colorScheme;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Ảnh tham chiếu',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(
                  '${state.images.length}/10',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              video
                  ? 'Ảnh đầu tiên làm khung hình chính. Có thể thay đổi thứ tự bên dưới.'
                  : 'Thêm ảnh để chỉnh sửa, kết hợp chủ thể hoặc tham khảo phong cách.',
              style: TextStyle(color: colors.onSurfaceVariant, height: 1.5),
            ),
            const SizedBox(height: 16),
            for (var index = 0; index < state.images.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        state.images[index].bytes,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        semanticLabel: 'Ảnh tham chiếu ${index + 1}',
                        cacheWidth: 160,
                        errorBuilder: (_, _, _) => const SizedBox(
                          width: 56,
                          height: 56,
                          child: Icon(Icons.image_not_supported_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.images[index].name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${index + 1}. ${(state.images[index].bytes.length / 1024 / 1024).toStringAsFixed(1)} MiB',
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      enabled: !blocked,
                      tooltip: 'Sắp xếp hoặc xóa ảnh ${index + 1}',
                      onSelected: (action) {
                        final cubit = context.read<ReferenceCubit>();
                        if (action == 'up') cubit.move(index, index - 1);
                        if (action == 'down') cubit.move(index, index + 1);
                        if (action == 'remove') cubit.remove(index);
                      },
                      itemBuilder: (_) => [
                        if (index > 0)
                          const PopupMenuItem(
                            value: 'up',
                            child: Text('Đưa lên trước'),
                          ),
                        if (index < state.images.length - 1)
                          const PopupMenuItem(
                            value: 'down',
                            child: Text('Đưa xuống sau'),
                          ),
                        const PopupMenuItem(
                          value: 'remove',
                          child: Text('Xóa ảnh'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            OutlinedButton.icon(
              onPressed: blocked || state.images.length >= 10
                  ? null
                  : () => context.read<ReferenceCubit>().pick(),
              icon: state.loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                state.loading ? 'Đang đọc ảnh…' : 'Thêm ảnh từ thiết bị',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'PNG, JPEG, WebP, GIF · tối đa 40 MiB/ảnh, 100 MiB tổng.',
              style: TextStyle(
                color: colors.onSurfaceVariant,
                fontSize: 12,
                height: 1.5,
              ),
            ),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    state.error!,
                    style: TextStyle(color: colors.error),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}
