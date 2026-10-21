import 'package:vikunja_domain/vikunja_domain.dart';

/// Where CalDAV apps find the user: under the server's own address, not
/// the web's, as the web shows it.
Uri caldavPrincipalUri(ServerConnection connection, String username) {
  final root = connection.rootUri;
  return root.replace(
    pathSegments: [
      ...root.pathSegments.where((segment) => segment.isNotEmpty),
      'dav',
      'principals',
      username,
      '',
    ],
  );
}

/// The server's interactive API documentation.
Uri apiDocsUri(ServerConnection connection) {
  final base = connection.apiBaseUri(ApiVersion.v1);
  return base.replace(path: '${base.path}/docs');
}

final Uri caldavDocsUri = Uri.parse('https://vikunja.io/docs/caldav/');
