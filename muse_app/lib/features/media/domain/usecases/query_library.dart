import '../entities/media_item.dart';

enum LibraryType { all, images, videos }

List<MediaItem> queryLibrary(
  List<MediaItem> items, {
  LibraryType type = LibraryType.all,
  String search = '',
  bool newest = true,
}) {
  final needle = search.trim().toLowerCase();
  final indexed = items.indexed.where((entry) {
    final item = entry.$2;
    return (type == LibraryType.all ||
            (type == LibraryType.videos) == item.isVideo) &&
        item.name.toLowerCase().contains(needle);
  }).toList();
  if (newest) {
    indexed.sort((a, b) {
      final first = a.$2.createdAt;
      final second = b.$2.createdAt;
      final order = first == null
          ? (second == null ? 0 : 1)
          : second == null
          ? -1
          : second.compareTo(first);
      return order == 0 ? a.$1.compareTo(b.$1) : order;
    });
  }
  return indexed.map((entry) => entry.$2).toList();
}
