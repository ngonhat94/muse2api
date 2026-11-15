/// A deliberately allowlisted snapshot; no accounts, tasks or configuration retained.
class ServerStatus {
  const ServerStatus({
    this.browserRunning,
    this.mediaCount,
    this.totalAccounts,
    this.enabledAccounts,
    this.disabledAccounts,
    this.healthyAccounts,
    this.errorAccounts,
    this.expiringAccounts,
    this.expiredAccounts,
  });
  final bool? browserRunning;
  final int? mediaCount;
  final int? totalAccounts;
  final int? enabledAccounts;
  final int? disabledAccounts;
  final int? healthyAccounts;
  final int? errorAccounts;
  final int? expiringAccounts;
  final int? expiredAccounts;
}
