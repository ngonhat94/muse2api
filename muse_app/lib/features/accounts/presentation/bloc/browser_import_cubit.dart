import 'package:bloc/bloc.dart';

import '../../domain/repositories/browser_account_import.dart';
import '../../../connection/domain/entities/server_connection.dart';

class BrowserImportState {
  const BrowserImportState({
    this.busy = false,
    this.message,
    this.imported = false,
  });
  final bool busy;
  final String? message;
  final bool imported;
}

class BrowserImportCubit extends Cubit<BrowserImportState> {
  BrowserImportCubit(this.bridge) : super(const BrowserImportState());
  final BrowserAccountImport bridge;
  int _generation = 0;
  String? _id;
  void reset() {
    ++_generation;
    final id = _id;
    _id = null;
    if (id != null) bridge.cancel(id);
    if (!isClosed) emit(const BrowserImportState());
  }

  Future<void> run(ServerConnection connection, bool Function() current) async {
    if (state.busy || !current()) return;
    if (!bridge.supported) {
      emit(
        BrowserImportState(
          message: switch (bridge.capability) {
            BrowserImportCapability.unsupportedOrigin =>
              'Trang hiện tại chưa được extension cho phép. Nhập tự động chỉ hỗ trợ $approvedBrowserImportOriginsLabel. Các domain khác và preview không tự được tin cậy. Mở trang được hỗ trợ và đăng nhập lại; API key không được chuyển sang trang mới. Bạn vẫn có thể nhập cookie thủ công.',
            BrowserImportCapability.unsupportedDevice =>
              'Thiết bị di động chưa hỗ trợ cầu nối extension. Dùng Chrome/Edge trên máy tính tại $approvedBrowserImportOriginsLabel hoặc nhập cookie thủ công.',
            _ => 'Nhập từ trình duyệt chỉ hỗ trợ Chrome/Edge trên máy tính. Bạn vẫn có thể nhập cookie thủ công.',
          },
        ),
      );
      return;
    }
    final generation = ++_generation;
    bool valid() => !isClosed && generation == _generation && current();
    emit(const BrowserImportState(busy: true, message: 'Đang tìm extension…'));
    String? id;
    try {
      if (!await bridge.available()) {
        if (valid())
          emit(
            const BrowserImportState(
              message: 'Chưa tìm thấy extension 1.1.1. Cài hoặc tải lại extension, rồi tải lại trang. Chỉ hỗ trợ Chrome/Edge desktop trên domain được cho phép. Bạn vẫn có thể nhập cookie thủ công.',
            ),
          );
        return;
      }
      if (!valid()) return;
      id = await bridge.prepare();
      if (!valid()) {
        bridge.cancel(id);
        return;
      }
      _id = id;
      emit(
        const BrowserImportState(
          busy: true,
          message:
              'Xác nhận origin và server trong cửa sổ extension (90 giây).',
        ),
      );
      final approval = await bridge.approve(id, connection);
      if (!valid()) {
        bridge.cancel(id);
        return;
      }
      if (approval != 'approved') {
        emit(
          BrowserImportState(
            message: approval == 'invalid_destination'
                ? 'Server không nằm trong danh sách HTTPS được tin cậy của extension. Dùng nhập thủ công hoặc cấu hình lại allowlist.'
                : 'Đã hủy hoặc yêu cầu hết hạn. Không nhập tài khoản.',
          ),
        );
        return;
      }
      emit(
        const BrowserImportState(
          busy: true,
          message: 'Đang nhập trực tiếp vào server; không tự thử lại…',
        ),
      );
      final result = await bridge.commit(id, connection);
      if (!valid()) return;
      emit(
        BrowserImportState(
          imported: result == 'imported',
          message: switch (result) {
            'imported' => 'Đã nhập tài khoản. Danh sách đang được tải lại; không cần nhập lần nữa.',
            'no_session' => 'Chưa có phiên Muse. Đăng nhập muse.ai trong cùng hồ sơ trình duyệt rồi thử lại.',
            'unauthorized' =>
              'Server từ chối quyền nhập. Kiểm tra API key và kết nối lại.',
            _ => 'Chưa xác nhận được kết quả. Server có thể đã nhận; tải lại danh sách trước khi thử lại. Không tự gửi lại.',
          },
        ),
      );
    } catch (_) {
      if (valid())
        emit(
          const BrowserImportState(
            message: 'Không xác nhận được kết quả. Tải lại danh sách trước khi thử lại.',
          ),
        );
    } finally {
      if (id != null) bridge.cancel(id);
      if (generation == _generation) _id = null;
    }
  }

  @override
  Future<void> close() {
    reset();
    return super.close();
  }
}
