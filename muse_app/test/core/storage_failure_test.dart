import 'package:test/test.dart';
import 'package:muse_app/core/storage/storage_failure.dart';

void main() {
  test(
    'Missing entitlement gives the native status and a concrete recovery path',
    () {
      final message = storageFailure(status: -34018).message;
      expect(message, contains('-34018'));
      expect(message, contains('Keychain Sharing'));
    },
  );
  test('Missing plugin requires a full restart rather than a storage permission change', () {
    expect(
      storageFailure(missingPlugin: true).message,
      contains('flutter run'),
    );
  });
  test('Unknown statuses expose only the numeric diagnostic', () {
    expect(storageFailure(status: -25308).message, contains('-25308'));
    expect(storageFailure().message, isNotEmpty);
  });
}
