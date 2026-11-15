import 'account_proxy.dart';

class MuseAccount {
  const MuseAccount({
    required this.id,
    required this.label,
    required this.enabled,
    this.healthy,
    this.expiresAt,
    this.plan,
    this.weeklyUsed,
    this.quotaCheckedAt,
    this.weeklyReset,
    this.extraUsed,
    this.extraLeft,
    this.extraExpires,
    this.proxy,
  });
  final String id;
  final String label;
  final bool enabled;
  final bool? healthy;
  final DateTime? expiresAt;
  final String? plan;
  final double? weeklyUsed;
  final DateTime? quotaCheckedAt;
  final String? weeklyReset;
  final double? extraUsed;

  /// Upstream display text, not an absolute numeric token allowance.
  final String? extraLeft;
  final String? extraExpires;
  static double? validPercentage(Object? value) =>
      value is num && value.isFinite && value >= 0 && value <= 100
      ? value.toDouble()
      : null;
  double? get weeklyRemaining => _remaining(weeklyUsed);
  double? get extraRemaining => _remaining(extraUsed);
  static double? _remaining(double? value) {
    final used = validPercentage(value);
    return used == null ? null : 100 - used;
  }

  final SavedAccountProxy? proxy;
}
