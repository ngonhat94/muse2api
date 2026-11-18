import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Help only: opening this tab never reads cookies or starts an import.
class GetCookiesGuide extends StatelessWidget {
  const GetCookiesGuide({super.key, required this.onManualImport});

  final VoidCallback? onManualImport;
  static final sourceUri = Uri.parse(
    'https://github.com/ngonhat94/murouter/tree/main/extension',
  );

  Future<void> _openSource(BuildContext context) async {
    try {
      if (await launchUrl(sourceUri, mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {
      // Show a fixed message, never a raw platform error.
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không mở được nguồn extension. Hãy nhờ quản trị viên gửi bản 1.1.0.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nhập phiên Muse an toàn',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Dùng Chrome hoặc Edge trên máy tính. Bạn cần tài khoản Muse của mình đã đăng nhập; hướng dẫn này không tự đăng ký tài khoản Muse.',
          ),
          const SizedBox(height: 24),
          const _GuideStep(
            title: '1. Lấy extension 1.1.0',
            body: 'Nhờ quản trị viên gửi muse2api-extension.zip bản 1.1.0 từ chức năng tải extension của hệ thống. Giải nén vào thư mục cố định. Nếu có quyền truy cập kho mã riêng, bạn cũng có thể lấy thư mục extension/ từ nguồn bên dưới. Không dùng bản 1.0.2 hoặc gói không rõ nguồn.',
          ),
          OutlinedButton.icon(
            onPressed: () => _openSource(context),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Nguồn extension (cần quyền GitHub)'),
          ),
          const SizedBox(height: 16),
          const _GuideStep(
            title: '2. Cài vào Chrome / Edge',
            body: 'Dán chrome://extensions hoặc edge://extensions vào thanh địa chỉ. Bật Developer mode (Chế độ nhà phát triển) → Load unpacked (Tải tiện ích đã giải nén) → chọn thư mục chứa manifest.json, thường là muse2api-extension. Khi cập nhật, thay các tệp trong thư mục cũ rồi bấm Reload (Tải lại) tại extension. Tải lại cả trang Muse Studio.',
          ),
          const _GuideStep(
            title: '3. Đăng nhập Muse',
            body: 'Mở https://muse.ai và đăng nhập tài khoản của bạn trong cùng hồ sơ trình duyệt (browser profile) đã cài extension và mở Muse Studio. Không dùng cửa sổ ẩn danh hoặc hồ sơ khác.',
          ),
          const _GuideStep(
            title: '4. Nhập và xác nhận một lần',
            body: 'Quay lại tab Danh sách → bấm “Nhập tài khoản từ trình duyệt”. Cửa sổ riêng của extension sẽ yêu cầu bạn kiểm tra địa chỉ trang yêu cầu và nơi nhận trước khi chọn “Cho phép nhập một lần” trong 90 giây. Chỉ duyệt khi nhận ra cả hai địa chỉ; nếu không chắc hãy hủy. Mở Get Cookies không tự nhập hay đọc cookie.',
          ),
          const _GuideStep(
            title: '5. Kiểm tra danh sách',
            body: 'Khi thành công, danh sách tài khoản tự tải lại. Tài khoản nhập vào gắn với người dùng đang đăng nhập Muse Studio. Việc nhập không bảo đảm phiên còn hợp lệ và không tự cập nhật quota. Nếu mất kết nối hoặc hết thời gian chờ, tải lại danh sách trước khi thử lại để tránh nhập trùng.',
          ),
          const Divider(height: 32),
          Text(
            'Bảo vệ phiên đăng nhập',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Extension cần quyền cookie của Muse để nhập phiên và gửi trực tiếp tới hệ thống sau khi bạn duyệt; cookie không trả về trang Muse Studio qua cầu nối. Không cần dán cookie hoặc API key vào extension cho luồng này. Cookie tương đương quyền truy cập tài khoản: không gửi vào chat công khai, ảnh chụp màn hình hoặc gói hỗ trợ.',
          ),
          const SizedBox(height: 24),
          Text(
            'Nếu chưa nhập được',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            '• Không thấy nút nhập / không tìm thấy extension: kiểm tra Chrome/Edge desktop, bản 1.1.0, bật extension và tải lại trang. Cài riêng cho từng browser profile.\n\n• Trang web chưa được hỗ trợ: cầu nối hiện chỉ hỗ trợ https://muapp-3d6.pages.dev. Domain riêng và đường dẫn preview không tự được tin cậy; nhờ quản trị viên hỗ trợ, không tắt bảo vệ hay tự cấp quyền cho trang lạ.\n\n• Không có phiên Muse: đăng nhập lại muse.ai trong cùng hồ sơ rồi nhập lại.\n\n• Đã hủy / hết hạn duyệt: chỉ bấm nhập lại khi sẵn sàng xác nhận. Nếu báo kết quả chưa rõ, làm mới danh sách trước.\n\n• Điện thoại, Safari, Firefox hoặc ứng dụng desktop native: không có cầu nối này. Có thể lấy cookie của chính bạn qua extension trên máy tính rồi dùng form nhập thủ công bên dưới trên thiết bị tin cậy. Chỉ dán vào trường Cookie string, kiểm tra nơi lưu và xóa nội dung clipboard sau khi dùng.',
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onManualImport,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Mở form nhập thủ công'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    ),
  );
}

class _GuideStep extends StatelessWidget {
  const _GuideStep({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: 8),
        Text(body),
      ],
    ),
  );
}
