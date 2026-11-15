import '../../domain/entities/account_import_draft.dart';
import '../../domain/repositories/batch_keepalive_repository.dart';
import '../../domain/entities/keepalive_status.dart';
import '../../domain/repositories/keepalive_status_repository.dart';
import '../../domain/repositories/account_cookies_repository.dart';
import '../../domain/entities/account_proxy.dart';
import '../../../../core/errors/app_failure.dart';
import '../../../../core/network/json_api_client.dart';
import '../../../connection/domain/entities/server_connection.dart';
import '../../domain/entities/muse_account.dart';
import '../../domain/repositories/account_repository.dart';

class AccountRepositoryImpl
    implements
        AccountRepository,
        AccountCookiesRepository,
        KeepaliveStatusRepository,
        BatchKeepaliveRepository {
  const AccountRepositoryImpl(this.api);
  final JsonApiClient api;

  @override
  Future<BatchKeepaliveResult> keepaliveAll(ServerConnection connection) async {
    Map<String, dynamic> json;
    try {
      json = await api.request(
        connection,
        '/admin/accounts/keepalive?force=true',
        method: 'POST',
        timeout: const Duration(minutes: 10),
      );
    } catch (_) {
      throw const AppFailure(
        'Chưa xác nhận được kết quả đợt duy trì phiên (có thể hết thời gian chờ). Server có thể vẫn đang chạy. Không tự thử lại; tải trạng thái trước khi quyết định.',
      );
    }
    if (json['status'] == 'busy') {
      return const BatchKeepaliveResult(busy: true);
    }
    if (json['status'] != null ||
        (json['refreshed'] is! List &&
            _statusCount(json['refreshed_count']) == null)) {
      throw const AppFailure(
        'Phản hồi đợt duy trì phiên không xác định. Không tự thử lại; tải trạng thái để kiểm tra.',
      );
    }
    return BatchKeepaliveResult(summary: _statusSummary(json));
  }

  @override
  Future<KeepaliveStatus> keepaliveStatus(ServerConnection connection) async {
    try {
      final json = await api.request(
        connection,
        '/admin/keepalive/status',
        method: 'GET',
      );
      return KeepaliveStatus(
        running: json['running'] is bool ? json['running'] as bool : null,
        lastRun: _statusDate(json['last_run']),
        nextRun: _statusDate(json['next_run']),
        lastResult: json['last_result'] is Map
            ? _statusSummary(json['last_result'] as Map)
            : null,
      );
    } catch (_) {
      throw const AppFailure(
        'Không tải được trạng thái duy trì phiên. Server có thể chưa hỗ trợ; hãy thử tải lại.',
      );
    }
  }

  static int? _statusCount(dynamic value) =>
      value is int && value >= 0 ? value : null;

  static KeepaliveSummary _statusSummary(Map json) {
    final entries = json['refreshed'] is List
        ? json['refreshed'] as List
        : null;
    var successes = 0;
    var failures = 0;
    var busy = 0;
    for (final entry in entries ?? []) {
      if (entry is! Map) continue;
      if (entry['ok'] == true && entry['busy'] != true) successes++;
      if (entry['ok'] == false) {
        failures++;
        if (entry['busy'] == true) busy++;
      }
    }
    final reported = _statusCount(json['refreshed_count']);
    // Count missing entries as unknown; never turn a reported attempt into success.
    final attempts = entries == null
        ? reported
        : (reported != null && reported > entries.length
              ? reported
              : entries.length);
    return KeepaliveSummary(
      checkedAt: _statusDate(json['checked_at']),
      attempts: attempts,
      skipped:
          _statusCount(json['skipped_count']) ??
          (json['skipped'] is List ? (json['skipped'] as List).length : null),
      successes: successes,
      failures: failures,
      busy: busy,
      unknown: attempts == null ? null : attempts - successes - failures,
    );
  }

  static DateTime? _statusDate(dynamic value) {
    if (value is! num ||
        !value.isFinite ||
        value <= 0 ||
        value > 8640000000000) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch((value * 1000).toInt());
  }

  @override
  Future<List<MuseAccount>> list(ServerConnection connection) async {
    final json = await api.request(connection, '/admin/accounts');
    return (json['accounts'] as List).map((item) {
      final e = item as Map<String, dynamic>;
      final proxy = e['proxy'];
      final q = e['quota'] is Map ? e['quota'] as Map : <String, dynamic>{};
      String? text(dynamic value) =>
          value is String && value.trim().isNotEmpty ? value : null;
      return MuseAccount(
        id: e['id'] as String,
        label: e['label'] as String? ?? e['id'] as String,
        enabled: e['enabled'] != false,
        healthy: e['ok'] as bool?,
        expiresAt: _statusDate(e['expires_at']),
        plan: text(q['plan']),
        weeklyUsed: MuseAccount.validPercentage(q['weekly_used_pct']),
        quotaCheckedAt: _statusDate(q['checked_at']),
        weeklyReset: text(q['weekly_reset']),
        extraUsed: MuseAccount.validPercentage(q['extra_used_pct']),
        extraLeft: text(q['extra_left']),
        extraExpires: text(q['extra_expires']),
        proxy: proxy is Map && proxy['server'] is String
            ? SavedAccountProxy(
                server: proxy['server'] as String,
                username: proxy['username'] as String? ?? '',
                hasPassword: proxy['has_password'] == true,
              )
            : null,
      );
    }).toList();
  }

  @override
  Future<String> import(
    ServerConnection connection,
    String label,
    String cookieHeader,
  ) async {
    final draft = AccountImportDraft.parse(label, cookieHeader);
    final json = await api.request(
      connection,
      '/admin/accounts',
      method: 'POST',
      body: draft.isBatch
          ? {'batch': draft.text}
          : {'label': draft.label, 'cookie_header': draft.text},
    );
    final count = json['count'];
    final added = json['added'];
    if (count is! int ||
        count != draft.accountCount ||
        (json.containsKey('added') &&
            (added is! List ||
                added.length != count ||
                added.any(
                  (item) =>
                      item is! Map ||
                      item['id'] is! String ||
                      (item['id'] as String).isEmpty,
                )))) {
      throw const AppFailure(
        'Chưa xác nhận đủ số tài khoản đã nhập. Server có thể đã nhận yêu cầu; tải lại danh sách trước khi thử lại.',
      );
    }
    final missing = json['essential_missing'];
    return missing is List && missing.isNotEmpty
        ? 'Đã nhập $count tài khoản, nhưng còn thiếu cookie phiên bắt buộc. Hãy kiểm tra lại tài khoản.'
        : 'Đã nhập $count tài khoản.';
  }

  @override
  Future<String> updateCookies(
    ServerConnection connection,
    String id,
    String cookieHeader,
  ) async {
    if (id.trim().isEmpty || cookieHeader.trim().isEmpty) {
      throw const AppFailure('Nhập cookie mới và chọn tài khoản cần cập nhật.');
    }
    final json = await api.request(
      connection,
      '/admin/accounts/${Uri.encodeComponent(id)}/cookies',
      method: 'POST',
      body: {'cookie_header': cookieHeader.trim()},
    );
    if (json['ok'] != true ||
        json['id'] != id ||
        json['cookie_count'] is! int ||
        (json['cookie_count'] as int) <= 0) {
      throw const AppFailure(
        'Chưa xác nhận được cập nhật cookie. Tải lại tài khoản trước khi thử lại.',
      );
    }
    return 'Đã cập nhật cookie. Phiên Muse chưa được xác nhận; hãy kiểm tra phiên.';
  }

  @override
  Future<String> act(
    ServerConnection connection,
    String id,
    AccountAction action,
  ) async {
    final path = '/admin/accounts/${Uri.encodeComponent(id)}';
    switch (action) {
      case AccountAction.enable:
      case AccountAction.disable:
        await api.request(
          connection,
          path,
          method: 'PATCH',
          body: {'enabled': action == AccountAction.enable},
        );
        return 'Đã cập nhật tài khoản.';
      case AccountAction.remove:
        await api.request(connection, path, method: 'DELETE');
        return 'Đã xóa tài khoản khỏi server.';
      case AccountAction.test:
        final json = await api.request(
          connection,
          '$path/test',
          method: 'POST',
          timeout: const Duration(seconds: 150),
        );
        if (json['ok'] != true) {
          throw const AppFailure(
            'Chưa xác nhận được phiên Muse. Kiểm tra tài khoản trên server.',
          );
        }
        return json['quota_error'] != null
            ? 'Phiên hợp lệ; chưa cập nhật được quota.'
            : 'Phiên hợp lệ, đã cập nhật quota.';
      case AccountAction.keepalive:
        final json = await api.request(
          connection,
          '$path/keepalive',
          method: 'POST',
          timeout: const Duration(seconds: 150),
        );
        if (json['id'] != id || json['ok'] != true) {
          throw AppFailure(
            json['id'] == id && json['busy'] == true
                ? 'Tài khoản đang bận. Chưa duy trì phiên; tải lại trước khi thử lại.'
                : 'Chưa xác nhận được duy trì phiên. Kiểm tra trạng thái tài khoản trước khi thử lại.',
          );
        }
        return json['wake_ok'] == true
            ? 'Đã duy trì phiên; đã xác nhận đánh thức workspace. Quota vẫn là dữ liệu lưu đệm.'
            : 'Đã duy trì phiên; chưa xác nhận đánh thức workspace. Quota vẫn là dữ liệu lưu đệm.';
      case AccountAction.quota:
        try {
          final json = await api.request(
            connection,
            '$path/quota',
            method: 'POST',
            timeout: const Duration(seconds: 150),
          );
          if (json['found'] != true ||
              MuseAccount.validPercentage(json['weekly_used_pct']) == null ||
              _statusDate(json['checked_at']) == null) {
            throw const AppFailure('Quota chưa được xác nhận.');
          }
        } catch (_) {
          throw const AppFailure(
            'Chưa xác nhận được cập nhật quota. Dữ liệu lưu đệm không thay đổi; tải lại danh sách trước khi thử lại.',
          );
        }
        return 'Đã cập nhật quota.';
    }
  }
}
