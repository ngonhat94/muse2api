import 'dart:io';

import '../domain/repositories/desktop_engine_failure.dart';

String desktopDataDirectory() {
  final env = Platform.environment;
  final home = env['HOME'];
  if (Platform.isWindows && env['LOCALAPPDATA'] != null) {
    return '${env['LOCALAPPDATA']}/MuseStudio/engine';
  }
  if (Platform.isMacOS && home != null) {
    return '$home/Library/Application Support/MuseStudio/engine';
  }
  final data =
      env['XDG_DATA_HOME'] ?? (home == null ? null : '$home/.local/share');
  if (data != null) return '$data/muse-studio/engine';
  throw const DesktopEngineFailure(DesktopEngineFailureCode.storageDenied);
}

String installedRuntimeDirectory(String dataDirectory) =>
    '${Directory(dataDirectory).parent.path}/desktop-runtime/current';
String runtimeExecutable(String directory) =>
    '$directory/muse_engine${Platform.isWindows ? '.exe' : ''}';
String desktopResourceDirectory() {
  final parent = File(Platform.resolvedExecutable).parent;
  return Platform.isMacOS ? '${parent.parent.path}/Resources' : parent.path;
}
