import 'package:vikunja_domain/vikunja_domain.dart';

const testServerRoot = 'https://tasks.example.com';

/// A connection to [version], 2.7.0 unless given; without v2 the client
/// falls back to `/api/v1`.
ServerConnection testConnection({
  bool hasV2 = true,
  int maxItemsPerPage = 50,
  String root = testServerRoot,
  ServerVersion version = const ServerVersion(2, 7, 0),
}) {
  final info = ServerInfo(version: version, maxItemsPerPage: maxItemsPerPage);
  final apiVersions = {ApiVersion.v1, if (hasV2) ApiVersion.v2};
  return ServerConnection(
    rootUri: Uri.parse(root),
    apiVersions: apiVersions,
    info: info,
    capabilities: ServerCapabilities.derive(
      info: info,
      apiVersions: apiVersions,
    ),
  );
}
