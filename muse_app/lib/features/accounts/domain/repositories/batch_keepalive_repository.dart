import '../../../connection/domain/entities/server_connection.dart';
import '../entities/keepalive_status.dart';

class BatchKeepaliveResult {
  const BatchKeepaliveResult({this.busy = false, this.summary});
  final bool busy;
  final KeepaliveSummary? summary;
  String get message {
    if (busy) {
      return 'Server đang bận. Đợt này chưa được thực hiện; không tự thử lại.';
    }
    final s = summary!;
    String count(int? n) => n?.toString() ?? 'chưa rõ';
    return '${count(s.attempts)} lượt thử · ${count(s.skipped)} bỏ qua\n'
        '${s.successes} thành công · ${s.failures} thất bại (trong đó ${s.busy} bận) · ${count(s.unknown)} chưa xác định\n'
        'Lượt thử không đồng nghĩa thành công. Không bảo đảm kéo dài phiên. Quota vẫn là dữ liệu lưu đệm.';
  }
}

abstract interface class BatchKeepaliveRepository {
  Future<BatchKeepaliveResult> keepaliveAll(ServerConnection connection);
}
