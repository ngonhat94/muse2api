import 'dart:convert';

import '../errors/app_failure.dart';

AppFailure apiError(int status, String body) {
  if (status == 401) {
    return const AppFailure(
      'API key không hợp lệ hoặc đã bị thu hồi. Kiểm tra và nhập lại key, hoặc liên hệ quản trị viên để cấp key mới.',
    );
  }
  if (status == 403) {
    return const AppFailure(
      'API key không có quyền thực hiện yêu cầu này. Liên hệ quản trị viên để kiểm tra quyền truy cập.',
    );
  }
  if (status == 409) {
    return const AppFailure(
      'Tài khoản đang bận hoặc cấu hình xung đột. Chờ tác vụ hoàn tất rồi thử lại.',
    );
  }
  if (status == 429) {
    return const AppFailure(
      'Đã chạm giới hạn yêu cầu. Vui lòng chờ; kiểm tra tác vụ trước khi gửi lại để tránh tạo trùng.',
    );
  }
  if (status == 507) {
    return const AppFailure(
      'Đã đầy hạn mức lưu trữ trên server, không phải số dư Muse. Xóa media của bạn hoặc liên hệ quản trị viên; không tự động gửi lại tác vụ.',
    );
  }
  // Do not surface arbitrary upstream bodies: they may contain credentials.
  try {
    final json = jsonDecode(body);
    if (json is Map) {
      final error = json['error'];
      final detail =
          json['detail'] ?? (error is Map ? error['message'] : error);
      if (detail is String && detail.startsWith('提示词没有发出去（')) {
        return const AppFailure(
          'Yêu cầu chưa được gửi tới Muse. Kiểm tra trạng thái tác vụ trước khi thử lại để tránh gửi trùng.',
        );
      }
    }
    if (json is Map &&
        (json.containsKey('error') || json.containsKey('detail'))) {
      return AppFailure(
        'Server từ chối yêu cầu (HTTP $status). Kiểm tra tài khoản Muse trên trang quản trị.',
      );
    }
  } on FormatException {
    /* Non-JSON proxy response. */
  }
  return AppFailure('Không thể hoàn tất yêu cầu (HTTP $status).');
}
