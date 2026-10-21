import 'package:vikunja_domain/vikunja_domain.dart';

/// The web's own settings pages the app sends the user to, because the app
/// never handles passwords (D14).
enum WebSettingsPage {
  password('user/settings/password-update'),
  email('user/settings/email-update');

  new(this.path);

  final String path;
}

/// [page] on the server's web frontend: the frontend address the server
/// reports, else the server's own address, where the web usually is.
Uri webSettingsPageUri(ServerConnection connection, WebSettingsPage page) {
  final base = connection.info.frontendUrl ?? connection.rootUri;
  final directory = base.path.endsWith('/')
      ? base
      : base.replace(path: '${base.path}/');
  return directory.resolve(page.path);
}
