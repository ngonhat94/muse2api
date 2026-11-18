import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../domain/repositories/extension_download.dart';

ExtensionZipSaver createExtensionZipSaver() => _BrowserSaver();

class _BrowserSaver implements ExtensionZipSaver {
  @override
  bool get supported => true;
  @override
  void save(Uint8List bytes) {
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'application/zip'),
    );
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = 'muse2api-extension.zip';
    try {
      web.document.body?.append(anchor);
      anchor.click();
    } finally {
      anchor.remove();
      Timer(const Duration(minutes: 1), () => web.URL.revokeObjectURL(url));
    }
  }
}
