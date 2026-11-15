import '../../../core/errors/app_failure.dart';
import '../domain/repositories/desktop_engine.dart';
import '../../connection/domain/entities/server_connection.dart';

DesktopEngine createDesktopEngine() => UnsupportedDesktopEngine();

class UnsupportedDesktopEngine implements DesktopEngine {
  @override
  bool get supported => false;
  @override
  Stream<void> get unexpectedExit => const Stream.empty();
  @override
  Future<ServerConnection> start() async =>
      throw const AppFailure('Chế độ trên máy này chỉ có trong bản desktop.');
  @override
  Future<void> stop() async {}
}
