import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:muse_app/core/network/api_error.dart';

void main() {
  test('v1.6.10 composer-not-sent failure gets safe actionable copy', () {
    final failure = apiError(
      502,
      jsonEncode({'detail': '提示词没有发出去（1 个附件 仍在输入框里），终止等待并换号重试 secret-cookie'}),
    );
    expect(failure.message, contains('chưa được gửi'));
    expect(failure.message, isNot(contains('secret-cookie')));
  });
}
