import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';

void _expectSameInfo(ServerInfo actual, ServerInfo expected) {
  expect(actual.version, expected.version);
  expect(actual.version?.raw, expected.version?.raw);
  expect(actual.rawVersion, expected.rawVersion);
  expect(actual.frontendUrl, expected.frontendUrl);
  expect(actual.motd, expected.motd);
  expect(actual.linkSharingEnabled, expected.linkSharingEnabled);
  expect(actual.maxFileSize, expected.maxFileSize);
  expect(actual.maxFileSizeBytes, expected.maxFileSizeBytes);
  expect(actual.maxItemsPerPage, expected.maxItemsPerPage);
  expect(actual.availableMigrators, expected.availableMigrators);
  expect(actual.taskAttachmentsEnabled, expected.taskAttachmentsEnabled);
  expect(
    actual.enabledBackgroundProviders,
    expected.enabledBackgroundProviders,
  );
  expect(actual.totpEnabled, expected.totpEnabled);
  expect(actual.legal.imprintUrl, expected.legal.imprintUrl);
  expect(actual.legal.privacyPolicyUrl, expected.legal.privacyPolicyUrl);
  expect(actual.caldavEnabled, expected.caldavEnabled);
  expect(actual.auth.localEnabled, expected.auth.localEnabled);
  expect(actual.auth.registrationEnabled, expected.auth.registrationEnabled);
  expect(actual.auth.ldapEnabled, expected.auth.ldapEnabled);
  expect(actual.auth.openIdConnectEnabled, expected.auth.openIdConnectEnabled);
  expect(
    actual.auth.openIdProviders.length,
    expected.auth.openIdProviders.length,
  );
  for (final (index, provider) in actual.auth.openIdProviders.indexed) {
    final other = expected.auth.openIdProviders[index];
    expect(provider.name, other.name);
    expect(provider.key, other.key);
    expect(provider.authUrl, other.authUrl);
    expect(provider.logoutUrl, other.logoutUrl);
    expect(provider.clientId, other.clientId);
    expect(provider.scope, other.scope);
  }
  expect(actual.emailRemindersEnabled, expected.emailRemindersEnabled);
  expect(actual.userDeletionEnabled, expected.userDeletionEnabled);
  expect(actual.taskCommentsEnabled, expected.taskCommentsEnabled);
  expect(actual.demoModeEnabled, expected.demoModeEnabled);
  expect(actual.webhooksEnabled, expected.webhooksEnabled);
  expect(actual.publicTeamsEnabled, expected.publicTeamsEnabled);
  expect(actual.allowIconChanges, expected.allowIconChanges);
  expect(actual.enabledProFeatures, expected.enabledProFeatures);
  expect(actual.concurrentWrites, expected.concurrentWrites);
}

/// [raw] restricted to what [serialized] has, with the null provider list
/// the server sends written as an empty one.
Object? _comparable(Object? raw, Object? serialized) {
  if (raw is Map<String, Object?> && serialized is Map<String, Object?>) {
    return {
      for (final key in raw.keys)
        if (key != r'$schema') key: _comparable(raw[key], serialized[key]),
    };
  }
  if (raw == null && serialized is List && serialized.isEmpty) return [];
  return raw;
}

void main() {
  final infoFixtures = [
    for (final file in Directory('test/fixtures').listSync())
      if (file is File && file.path.endsWith('.json'))
        file.uri.pathSegments.last,
  ].where((name) => fixtureJson(name).containsKey('version')).toList()..sort();

  test('every /info fixture is covered', () {
    expect(infoFixtures, hasLength(8));
  });

  for (final name in infoFixtures) {
    group(name, () {
      final raw = fixtureJson(name);
      final info = parseServerInfo(raw);

      test('round-trips through the parser', () {
        final restored = parseServerInfo(serverInfoToJson(info));

        _expectSameInfo(restored, info);
        expect(serverInfoToJson(restored), serverInfoToJson(info));
      });

      test("reproduces the server's own fields", () {
        final serialized = serverInfoToJson(info);

        expect(serialized, containsPair('version', raw['version']));
        expect(_comparable(raw, serialized), {
          for (final key in raw.keys)
            if (key != r'$schema') key: serialized[key],
        });
      });
    });
  }

  test('a fully populated info round-trips', () {
    final info = ServerInfo(
      version: ServerVersion.tryParse('v2.7.0-6-ge7d7f173'),
      rawVersion: 'v2.7.0-6-ge7d7f173',
      frontendUrl: Uri.parse('https://tasks.example.com/web/'),
      motd: 'Hello',
      linkSharingEnabled: true,
      maxFileSize: '1GB',
      maxFileSizeBytes: 1 << 30,
      maxItemsPerPage: 100,
      availableMigrators: const ['vikunja-file', 'todoist'],
      taskAttachmentsEnabled: true,
      enabledBackgroundProviders: const ['upload', 'unsplash'],
      totpEnabled: true,
      legal: LegalLinks(
        imprintUrl: Uri.parse('https://example.com/imprint'),
        privacyPolicyUrl: Uri.parse('https://example.com/privacy'),
      ),
      caldavEnabled: true,
      auth: AuthMethods(
        localEnabled: true,
        registrationEnabled: true,
        ldapEnabled: true,
        openIdConnectEnabled: true,
        openIdProviders: [
          OpenIdProvider(
            name: 'Company SSO',
            key: 'company',
            authUrl: Uri.parse('https://sso.example.com/auth'),
            logoutUrl: Uri.parse('https://sso.example.com/logout'),
            clientId: 'vikunja',
            scope: 'openid profile email',
          ),
          const OpenIdProvider(name: 'Bare', key: 'bare'),
        ],
      ),
      emailRemindersEnabled: true,
      userDeletionEnabled: true,
      taskCommentsEnabled: true,
      demoModeEnabled: true,
      webhooksEnabled: true,
      publicTeamsEnabled: true,
      allowIconChanges: true,
      enabledProFeatures: const {'time_tracking', 'admin_panel'},
      concurrentWrites: true,
    );

    _expectSameInfo(parseServerInfo(serverInfoToJson(info)), info);
  });

  test('a server that reported no max_file_size keeps reporting none', () {
    final info = parseServerInfo(const {'version': 'v2.7.0'});

    expect(info.maxFileSizeBytes, isNull);
    expect(serverInfoToJson(info).containsKey('max_file_size'), isFalse);
    _expectSameInfo(parseServerInfo(serverInfoToJson(info)), info);
  });

  test('an empty max_file_size keeps the 20 MiB fallback', () {
    final info = parseServerInfo(const {
      'version': 'v2.7.0',
      'max_file_size': '',
    });

    expect(info.maxFileSizeBytes, 20 << 20);
    _expectSameInfo(parseServerInfo(serverInfoToJson(info)), info);
  });

  test('an unreadable version string stays as reported', () {
    final info = parseServerInfo(const {'version': 'custom-build'});

    expect(info.version, isNull);
    expect(serverInfoToJson(info)['version'], 'custom-build');
  });
}
