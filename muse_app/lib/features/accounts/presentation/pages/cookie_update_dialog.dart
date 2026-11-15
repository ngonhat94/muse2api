import 'package:flutter/material.dart';

/// Replacement credentials live only for this dialog and the outgoing request.
class CookieUpdateDialog extends StatefulWidget {
  const CookieUpdateDialog({
    super.key,
    required this.isCurrent,
    required this.onSubmit,
  });
  final bool Function() isCurrent;
  final ValueChanged<String> onSubmit;
  @override
  State<CookieUpdateDialog> createState() => _CookieUpdateDialogState();
}

class _CookieUpdateDialogState extends State<CookieUpdateDialog> {
  final _cookies = TextEditingController();
  bool _submitted = false;
  String? _error;
  @override
  void dispose() {
    _cookies.clear();
    _cookies.dispose();
    super.dispose();
  }

  void _submit() {
    if (_submitted) return;
    if (!widget.isCurrent()) {
      _cookies.clear();
      Navigator.pop(context);
      return;
    }
    final value = _cookies.text.trim();
    if (value.isEmpty) {
      setState(() => _error = 'Nhập cookie mới để tiếp tục.');
      return;
    }
    _submitted = true;
    _cookies.clear();
    widget.onSubmit(value);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Cập nhật cookie'),
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cookie mới sẽ thay thế toàn bộ cookie của tài khoản trên server. Thao tác này đặt lại trạng thái phiên và ước tính hạn dùng; không xác nhận phiên Muse hợp lệ.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _cookies,
            autofocus: true,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            enableIMEPersonalizedLearning: false,
            autofillHints: const [],
            keyboardType: TextInputType.visiblePassword,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Cookie header mới',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Chỉ gửi tới server đang kết nối. Không lưu cookie trên thiết bị; nội dung sẽ được xóa khi gửi hoặc đóng hộp thoại.',
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () {
          _cookies.clear();
          Navigator.pop(context);
        },
        child: const Text('Hủy'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Cập nhật cookie')),
    ],
  );
}
