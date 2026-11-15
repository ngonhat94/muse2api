/// Known stages only; process output and secrets never reach presentation.
enum DesktopInstallStage {
  preparing,
  dependencies,
  browser,
  packaging,
  verifying,
  cancelling,
}

abstract interface class DesktopEngineInstaller {
  Future<void> install(void Function(DesktopInstallStage) onProgress);
  Future<void> cancelInstall();
}
