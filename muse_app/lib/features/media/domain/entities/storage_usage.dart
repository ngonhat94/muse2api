class StorageUsage {
  const StorageUsage({
    required this.bytes,
    required this.files,
    required this.limitBytes,
    required this.limitFiles,
    required this.retentionDays,
  });
  final int bytes;
  final int files;
  final int limitBytes;
  final int limitFiles;
  final int retentionDays;
}
