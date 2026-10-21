import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/account_settings/application/web_settings_pages.dart';

import '../../helpers/server_connections.dart';

ServerConnection _server({required String root, String? frontend}) {
  final connection = fullServer270(root: root);
  final info = connection.info;
  return ServerConnection(
    rootUri: connection.rootUri,
    apiVersions: connection.apiVersions,
    capabilities: connection.capabilities,
    info: ServerInfo(
      version: info.version,
      rawVersion: info.rawVersion,
      frontendUrl: frontend == null ? null : Uri.parse(frontend),
    ),
  );
}

void main() {
  test('the security pages are where the web routes them', () {
    final server = _server(
      root: 'https://tasks.example.org',
      frontend: 'https://tasks.example.org/',
    );

    expect(
      {
        for (final page in WebSettingsPage.values)
          page: webSettingsPageUri(server, page).toString(),
      },
      {
        WebSettingsPage.password:
            'https://tasks.example.org/user/settings/password-update',
        WebSettingsPage.email:
            'https://tasks.example.org/user/settings/email-update',
        WebSettingsPage.totp: 'https://tasks.example.org/user/settings/totp',
        WebSettingsPage.dataExport:
            'https://tasks.example.org/user/settings/data-export',
        WebSettingsPage.exportDownload:
            'https://tasks.example.org/user/export/download',
        WebSettingsPage.deletion:
            'https://tasks.example.org/user/settings/deletion',
      },
    );
  });

  test('an https server never sends the user to an http frontend', () {
    final server = _server(
      root: 'https://tasks.example.org/vikunja',
      frontend: 'http://tasks.example.org:3456/',
    );

    expect(
      webSettingsPageUri(server, WebSettingsPage.totp),
      Uri.parse('https://tasks.example.org/vikunja/user/settings/totp'),
    );
  });

  test('an http server may report an https frontend, and an http one', () {
    expect(
      webSettingsPageUri(
        _server(
          root: 'http://192.168.1.5:3456',
          frontend: 'https://tasks.example.org/',
        ),
        WebSettingsPage.deletion,
      ),
      Uri.parse('https://tasks.example.org/user/settings/deletion'),
    );
    expect(
      webSettingsPageUri(
        _server(
          root: 'http://localhost:34527',
          frontend: 'http://localhost:34527/',
        ),
        WebSettingsPage.exportDownload,
      ),
      Uri.parse('http://localhost:34527/user/export/download'),
    );
  });
}
