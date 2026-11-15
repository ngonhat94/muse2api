import '../../../../core/errors/app_failure.dart';

/// Only these fixed, non-sensitive desktop failures may reach the interface.
/// Arbitrary process output, exception text and backend payloads stay private.
enum DesktopEngineFailureCode {
  missingEngine,
  missingBrowser,
  alreadyRunning,
  storageDenied,
  launchDenied,
  startupTimeout,
  startupFailed,
  pythonMissing,
  setupMissing,
  installBusy,
  downloadFailed,
  installFailed,
  installCancelled,
}

class DesktopEngineFailure extends AppFailure {
  const DesktopEngineFailure(this.code) : super('');
  final DesktopEngineFailureCode code;
  @override
  String get message => switch (code) {
    DesktopEngineFailureCode.missingEngine => 'Bản cài này chưa có engine desktop. Chọn Cài đặt engine để chuẩn bị, hoặc dùng bản desktop được đóng gói đầy đủ.',
    DesktopEngineFailureCode.missingBrowser =>
      'Bản cài thiếu trình duyệt đi kèm. Hãy cài lại bản desktop đầy đủ.',
    DesktopEngineFailureCode.alreadyRunning => 'Muse đang chạy trong một cửa sổ khác. Đóng phiên đó rồi khởi động lại tại đây.',
    DesktopEngineFailureCode.storageDenied => 'Engine không ghi được dữ liệu ứng dụng. Kiểm tra quyền ghi của tài khoản đang dùng rồi thử lại.',
    DesktopEngineFailureCode.launchDenied => 'Hệ điều hành không cho chạy engine. Kiểm tra quyền thực thi hoặc dùng lại bản cài desktop đầy đủ.',
    DesktopEngineFailureCode.startupTimeout => 'Engine khởi động quá thời gian chờ. Đóng các phiên Muse khác rồi thử lại.',
    DesktopEngineFailureCode.startupFailed => 'Không khởi động được engine trên máy này. Kiểm tra bản cài đầy đủ và quyền ghi dữ liệu rồi thử lại.',
    DesktopEngineFailureCode.pythonMissing => 'Cần Python 3.11 trở lên để cài engine từ ứng dụng. Hãy cài Python rồi thử lại, hoặc dùng bản desktop đã kèm engine.',
    DesktopEngineFailureCode.setupMissing => 'Bản app này thiếu bộ cài engine. Hãy mở app từ project đầy đủ hoặc dùng bản desktop mới có kèm bộ cài.',
    DesktopEngineFailureCode.installBusy =>
      'Một đợt cài đặt engine khác đang chạy. Chờ hoàn tất rồi thử lại.',
    DesktopEngineFailureCode.downloadFailed => 'Không tải hoặc cài được thành phần cần thiết. Kiểm tra Internet và phiên bản Python rồi thử lại.',
    DesktopEngineFailureCode.installFailed => 'Cài engine chưa thành công. Kiểm tra dung lượng trống và quyền ghi rồi thử cài lại.',
    DesktopEngineFailureCode.installCancelled =>
      'Đã hủy cài đặt engine. Bạn có thể cài lại khi sẵn sàng.',
  };

  static DesktopEngineFailure fromProtocol(Object? code) =>
      DesktopEngineFailure(switch (code) {
        'browser_missing' => DesktopEngineFailureCode.missingBrowser,
        'engine_in_use' => DesktopEngineFailureCode.alreadyRunning,
        'storage_denied' => DesktopEngineFailureCode.storageDenied,
        _ => DesktopEngineFailureCode.startupFailed,
      });

  static DesktopEngineFailure fromInstallProtocol(Object? code) =>
      DesktopEngineFailure(switch (code) {
        'python_missing' => DesktopEngineFailureCode.pythonMissing,
        'setup_missing' => DesktopEngineFailureCode.setupMissing,
        'install_busy' => DesktopEngineFailureCode.installBusy,
        'storage_denied' => DesktopEngineFailureCode.storageDenied,
        'download_failed' => DesktopEngineFailureCode.downloadFailed,
        'cancelled' => DesktopEngineFailureCode.installCancelled,
        _ => DesktopEngineFailureCode.installFailed,
      });
}
