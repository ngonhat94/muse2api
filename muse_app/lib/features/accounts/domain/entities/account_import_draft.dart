import 'dart:convert';

import '../../../../core/errors/app_failure.dart';

/// Auto-detects the backend's single-header and per-line batch formats.
/// Cookie values are never included in validation messages or diagnostics.
class AccountImportDraft {
  const AccountImportDraft._({
    required this.label,
    required this.text,
    required this.isBatch,
    required this.accountCount,
  });
  final String label;
  final String text;
  final bool isBatch;
  final int accountCount;

  factory AccountImportDraft.parse(String label, String input) {
    final raw = input.trim();
    if (raw.isEmpty) {
      throw const AppFailure('Nhập chuỗi cookie hoặc danh sách tài khoản.');
    }
    if (raw.startsWith('{')) {
      if (!_hasCookies(raw)) {
        throw const AppFailure(
          'Cookie JSON phải là một object không rỗng. Kiểm tra lại định dạng.',
        );
      }
      return AccountImportDraft._(
        label: label.trim(),
        text: raw,
        isBatch: false,
        accountCount: 1,
      );
    }
    final lines = <({int number, String text})>[];
    final all = input.split(RegExp(r'\r\n|\n|\r'));
    for (var i = 0; i < all.length; i++) {
      final line = all[i].trim();
      if (line.isNotEmpty && !line.startsWith('#')) {
        lines.add((number: i + 1, text: line));
      }
    }
    if (lines.isEmpty) throw const AppFailure('Nhập ít nhất một chuỗi cookie.');
    bool labeled(String line) {
      final index = line.indexOf('|');
      return index >= 0 && !line.substring(0, index).contains('=');
    }

    final batch =
        lines.any((line) => labeled(line.text)) ||
        lines
                .where(
                  (line) =>
                      RegExp(r'(^|;)\s*hatch_sess\s*=').hasMatch(line.text),
                )
                .length >
            1;
    if (batch) {
      for (final line in lines) {
        final body = labeled(line.text)
            ? line.text.substring(line.text.indexOf('|') + 1).trim()
            : line.text;
        if (!_hasCookies(body)) {
          throw AppFailure(
            'Dòng ${line.number} chưa có cookie hợp lệ. Dùng dạng tên | cookie hoặc chuỗi cookie.',
          );
        }
      }
      return AccountImportDraft._(
        label: '',
        text: lines.map((line) => line.text).join('\n'),
        isBatch: true,
        accountCount: lines.length,
      );
    }
    // Separate cookie-pair lines can still belong to one account.
    for (final line in lines) {
      if (!_hasCookies(line.text)) {
        throw AppFailure(
          'Dòng ${line.number} chưa có cookie hợp lệ. Kiểm tra lại dấu =.',
        );
      }
    }
    return AccountImportDraft._(
      label: label.trim(),
      text: lines.map((line) => line.text).join('; '),
      isBatch: false,
      accountCount: 1,
    );
  }

  static bool _hasCookies(String text) {
    if (text.trimLeft().startsWith('{')) {
      try {
        final json = jsonDecode(text);
        return json is Map &&
            json.isNotEmpty &&
            json.keys.any((key) => key.toString().trim().isNotEmpty);
      } catch (_) {
        return false;
      }
    }
    return text
        .split(';')
        .any((part) => RegExp(r'^\s*[^=;\s]+\s*=').hasMatch(part));
  }

  @override
  String toString() =>
      'AccountImportDraft(batch: $isBatch, count: $accountCount, cookies: [redacted])';
}
