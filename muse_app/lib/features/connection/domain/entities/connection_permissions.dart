import 'server_connection.dart';

/// Technical UI requires a verified admin and the server settings capability.
/// Local engine controls remain available on desktop, not an admin bypass.
bool canConfigureServer(ServerConnection? connection) =>
    connection?.principal?.isAdmin == true &&
    connection?.principal?.can('global_settings') == true;

bool canShowConnectionTools(
  ServerConnection? connection, {
  required bool supportsLocal,
}) =>
    canConfigureServer(connection) ||
    (supportsLocal && (connection == null || connection.isLocal));
