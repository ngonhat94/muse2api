import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'package:muse_app/features/accounts/data/extension_zip_saver.dart';

void main() {
  final button = web.HTMLButtonElement()..textContent = 'Save ZIP';
  button.onclick = ((web.Event _) {
    createExtensionZipSaver().save(Uint8List.fromList([80, 75, 3, 4, 1, 2, 3]));
  }).toJS;
  web.document.body!.append(button);
}
