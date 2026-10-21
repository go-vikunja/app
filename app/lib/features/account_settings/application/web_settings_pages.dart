import 'package:vikunja_domain/vikunja_domain.dart';

/// The web's own settings pages the app sends the user to, because they ask
/// for the password or a TOTP code, which the app never handles (D14).
enum WebSettingsPage {
  password('user/settings/password-update'),
  email('user/settings/email-update'),
  totp('user/settings/totp'),
  dataExport('user/settings/data-export'),
  exportDownload('user/export/download'),
  deletion('user/settings/deletion');

  new(this.path);

  final String path;
}

/// [page] on the server's web frontend: the frontend address the server
/// reports, else the server's own address, where the web usually is. An
/// https server's pages are never opened over http, e.g. for a stale
/// `service.publicurl` behind a TLS proxy, as for the sign-in.
Uri webSettingsPageUri(ServerConnection connection, WebSettingsPage page) {
  final advertised = connection.info.frontendUrl;
  final base =
      advertised == null ||
          (connection.rootUri.isScheme('https') &&
              !advertised.isScheme('https'))
      ? connection.rootUri
      : advertised;
  final directory = base.path.endsWith('/')
      ? base
      : base.replace(path: '${base.path}/');
  return directory.resolve(page.path);
}
