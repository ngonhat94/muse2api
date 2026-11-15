import '../errors/app_failure.dart';

/// Only numeric native status codes are exposed; never exception messages/data.
AppFailure storageFailure({int? status, bool missingPlugin = false}) {
  if (missingPlugin) {
    return const AppFailure(
      'Plugin lưu trữ chưa được nạp. Dừng app hoàn toàn, chạy flutter pub get rồi flutter run lại.',
    );
  }
  if (status == -34018) {
    return const AppFailure(
      'Keychain thiếu entitlement (-34018). Build lại app; nếu còn lỗi, kiểm tra Signing & Capabilities → Keychain Sharing trong Xcode.',
    );
  }
  if (status != null) {
    return AppFailure(
      'Không truy cập được Keychain (mã $status). Kiểm tra Keychain và cấu hình ký ứng dụng rồi thử lại.',
    );
  }
  return const AppFailure(
    'Không truy cập được bộ lưu trữ của thiết bị. Dừng app và chạy lại đầy đủ rồi thử lưu lại.',
  );
}
