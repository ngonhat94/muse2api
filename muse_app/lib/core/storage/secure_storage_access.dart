import 'package:flutter/services.dart';

import 'storage_failure.dart';

Future<T> secureStorageAccess<T>(Future<T> Function() operation) async {
  try {
    return await operation();
  } on MissingPluginException {
    throw storageFailure(missingPlugin: true);
  } on PlatformException catch (error) {
    // flutter_secure_storage_macos returns OSStatus as an integer in details.
    final status = error.details is int
        ? error.details as int
        : int.tryParse(error.code);
    throw storageFailure(status: status);
  }
}
