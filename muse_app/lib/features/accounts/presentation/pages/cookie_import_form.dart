import 'package:flutter/material.dart';

import '../../../../core/errors/app_failure.dart';
import '../../domain/entities/account_import_draft.dart';

class CookieImportForm extends StatefulWidget {
  const CookieImportForm({
    super.key,
    required this.busy,
    required this.onSubmit,
    this.localMode = false,
  });
  final bool busy;
  final bool localMode;
  final void Function(String label, String cookies) onSubmit;
  @override
  State<CookieImportForm> createState() => _CookieImportFormState();
}

class _CookieImportFormState extends State<CookieImportForm> {
  final _form = GlobalKey<FormState>();
  final _label = TextEditingController();
  final _cookies = TextEditingController();
  final _focus = FocusNode();
  bool _hidden = false;
  AccountImportDraft? get _draft {
    try {
      return AccountImportDraft.parse(_label.text, _cookies.text);
    } on AppFailure {
      return null;
    }
  }

  @override
  void dispose() {
    _cookies.clear();
    _label.clear();
    _cookies.dispose();
    _label.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    final batch = draft?.isBatch == true;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _label,
            enabled: !widget.busy && !batch,
            decoration: InputDecoration(
              labelText: 'Tên tài khoản (không bắt buộc)',
              helperMaxLines: 2,
              helperText: batch
                  ? 'Tên tài khoản được lấy từ đầu từng dòng.'
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _cookies,
            focusNode: _focus,
            enabled: !widget.busy,
            obscureText: _hidden,
            minLines: _hidden ? 1 : 4,
            maxLines: _hidden ? 1 : 8,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: _hidden
                ? TextInputType.visiblePassword
                : TextInputType.multiline,
            textInputAction: _hidden
                ? TextInputAction.done
                : TextInputAction.newline,
            onChanged: (_) => setState(() {}),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: (value) {
              try {
                AccountImportDraft.parse(_label.text, value ?? '');
                return null;
              } on AppFailure catch (error) {
                return error.message;
              }
            },
            decoration: InputDecoration(
              labelText: 'Cookie string',
              alignLabelWithHint: true,
              errorMaxLines: 3,
              hintText: 'hatch_sess=...; hatch_vml=...\n\nacc-01 | hatch_sess=...; hatch_vml=...\nacc-02 | hatch_sess=...; hatch_vml=...',
              helperMaxLines: 3,
              helperText: 'Một chuỗi cookie hoặc nhiều tài khoản, mỗi dòng: tên | cookie.',
              suffixIcon: IconButton(
                tooltip: _hidden ? 'Hiện cookie' : 'Ẩn cookie',
                onPressed: widget.busy
                    ? null
                    : () => setState(() => _hidden = !_hidden),
                icon: Icon(
                  _hidden
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (draft != null)
            Semantics(
              liveRegion: true,
              child: Text(
                'Sẽ nhập ${draft.accountCount} tài khoản${batch ? ' từ danh sách' : ''}.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          const SizedBox(height: 8),
          Text(
            widget.localMode
                ? 'Cookie được engine lưu trong dữ liệu ứng dụng trên máy này để dùng lại lần sau.'
                : 'Cookie được lưu trên server đang kết nối. Form không lưu bản sao trên thiết bị.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: widget.busy
                ? null
                : () {
                    if (!_form.currentState!.validate()) {
                      _focus.requestFocus();
                      return;
                    }
                    widget.onSubmit(_label.text, _cookies.text);
                  },
            icon: const Icon(Icons.person_add_outlined),
            label: Text(
              widget.busy
                  ? 'Đang nhập…'
                  : draft != null && draft.accountCount > 1
                  ? 'Nhập ${draft.accountCount} tài khoản'
                  : widget.localMode
                  ? 'Nhập tài khoản'
                  : 'Nhập vào server',
            ),
          ),
        ],
      ),
    );
  }
}
