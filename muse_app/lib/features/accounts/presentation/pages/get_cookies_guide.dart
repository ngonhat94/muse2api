import 'package:flutter/material.dart';

/// Passive help; downloads and imports require explicit user actions.
class GetCookiesGuide extends StatelessWidget {
  const GetCookiesGuide({
    super.key,
    required this.onManualImport,
    this.download,
  });
  final VoidCallback? onManualImport;
  final Widget? download;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topLeft,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 960),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Panel(
            title: 'Cập nhật thủ công · Extension 1.1.0',
            icon: Icons.system_update_alt,
            highlighted: true,
            children: [
              Text(
                'Đã cài bản cũ? Tải ZIP mới, thay các tệp trong thư mục cũ → Reload tại chrome://extensions → tải lại Muse Studio.',
              ),
            ],
          ),
          Text(
            'Nhập phiên Muse an toàn',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Vì sao cần extension? Cookie phiên Muse có HttpOnly: JavaScript trên trang web không đọc được. Extension dùng quyền cookie của trình duyệt để đọc phiên của chính bạn sau khi bạn cho phép.',
          ),
          const SizedBox(height: 16),
          const _Panel(
            title: 'Khuyên dùng: Extension trình duyệt',
            icon: Icons.verified_user_outlined,
            highlighted: true,
            children: [
              Text(
                'Chrome / Edge trên máy tính · Không cần Python hay dòng lệnh. Không cần dán API key hoặc cookie vào extension khi dùng nhập tự động. Mở Get Cookies không tự đọc cookie hoặc nhập tài khoản.',
              ),
            ],
          ),
          _Panel(
            title: '1. Tải ZIP và giải nén',
            icon: Icons.download_outlined,
            children: [
              const Text(
                'Tải muse2api-extension.zip từ máy chủ đang kết nối bằng phiên Muse Studio hiện tại. Sau khi ZIP sẵn sàng, bấm Lưu rồi giải nén vào một thư mục cố định.',
              ),
              const SizedBox(height: 12),
              ?download,
            ],
          ),
          const _Panel(
            title: '2. Cài vào Chrome / Edge',
            icon: Icons.extension_outlined,
            children: [
              Text(
                'Dán chrome://extensions (hoặc edge://extensions) vào thanh địa chỉ. Bật Developer mode (Chế độ nhà phát triển) → Load unpacked (Tải tiện ích đã giải nén) → chọn thư mục muse2api-extension chứa manifest.json. Khi cập nhật, bấm Reload rồi tải lại Muse Studio.',
              ),
              SizedBox(height: 8),
              SelectableText('chrome://extensions'),
            ],
          ),
          const _Panel(
            title: '3. Đăng nhập Muse → đọc và nhập phiên',
            icon: Icons.login,
            children: [
              SelectableText('https://muse.ai'),
              SizedBox(height: 8),
              Text(
                'Đăng nhập tài khoản Muse của bạn trong cùng hồ sơ Chrome/Edge đã cài extension và mở Muse Studio, không dùng ẩn danh. Quay lại Danh sách → “Nhập tài khoản từ trình duyệt”. Extension 1.1.0 mở cửa sổ xác nhận: kiểm tra trang yêu cầu và nơi nhận, rồi chọn “Cho phép nhập một lần” trong 90 giây. Nếu không nhận ra địa chỉ, hãy hủy.',
              ),
              SizedBox(height: 8),
              Text(
                'Sau khi nhập thành công, danh sách tự tải lại; tài khoản thuộc người dùng Muse Studio hiện tại. Nhập không bảo đảm phiên còn hợp lệ hoặc tự cập nhật quota. Nếu kết quả chưa rõ, tải lại danh sách trước khi thử lại để tránh nhập trùng.',
              ),
            ],
          ),
          const _Panel(
            title: 'Bảo vệ phiên đăng nhập & xử lý sự cố',
            icon: Icons.lock_outline,
            children: [
              Text(
                'Cookie tương đương quyền truy cập tài khoản: không gửi vào chat, ảnh chụp hoặc gói hỗ trợ. Luồng tự động gửi cookie trực tiếp từ extension đến máy chủ sau khi bạn duyệt, không trả cookie về trang web.\n\nKhông thấy extension? Kiểm tra bản 1.1.0, bật extension và tải lại trang trong cùng browser profile. Cầu nối hiện chỉ hỗ trợ https://muapp-3d6.pages.dev; domain riêng và preview không tự được tin cậy. Không tắt bảo vệ để cấp quyền cho trang lạ.\n\nKhông có phiên Muse? Đăng nhập lại muse.ai. Đã hủy/hết hạn? Chỉ nhập lại khi sẵn sàng xác nhận. Điện thoại, Safari, Firefox và ứng dụng native không có cầu nối này.',
              ),
            ],
          ),
          _Panel(
            title: 'Tùy chọn: nhập thủ công',
            icon: Icons.edit_outlined,
            children: [
              const Text(
                'Nếu không dùng được nhập tự động, lấy cookie của chính bạn bằng extension trên máy tính tin cậy rồi dán vào trường Cookie string trong form. Kiểm tra nơi lưu và xóa clipboard sau khi dùng. Đây là tùy chọn riêng, không phải bước bắt buộc của luồng tự động.',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onManualImport,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Mở form nhập thủ công'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.icon,
    required this.children,
    this.highlighted = false,
  });
  final String title;
  final IconData icon;
  final List<Widget> children;
  final bool highlighted;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: highlighted
            ? colors.primaryContainer.withValues(alpha: .25)
            : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlighted
              ? colors.primary.withValues(alpha: .5)
              : colors.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
