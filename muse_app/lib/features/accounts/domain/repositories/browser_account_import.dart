import '../../../connection/domain/entities/server_connection.dart';

const approvedBrowserImportOrigin = 'https://muse.dntrip.xyz';
const approvedBrowserImportOrigins = [
  'https://muapp-3d6.pages.dev',
  approvedBrowserImportOrigin,
];
const approvedBrowserImportOriginsLabel =
    'https://muse.dntrip.xyz và https://muapp-3d6.pages.dev';

enum BrowserImportCapability {
  supported,
  unsupportedOrigin,
  unsupportedDevice,
  native,
}

BrowserImportCapability browserImportCapabilityFor({
  required String origin,
  required String userAgent,
}) {
  if (RegExp(
    r'Android|iPhone|iPad|Mobile',
    caseSensitive: false,
  ).hasMatch(userAgent)) {
    return BrowserImportCapability.unsupportedDevice;
  }
  return approvedBrowserImportOrigins.contains(origin)
      ? BrowserImportCapability.supported
      : BrowserImportCapability.unsupportedOrigin;
}

abstract interface class BrowserAccountImport {
  BrowserImportCapability get capability;
  bool get supported;
  Future<bool> available();
  Future<String> prepare();
  Future<String> approve(String id, ServerConnection connection);
  Future<String> commit(String id, ServerConnection connection);
  void cancel(String id);
}
