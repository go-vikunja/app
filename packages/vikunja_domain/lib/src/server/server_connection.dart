import 'package:meta/meta.dart';
import 'package:vikunja_domain/src/server/api_version.dart';
import 'package:vikunja_domain/src/server/server_capabilities.dart';
import 'package:vikunja_domain/src/server/server_info.dart';

@immutable
final class ServerConnection {
  const new({
    required this.rootUri,
    required this.apiVersions,
    required this.info,
    required this.capabilities,
  });

  /// Scheme, host, optional port and optional sub-path, without a trailing
  /// slash and without `/api/vN`, e.g. `https://example.com/vikunja`.
  final Uri rootUri;

  /// The API versions whose `/info` answered. Always contains [ApiVersion.v1]
  /// or [ApiVersion.v2], usually both on 2.4+.
  final Set<ApiVersion> apiVersions;
  final ServerInfo info;
  final ServerCapabilities capabilities;

  bool get isInsecure => rootUri.scheme == 'http';

  /// Every 2.4.0+ server serves `/api/v2`, so its absence on such a server
  /// means something in front of it (usually a reverse proxy) blocks it.
  bool get apiV2Missing =>
      !apiVersions.contains(ApiVersion.v2) &&
      (info.version?.isAtLeast(2, 4) ?? false);

  ApiVersion get preferredApiVersion =>
      apiVersions.contains(ApiVersion.v2) ? ApiVersion.v2 : ApiVersion.v1;

  Uri apiBaseUri(ApiVersion version) =>
      rootUri.replace(path: '${rootUri.path}/api/${version.pathSegment}');
}
