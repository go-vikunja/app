import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';

const int _mib = 1024 * 1024;

void main() {
  group('parseServerInfo with captured fixtures', () {
    for (final (name, version, frontendPort, migrators) in [
      ('info_v1_1.0.0.json', const ServerVersion(1, 0, 0), 34510, 2),
      ('info_v1_2.0.0.json', const ServerVersion(2, 0, 0), 34520, 2),
      ('info_v1_2.3.0.json', const ServerVersion(2, 3, 0), 34523, 4),
      ('info_v1_2.4.0.json', const ServerVersion(2, 4, 0), 34524, 4),
      ('info_v2_2.4.0.json', const ServerVersion(2, 4, 0), 34524, 4),
      ('info_v1_2.7.0.json', const ServerVersion(2, 7, 0), 34527, 5),
      ('info_v2_2.7.0.json', const ServerVersion(2, 7, 0), 34527, 5),
      ('info_v1_2.8.0.json', const ServerVersion(2, 8, 0), 34552, 5),
      ('info_v2_2.8.0.json', const ServerVersion(2, 8, 0), 34552, 5),
    ]) {
      test(name, () {
        final info = parseServerInfo(fixtureJson(name));

        expect(info.version, version);
        expect(info.version!.raw, 'v${version.display}');
        expect(info.frontendUrl, Uri.parse('http://localhost:$frontendPort/'));
        expect(info.motd, isEmpty);
        expect(info.maxFileSize, '20MB');
        expect(info.maxFileSizeBytes, 20 * _mib);
        expect(info.maxItemsPerPage, 50);
        expect(info.availableMigrators, hasLength(migrators));
        expect(info.availableMigrators.first, 'vikunja-file');
        expect(info.enabledBackgroundProviders, ['upload']);
        expect(info.legal.imprintUrl, isNull);
        expect(info.legal.privacyPolicyUrl, isNull);
        expect(info.legal.links, isEmpty);
        expect(info.auth.localEnabled, isTrue);
        expect(info.auth.registrationEnabled, isTrue);
        expect(info.auth.ldapEnabled, isFalse);
        expect(info.auth.openIdConnectEnabled, isFalse);
        expect(info.auth.openIdProviders, isEmpty);
        expect(info.linkSharingEnabled, isTrue);
        expect(info.taskAttachmentsEnabled, isTrue);
        expect(info.totpEnabled, isTrue);
        expect(info.caldavEnabled, isTrue);
        expect(info.emailRemindersEnabled, isTrue);
        expect(info.userDeletionEnabled, isTrue);
        expect(info.taskCommentsEnabled, isTrue);
        expect(info.webhooksEnabled, isTrue);
        expect(info.demoModeEnabled, isFalse);
        expect(info.publicTeamsEnabled, isFalse);
        expect(info.allowIconChanges, isFalse);
        expect(info.enabledProFeatures, isEmpty);
        if (version.isAtLeast(2, 4)) {
          expect(info.concurrentWrites, isFalse, reason: 'SQLite');
        } else {
          expect(info.concurrentWrites, isNull, reason: 'not reported < 2.4');
        }
      });
    }

    test('info_v2_try_vikunja_io.json (a build after a tag)', () {
      final info = parseServerInfo(fixtureJson('info_v2_try_vikunja_io.json'));

      expect(info.version, const ServerVersion(2, 7, 0));
      expect(info.version!.raw, 'v2.7.0-6-ge7d7f173');
      expect(info.version!.isDevelopmentBuild, isFalse);
      expect(info.frontendUrl, Uri.parse('https://try.vikunja.io/'));
      expect(info.motd, startsWith('You can use the user'));
      expect(info.availableMigrators, contains('trello'));
      expect(info.enabledBackgroundProviders, ['upload', 'unsplash']);
      expect(info.totpEnabled, isFalse);
      expect(info.demoModeEnabled, isTrue);
      expect(info.concurrentWrites, isTrue);
      expect(info.legal.imprintUrl, Uri.parse('https://vikunja.io/imprint/'));
      expect(
        info.legal.privacyPolicyUrl,
        Uri.parse('https://vikunja.io/privacy/'),
      );
      expect(info.legal.links, [
        LegalLink(
          text: 'Imprint',
          url: Uri.parse('https://vikunja.io/imprint/'),
        ),
        LegalLink(
          text: 'Privacy Policy',
          url: Uri.parse('https://vikunja.io/privacy/'),
        ),
      ]);
    });

    for (final version in ['2.7.0', '2.8.0']) {
      test('the v1 and v2 bodies of one $version server parse alike', () {
        final v1 = parseServerInfo(fixtureJson('info_v1_$version.json'));
        final v2 = parseServerInfo(fixtureJson('info_v2_$version.json'));

        expect(v2.version, v1.version);
        expect(v2.availableMigrators, v1.availableMigrators);
        expect(v2.concurrentWrites, v1.concurrentWrites);
        expect(v2.maxFileSizeBytes, v1.maxFileSizeBytes);
        expect(v2.legal.links, v1.legal.links);
      });
    }
  });

  group('legal links', () {
    LegalLinks legalOf(Map<String, Object?> legal) =>
        parseServerInfo({'version': 'v2.8.0', 'legal': legal}).legal;

    final imprint = Uri.parse('https://example.com/imprint');
    final privacy = Uri.parse('https://example.com/privacy');
    final terms = Uri.parse('https://example.com/terms');

    test('2.8.0 lists them with the two deprecated ones first', () {
      final legal = legalOf({
        'imprint_url': '$imprint',
        'privacy_policy_url': '$privacy',
        'links': [
          {'text': 'Imprint', 'url': '$imprint'},
          {'text': 'Privacy Policy', 'url': '$privacy'},
          {'text': 'Terms of Service', 'url': '$terms'},
        ],
      });

      expect(legal.imprintUrl, imprint);
      expect(legal.privacyPolicyUrl, privacy);
      expect(legal.links, [
        LegalLink(text: 'Imprint', url: imprint),
        LegalLink(text: 'Privacy Policy', url: privacy),
        LegalLink(text: 'Terms of Service', url: terms),
      ]);
    });

    test('the imprint and the privacy policy come from the list when '
        'only the new keys are configured', () {
      final legal = legalOf({
        'imprint_url': '',
        'privacy_policy_url': '',
        'links': [
          {'text': 'Imprint', 'url': '$imprint'},
          {'text': 'Privacy Policy', 'url': '$privacy'},
        ],
      });

      expect(legal.imprintUrl, imprint);
      expect(legal.privacyPolicyUrl, privacy);
    });

    test('only the exact server texts name the imprint and privacy policy', () {
      final legal = legalOf({
        'links': [
          {'text': 'imprint', 'url': '$imprint'},
          {'text': 'Datenschutz', 'url': '$privacy'},
        ],
      });

      expect(legal.imprintUrl, isNull);
      expect(legal.privacyPolicyUrl, isNull);
      expect(legal.links, hasLength(2));
    });

    test('the deprecated fields win over a listed link of that name', () {
      final legal = legalOf({
        'imprint_url': '$imprint',
        'links': [
          {'text': 'Imprint', 'url': '$terms'},
        ],
      });

      expect(legal.imprintUrl, imprint);
    });

    test('keeps http(s) links with a text, each URL once', () {
      final legal = legalOf({
        'links': [
          {'text': '  Terms  ', 'url': ' $terms '},
          {'text': 'Terms again', 'url': '$terms'},
          {'text': '', 'url': '$imprint'},
          {'text': '   ', 'url': '$imprint'},
          {'url': '$imprint'},
          {'text': 'No URL'},
          {'text': 'Script', 'url': 'javascript:alert(1)'},
          {'text': 'Relative', 'url': '/privacy'},
          {'text': 'Mail', 'url': 'mailto:legal@example.com'},
          {'text': 42, 'url': '$privacy'},
          {'text': 'Not a string', 'url': 42},
          null,
          'not a link',
          {'text': 'Privacy', 'url': 'http://example.com/privacy'},
        ],
      });

      expect(legal.links, [
        LegalLink(text: 'Terms', url: terms),
        LegalLink(
          text: 'Privacy',
          url: Uri.parse('http://example.com/privacy'),
        ),
      ]);
    });

    test('servers before 2.8.0: the list is built from the two URLs', () {
      expect(
        legalOf({'imprint_url': '$imprint', 'privacy_policy_url': '$privacy'})
            .links,
        [
          LegalLink(text: 'Imprint', url: imprint),
          LegalLink(text: 'Privacy Policy', url: privacy),
        ],
      );
      expect(legalOf({'privacy_policy_url': '$privacy'}).links, [
        LegalLink(text: 'Privacy Policy', url: privacy),
      ]);
      expect(
        legalOf({'imprint_url': '', 'privacy_policy_url': 'ftp://x'}).links,
        isEmpty,
      );
      expect(
        legalOf({'imprint_url': '$imprint', 'privacy_policy_url': '$imprint'})
            .links,
        [LegalLink(text: 'Imprint', url: imprint)],
      );
    });

    test('a links value that is not a list counts as missing', () {
      for (final links in [null, 'x', 1, <String, Object?>{}]) {
        final legal = legalOf({'imprint_url': '$imprint', 'links': links});

        expect(legal.imprintUrl, imprint, reason: '$links');
        expect(legal.links, [
          LegalLink(text: 'Imprint', url: imprint),
        ], reason: '$links');
      }
    });

    test('the list is unmodifiable', () {
      final legal = legalOf({
        'links': [
          {'text': 'Terms', 'url': '$terms'},
        ],
      });

      expect(
        () => legal.links.add(LegalLink(text: 'x', url: terms)),
        throwsUnsupportedError,
      );
    });
  });

  group('parseServerInfo tolerance', () {
    test('keeps an unreadable version string verbatim', () {
      final info = parseServerInfo({'version': ' custom-2024 '});

      expect(info.version, isNull);
      expect(info.rawVersion, 'custom-2024');
    });

    test('only a version is required; everything else has a default', () {
      final info = parseServerInfo({'version': 'v2.0.0'});

      expect(info.version, const ServerVersion(2, 0, 0));
      expect(info.rawVersion, 'v2.0.0');
      expect(info.frontendUrl, isNull);
      expect(info.motd, '');
      expect(info.maxFileSize, '');
      expect(info.maxFileSizeBytes, isNull);
      expect(info.maxItemsPerPage, 50);
      expect(info.availableMigrators, isEmpty);
      expect(info.enabledBackgroundProviders, isEmpty);
      expect(info.auth.localEnabled, isFalse);
      expect(info.auth.openIdProviders, isEmpty);
      expect(info.enabledProFeatures, isEmpty);
      expect(info.concurrentWrites, isNull);
    });

    test('nulls and mistyped values fall back to defaults', () {
      final info = parseServerInfo({
        r'$schema': 'https://example.com/api/v2/schemas/VikunjaInfos.json',
        'version': 'v2.7.0',
        'frontend_url': null,
        'motd': 42,
        'link_sharing_enabled': 'true',
        'max_items_per_page': null,
        'available_migrators': null,
        'enabled_background_providers': ['upload', null, 3],
        'legal': null,
        'auth': {
          'local': null,
          'ldap': 'yes',
          'openid_connect': {'enabled': true, 'providers': null},
        },
        'enabled_pro_features': null,
        'concurrent_writes': null,
        'something_new': {'nested': true},
      });

      expect(info.version, const ServerVersion(2, 7, 0));
      expect(info.frontendUrl, isNull);
      expect(info.motd, '');
      expect(info.linkSharingEnabled, isFalse);
      expect(info.maxItemsPerPage, 50);
      expect(info.availableMigrators, isEmpty);
      expect(info.enabledBackgroundProviders, ['upload']);
      expect(info.legal.imprintUrl, isNull);
      expect(info.auth.localEnabled, isFalse);
      expect(info.auth.ldapEnabled, isFalse);
      expect(info.auth.openIdConnectEnabled, isTrue);
      expect(info.auth.openIdProviders, isEmpty);
      expect(info.enabledProFeatures, isEmpty);
      expect(info.concurrentWrites, isNull);
    });

    test('out-of-range numbers fall back instead of throwing', () {
      for (final perPage in [1e400, -5, 0, 0.5]) {
        expect(
          parseServerInfo({'version': 'v2.7.0', 'max_items_per_page': perPage})
              .maxItemsPerPage,
          50,
          reason: '$perPage',
        );
      }
      expect(
        parseServerInfo({'version': 'v2.7.0', 'max_items_per_page': 1})
            .maxItemsPerPage,
        1,
      );
      expect(
        parseServerInfo({'version': 'v2.7.0', 'max_file_size': 1e400})
            .maxFileSizeBytes,
        isNull,
      );
      expect(
        parseServerInfo({'version': 'v99999999999999999999.0.0'}).version,
        isNull,
      );
    });

    test('a version that is not a string is a FormatException', () {
      for (final json in [
        <String, Object?>{},
        {'version': null},
        {'version': 2.7},
        {
          'version': const ['v2.7.0'],
        },
      ]) {
        expect(() => parseServerInfo(json), throwsFormatException);
      }
    });

    test('the /api/v2/info 404 body of a 2.3 server is no /info', () {
      expect(
        () => parseServerInfo(fixtureJson('v2_info_404_2.3.0.json')),
        throwsFormatException,
      );
    });

    test('an uninterpretable version string yields a null version', () {
      expect(parseServerInfo({'version': 'banana'}).version, isNull);
      expect(
        parseServerInfo({'version': 'unstable'}).version!.isDevelopmentBuild,
        isTrue,
      );
    });

    test('reads registration from auth.local and OpenID providers', () {
      final info = parseServerInfo({
        'version': 'v2.7.0',
        'registration_enabled': true,
        'auth': {
          'local': {'enabled': true, 'registration_enabled': false},
          'ldap': {'enabled': true},
          'openid_connect': {
            'enabled': true,
            'providers': [
              {
                'name': 'Authentik',
                'key': 'authentik',
                'auth_url': 'https://sso.example.com/application/o/authorize/',
                'logout_url': '',
                'client_id': 'vikunja',
                'scope': 'openid profile email',
                'email_fallback': false,
              },
              {'name': 'No key'},
              {'key': 'nameless', 'auth_url': 'javascript:alert(1)'},
              'not a provider',
            ],
          },
        },
      });

      expect(info.auth.localEnabled, isTrue);
      expect(info.auth.registrationEnabled, isFalse);
      expect(info.auth.ldapEnabled, isTrue);
      final [authentik, nameless] = info.auth.openIdProviders;
      expect(authentik.name, 'Authentik');
      expect(authentik.key, 'authentik');
      expect(
        authentik.authUrl,
        Uri.parse('https://sso.example.com/application/o/authorize/'),
      );
      expect(authentik.logoutUrl, isNull);
      expect(authentik.clientId, 'vikunja');
      expect(authentik.scope, 'openid profile email');
      expect(nameless.name, 'nameless');
      expect(nameless.authUrl, isNull);
    });

    test('links must be http(s) URLs with a host', () {
      Uri? imprint(String url) => parseServerInfo({
        'version': 'v2.7.0',
        'legal': {'imprint_url': url},
      }).legal.imprintUrl;

      expect(imprint(''), isNull);
      expect(imprint('   '), isNull);
      expect(imprint('javascript:alert(1)'), isNull);
      expect(imprint('intent://evil'), isNull);
      expect(imprint('/imprint'), isNull);
      expect(imprint(' https://example.com/imprint '), isNotNull);
      expect(
        imprint('http://example.com/imprint').toString(),
        'http://example.com/imprint',
      );
    });

    test('pro features become a set', () {
      final info = parseServerInfo({
        'version': 'v2.7.0',
        'enabled_pro_features': [
          'time_tracking',
          'admin_panel',
          'time_tracking',
        ],
      });

      expect(info.enabledProFeatures, {'time_tracking', 'admin_panel'});
    });

    test('parsed collections are unmodifiable', () {
      final info = parseServerInfo(fixtureJson('info_v2_2.7.0.json'));

      expect(() => info.availableMigrators.add('x'), throwsUnsupportedError);
      expect(() => info.enabledProFeatures.add('x'), throwsUnsupportedError);
    });
  });

  group('max_file_size as the server enforces it', () {
    int? bytesOf(Object? maxFileSize) =>
        parseServerInfo({'version': 'v2.7.0', 'max_file_size': maxFileSize})
            .maxFileSizeBytes;

    for (final (configured, expected) in <(Object?, int?)>[
      ('20MB', 20 * _mib),
      ('20mb', 20 * _mib),
      ('20M', 20 * _mib),
      ('20 MB', 20 * _mib),
      ('20megabytes', 20 * _mib),
      ('1GB', 1024 * _mib),
      ('1g', 1024 * _mib),
      ('2048KB', 2 * _mib),
      // Truncated to whole MiB: 1.5 MiB allows 1 MiB.
      ('1536KB', _mib),
      // Below 1 MiB truncates to 0, which the server replaces by 20 MiB.
      ('512KB', 20 * _mib),
      ('0', 20 * _mib),
      ('', 20 * _mib),
      // A bare number is bytes.
      ('20971520', 20 * _mib),
      ('20971519', 19 * _mib),
      (52428800, 50 * _mib),
      ('1TB', 1024 * 1024 * _mib),
      ('1EB', 1 << 60),
      // Exceeds a Dart int but not the server's uint64.
      ('15EB', 0x7FFFFFFFFFFFFFFF),
      // Spellings the server refuses to start with.
      ('20Mb', null),
      ('20Kb', null),
      ('1.5GB', null),
      (' 20MB', null),
      ('MB', null),
      ('20MiB', null),
      ('20 bytes', null),
      ('16EB', null),
      ('99999999999999999999', null),
      (null, null),
      (true, null),
    ]) {
      test('$configured -> $expected', () {
        expect(bytesOf(configured), expected);
      });
    }

    test('keeps the configured text', () {
      final info = parseServerInfo({
        'version': 'v2.7.0',
        'max_file_size': '1536KB',
      });
      expect(info.maxFileSize, '1536KB');
    });
  });

  group('capabilities derived from the fixtures', () {
    ServerCapabilities derive(String name, Set<ApiVersion> apiVersions) =>
        ServerCapabilities.derive(
          info: parseServerInfo(fixtureJson(name)),
          apiVersions: apiVersions,
        );

    test('tiers per server version', () {
      expect(
        derive('info_v1_1.0.0.json', {ApiVersion.v1}).tier,
        SupportTier.unsupported,
      );
      expect(
        derive('info_v1_2.0.0.json', {ApiVersion.v1}).tier,
        SupportTier.unsupported,
      );
      expect(
        derive('info_v1_2.3.0.json', {ApiVersion.v1}).tier,
        SupportTier.oauth,
      );
      expect(
        derive('info_v2_2.4.0.json', {ApiVersion.v1, ApiVersion.v2}).tier,
        SupportTier.full,
      );
      expect(
        derive('info_v2_2.7.0.json', {ApiVersion.v1, ApiVersion.v2}).tier,
        SupportTier.full,
      );
      expect(
        derive('info_v2_2.8.0.json', {ApiVersion.v1, ApiVersion.v2}).tier,
        SupportTier.full,
      );
      expect(
        derive('info_v2_try_vikunja_io.json', {ApiVersion.v2}).tier,
        SupportTier.full,
      );
    });

    test('flags of the 2.7.0 and 2.8.0 fixtures', () {
      final capabilities = derive('info_v2_2.7.0.json', {
        ApiVersion.v1,
        ApiVersion.v2,
      });

      expect(derive('info_v2_2.8.0.json', {ApiVersion.v1, ApiVersion.v2}).all, {
        ...capabilities.all,
        Capability.trash,
      });

      expect(capabilities.all, {
        Capability.apiV2,
        Capability.sessionRefresh,
        Capability.oauthPkce,
        Capability.websocket,
        Capability.bulkCreateTasks,
        Capability.pendingEmail,
        Capability.byIndexRedirect,
        Capability.userSettingsMergePatch,
        Capability.localAuth,
        Capability.registration,
        Capability.linkSharing,
        Capability.taskAttachments,
        Capability.taskComments,
        Capability.totp,
        Capability.caldav,
        Capability.webhooks,
        Capability.userDeletion,
        Capability.emailReminders,
        Capability.backgroundUpload,
      });
    });
  });
}
