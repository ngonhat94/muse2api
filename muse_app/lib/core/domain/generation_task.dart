enum GenerationStatus { queued, processing, completed, failed }

class GenerationTask {
  const GenerationTask({
    required this.id,
    required this.kind,
    required this.status,
    this.prompt = '',
    this.progress = 0,
    this.createdAt,
    this.filename,
    this.protectedUri,
  });
  final String id;
  final String kind;
  final String prompt;
  final GenerationStatus status;
  final double progress;
  final DateTime? createdAt;
  final String? filename;
  final Uri? protectedUri;
  bool get terminal =>
      status == GenerationStatus.completed || status == GenerationStatus.failed;
}
