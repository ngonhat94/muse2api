class MediaItem {
  const MediaItem({
    required this.name,
    required this.isVideo,
    required this.bytes,
    this.createdAt,
    this.protectedUri,
  });
  final String name;
  final bool isVideo;
  final int bytes;
  final DateTime? createdAt;
  final Uri? protectedUri;
}
