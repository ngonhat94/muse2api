import 'package:flutter/material.dart';

class GenerationWorkspace extends StatelessWidget {
  const GenerationWorkspace({
    super.key,
    required this.title,
    required this.description,
    required this.form,
    required this.preview,
  });
  final String title;
  final String description;
  final Widget form;
  final Widget preview;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 1050;
      final padding = constraints.maxWidth < 600 ? 20.0 : 32.0;
      return SingleChildScrollView(
        padding: EdgeInsets.all(padding),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1320),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 360, child: form),
                      const SizedBox(width: 40),
                      Expanded(child: preview),
                    ],
                  )
                else ...[
                  form,
                  const SizedBox(height: 32),
                  preview,
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

class GenerationPreview extends StatelessWidget {
  const GenerationPreview({
    super.key,
    required this.video,
    required this.busy,
    this.status,
    this.child,
  });
  final bool video;
  final bool busy;
  final String? status;
  final Widget? child;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (child != null) return child!;
    // Keep the media-shaped empty state when there is room, but let status
    // text and progress grow naturally on narrow screens and at large text sizes.
    return LayoutBuilder(
      builder: (context, constraints) => ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: constraints.maxWidth,
          minHeight: constraints.maxWidth / (video ? 16 / 9 : 1),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  video ? Icons.movie_outlined : Icons.image_outlined,
                  size: 36,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(height: 20),
                Semantics(
                  liveRegion: busy,
                  child: Text(
                    status ??
                        (video
                            ? 'Video của bạn sẽ xuất hiện ở đây'
                            : 'Ảnh của bạn sẽ xuất hiện ở đây'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ),
                if (busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: SizedBox(
                      width: 180,
                      child: LinearProgressIndicator(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
