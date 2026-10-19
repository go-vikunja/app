import 'package:vikunja_domain/vikunja_domain.dart';

/// `/api/v2/ws` on servers with v2, else `/api/v1/ws` (2.3+); both speak the
/// same protocol.
Uri realtimeUri(ServerConnection connection) {
  final api = connection.apiBaseUri(connection.preferredApiVersion);
  return api.replace(
    scheme: api.isScheme('https') ? 'wss' : 'ws',
    path: '${api.path}/ws',
  );
}
