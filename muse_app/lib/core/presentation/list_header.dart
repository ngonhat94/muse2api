import 'package:flutter/material.dart';

class ListHeader extends StatelessWidget {
  const ListHeader({
    super.key,
    required this.title,
    required this.loading,
    required this.onRefresh,
    this.error,
  });
  final String title;
  final bool loading;
  final VoidCallback? onRefresh;
  final String? error;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'Làm mới',
            onPressed: loading ? null : onRefresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      if (loading) const LinearProgressIndicator(),
      if (error != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
    ],
  );
}

String formatDate(DateTime? date) {
  if (date == null) return '—';
  final d = date.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
}
