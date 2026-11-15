import '../../../connection/domain/entities/server_connection.dart';

/// An app-owned runtime. Its transient connection must never replace saved
/// remote credentials. Stop only the process this instance started.
abstract interface class DesktopEngine {
  bool get supported;
  Stream<void> get unexpectedExit;
  Future<ServerConnection> start();
  Future<void> stop();
}
