import 'dart:typed_data';

import '../domain/repositories/extension_download.dart';

ExtensionZipSaver createExtensionZipSaver() => _Unsupported();

class _Unsupported implements ExtensionZipSaver {
  @override
  bool get supported => false;
  @override
  void save(Uint8List bytes) => throw UnsupportedError('Browser download only');
}
