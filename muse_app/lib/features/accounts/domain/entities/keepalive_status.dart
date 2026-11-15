class KeepaliveStatus {
  const KeepaliveStatus({
    this.running,
    this.lastRun,
    this.nextRun,
    this.lastResult,
  });
  final bool? running;
  final DateTime? lastRun;
  final DateTime? nextRun;
  final KeepaliveSummary? lastResult;
}

class KeepaliveSummary {
  const KeepaliveSummary({
    this.checkedAt,
    this.attempts,
    this.skipped,
    this.successes = 0,
    this.failures = 0,
    this.busy = 0,
    this.unknown,
  });
  final DateTime? checkedAt;
  final int? attempts;
  final int? skipped;
  final int successes;
  final int failures;
  final int busy;
  final int? unknown;
}
