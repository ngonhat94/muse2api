import 'dart:typed_data';

import '../../../connection/domain/entities/server_connection.dart';

abstract interface class ExtensionDownload {
  Future<Uint8List> fetch(ServerConnection connection);
}

abstract interface class ExtensionZipSaver {
  bool get supported;
  void save(Uint8List bytes);
}
