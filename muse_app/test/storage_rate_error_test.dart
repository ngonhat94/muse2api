import 'package:flutter_test/flutter_test.dart';
import 'package:muse_app/core/network/api_error.dart';

void main() {
  test('storage quota errors distinguish disk from Muse balance', () {
    final failure = apiError(507, 'secret-cookie');
    expect(failure.message, contains('lưu trữ'));
    expect(failure.message, contains('Muse'));
    expect(failure.message, isNot(contains('secret-cookie')));
  });
  test('rate errors discourage duplicate generation POST', () {
    expect(apiError(429, 'secret-cookie').message, contains('gửi lại'));
  });
}
