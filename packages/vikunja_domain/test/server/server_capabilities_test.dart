import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

/// The `/info` flags all captured test servers share (Docker defaults).
ServerInfo _info(
  String version, {
  Set<String> proFeatures = const {},
  AuthMethods auth = const AuthMethods(
    localEnabled: true,
    registrationEnabled: true,
  ),
}) => ServerInfo(
  version: ServerVersion.tryParse(version),
  linkSharingEnabled: true,
  taskAttachmentsEnabled: true,
  enabledBackgroundProviders: const ['upload'],
  totpEnabled: true,
  caldavEnabled: true,
  auth: auth,
  emailRemindersEnabled: true,
  userDeletionEnabled: true,
  taskCommentsEnabled: true,
  webhooksEnabled: true,
  enabledProFeatures: proFeatures,
);

const Set<ApiVersion> _v1 = {ApiVersion.v1};
const Set<ApiVersion> _both = {ApiVersion.v1, ApiVersion.v2};

const Set<Capability> _instanceFlags = {
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
};

const Set<Capability> _v2Only = {
  Capability.apiV2,
  Capability.bulkCreateTasks,
  Capability.pendingEmail,
  Capability.byIndexRedirect,
  Capability.userSettingsMergePatch,
  Capability.trash,
  Capability.timeTracking,
  Capability.adminPanel,
  Capability.auditLogs,
  Capability.userInvites,
};

void main() {
  group('ServerCapabilities.derive per test server', () {
    test('1.0.0 is unsupported', () {
      final capabilities = ServerCapabilities.derive(
        info: _info('v1.0.0'),
        apiVersions: _v1,
      );
      expect(capabilities.tier, SupportTier.unsupported);
      expect(capabilities.isSupported, isFalse);
      expect(capabilities.all, _instanceFlags);
    });

    test('2.0.0 is unsupported, but keeps its capabilities', () {
      final capabilities = ServerCapabilities.derive(
        info: _info('v2.0.0'),
        apiVersions: _v1,
      );
      expect(capabilities.tier, SupportTier.unsupported);
      expect(capabilities.isSupported, isFalse);
      expect(capabilities.all, {..._instanceFlags, Capability.sessionRefresh});
    });

    test('2.3.0 is the OAuth tier with OAuth and the WebSocket', () {
      final capabilities = ServerCapabilities.derive(
        info: _info('v2.3.0'),
        apiVersions: _v1,
      );
      expect(capabilities.tier, SupportTier.oauth);
      expect(capabilities.isSupported, isTrue);
      expect(capabilities.all, {
        ..._instanceFlags,
        Capability.sessionRefresh,
        Capability.oauthPkce,
        Capability.websocket,
      });
    });

    test('2.4.0 with v2 is full, without the later v2 additions', () {
      final capabilities = ServerCapabilities.derive(
        info: _info('v2.4.0'),
        apiVersions: _both,
      );
      expect(capabilities.tier, SupportTier.full);
      expect(capabilities.all, {
        ..._instanceFlags,
        Capability.apiV2,
        Capability.sessionRefresh,
        Capability.oauthPkce,
        Capability.websocket,
      });
    });

    test('2.7.0 with v2 has every versioned capability but the trash', () {
      final capabilities = ServerCapabilities.derive(
        info: _info('v2.7.0'),
        apiVersions: _both,
      );
      expect(capabilities.tier, SupportTier.full);
      expect(capabilities.all, {
        ..._instanceFlags,
        Capability.apiV2,
        Capability.sessionRefresh,
        Capability.oauthPkce,
        Capability.websocket,
        Capability.bulkCreateTasks,
        Capability.pendingEmail,
        Capability.byIndexRedirect,
        Capability.userSettingsMergePatch,
      });
    });

    test('2.8.0 with v2 has every versioned capability', () {
      final capabilities = ServerCapabilities.derive(
        info: _info('v2.8.0'),
        apiVersions: _both,
      );
      expect(capabilities.tier, SupportTier.full);
      expect(capabilities.all, {
        ..._instanceFlags,
        Capability.apiV2,
        Capability.sessionRefresh,
        Capability.oauthPkce,
        Capability.websocket,
        Capability.bulkCreateTasks,
        Capability.pendingEmail,
        Capability.byIndexRedirect,
        Capability.userSettingsMergePatch,
        Capability.trash,
        Capability.remindersToSubscribers,
      });
    });

    test('2.6.0 with v2 has pending email but replaces the settings whole', () {
      final capabilities = ServerCapabilities.derive(
        info: _info('v2.6.0'),
        apiVersions: _both,
      );
      expect(capabilities.has(Capability.pendingEmail), isTrue);
      expect(capabilities.has(Capability.userSettingsMergePatch), isFalse);
    });

    test('a build after a tag counts as that release', () {
      final capabilities = ServerCapabilities.derive(
        info: _info('v2.7.0-6-ge7d7f173'),
        apiVersions: const {ApiVersion.v2},
      );
      expect(capabilities.has(Capability.byIndexRedirect), isTrue);
    });
  });

  group('v2-only capabilities', () {
    const licensed = {
      'time_tracking',
      'admin_panel',
      'audit_logs',
      'user_invites',
    };

    for (final version in ['v2.4.0', 'v2.7.0', 'v2.8.0', 'dev']) {
      test('are absent on $version when /api/v2 is unreachable', () {
        final capabilities = ServerCapabilities.derive(
          info: _info(version, proFeatures: licensed),
          apiVersions: _v1,
        );
        expect(capabilities.all.intersection(_v2Only), isEmpty);
        expect(capabilities.tier, SupportTier.oauth);
        expect(capabilities.has(Capability.oauthPkce), isTrue);
      });
    }

    test('licensed features need v2', () {
      final capabilities = ServerCapabilities.derive(
        info: _info('v2.7.0', proFeatures: licensed),
        apiVersions: _both,
      );
      expect(capabilities.has(Capability.timeTracking), isTrue);
      expect(capabilities.has(Capability.adminPanel), isTrue);
      expect(capabilities.has(Capability.auditLogs), isTrue);
      expect(capabilities.has(Capability.userInvites), isTrue);
    });

    test('unlicensed features stay absent with v2', () {
      final capabilities = ServerCapabilities.derive(
        info: _info('v2.7.0', proFeatures: {'time_tracking'}),
        apiVersions: _both,
      );
      expect(capabilities.has(Capability.timeTracking), isTrue);
      expect(capabilities.has(Capability.adminPanel), isFalse);
    });
  });

  group('the trash', () {
    for (final version in [
      'v2.8.0',
      'v2.8.1',
      'v2.8.0-3-gabc1234',
      'v3.0.0',
      'dev',
      'unstable',
    ]) {
      test('$version with v2 has it', () {
        final capabilities = ServerCapabilities.derive(
          info: _info(version),
          apiVersions: _both,
        );
        expect(capabilities.has(Capability.trash), isTrue);
      });
    }

    for (final version in [
      'v2.7.0',
      'v2.7.1',
      'v2.7.1-40-g0123abc',
      'banana',
    ]) {
      test('$version with v2 has none', () {
        final capabilities = ServerCapabilities.derive(
          info: _info(version),
          apiVersions: _both,
        );
        expect(capabilities.has(Capability.trash), isFalse);
      });
    }

    test('a missing version with v2 has none', () {
      final capabilities = ServerCapabilities.derive(
        info: const ServerInfo(version: null),
        apiVersions: _both,
      );
      expect(capabilities.has(Capability.trash), isFalse);
    });

    test('2.8.0 without v2 has none: the routes exist only there', () {
      final capabilities = ServerCapabilities.derive(
        info: _info('v2.8.0'),
        apiVersions: _v1,
      );
      expect(capabilities.has(Capability.trash), isFalse);
    });
  });

  group('reminders only to subscribers', () {
    for (final (version, apiVersions, api) in [
      ('v2.8.0', _both, 'v2'),
      ('v2.8.0', _v1, 'only v1'),
      ('v2.8.0-3-gabcdef1', _both, 'v2'),
      ('dev', _both, 'v2'),
    ]) {
      test('$version with $api has it', () {
        final capabilities = ServerCapabilities.derive(
          info: _info(version),
          apiVersions: apiVersions,
        );
        expect(capabilities.has(Capability.remindersToSubscribers), isTrue);
      });
    }

    for (final version in ['v2.7.1', 'banana']) {
      test('$version with v2 has none', () {
        final capabilities = ServerCapabilities.derive(
          info: _info(version),
          apiVersions: _both,
        );
        expect(capabilities.has(Capability.remindersToSubscribers), isFalse);
      });
    }

    test('a missing version with v2 has none', () {
      final capabilities = ServerCapabilities.derive(
        info: const ServerInfo(version: null),
        apiVersions: _both,
      );
      expect(capabilities.has(Capability.remindersToSubscribers), isFalse);
    });
  });

  group('tier edge cases', () {
    test('an unknown version without v2 is unsupported', () {
      final capabilities = ServerCapabilities.derive(
        info: _info('banana'),
        apiVersions: _v1,
      );
      expect(capabilities.tier, SupportTier.unsupported);
      expect(capabilities.has(Capability.sessionRefresh), isFalse);
    });

    test('an unknown version with v2 is full', () {
      final capabilities = ServerCapabilities.derive(
        info: _info('banana'),
        apiVersions: const {ApiVersion.v2},
      );
      expect(capabilities.tier, SupportTier.full);
      expect(capabilities.has(Capability.oauthPkce), isTrue);
      expect(capabilities.has(Capability.bulkCreateTasks), isFalse);
    });

    for (final (version, tier) in [
      ('v2.2.9', SupportTier.unsupported),
      ('v2.2.1-14-gabcdef0', SupportTier.unsupported),
      ('v2.3', SupportTier.oauth),
      ('v2.3.0-3-g1234567', SupportTier.oauth),
      ('v2.3.1', SupportTier.oauth),
    ]) {
      test('$version without v2 is ${tier.name}', () {
        final capabilities = ServerCapabilities.derive(
          info: _info(version),
          apiVersions: _v1,
        );
        expect(capabilities.tier, tier);
      });
    }

    test('a missing version without v2 is unsupported', () {
      final capabilities = ServerCapabilities.derive(
        info: const ServerInfo(version: null),
        apiVersions: _v1,
      );
      expect(capabilities.tier, SupportTier.unsupported);
    });

    test('a development build without v2 is the OAuth tier', () {
      final capabilities = ServerCapabilities.derive(
        info: _info('unstable'),
        apiVersions: _v1,
      );
      expect(capabilities.tier, SupportTier.oauth);
    });

    test('every supported server offers OAuth 2.0 + PKCE', () {
      for (final version in [
        'v1.0.0',
        'v2.0.0',
        'v2.2.0',
        'v2.3.0',
        'v2.4.0',
        'v2.7.0',
        'dev',
        'banana',
      ]) {
        for (final apiVersions in [
          _v1,
          _both,
          const {ApiVersion.v2},
        ]) {
          final capabilities = ServerCapabilities.derive(
            info: _info(version),
            apiVersions: apiVersions,
          );
          if (!capabilities.isSupported) continue;
          expect(
            capabilities.has(Capability.oauthPkce),
            isTrue,
            reason: '$version on $apiVersions',
          );
        }
      }
    });
  });

  group('instance flags', () {
    test('everything off yields no flag capabilities', () {
      final capabilities = ServerCapabilities.derive(
        info: ServerInfo(version: ServerVersion.tryParse('v2.7.0')),
        apiVersions: _both,
      );
      expect(capabilities.all.intersection(_instanceFlags), isEmpty);
    });

    test('OpenID Connect needs at least one provider', () {
      ServerCapabilities withProviders(List<OpenIdProvider> providers) =>
          ServerCapabilities.derive(
            info: _info(
              'v2.7.0',
              auth: AuthMethods(
                openIdConnectEnabled: true,
                ldapEnabled: true,
                openIdProviders: providers,
              ),
            ),
            apiVersions: _both,
          );

      expect(withProviders([]).has(Capability.openIdConnect), isFalse);
      final capabilities = withProviders([
        const OpenIdProvider(name: 'Authentik', key: 'authentik'),
      ]);
      expect(capabilities.has(Capability.openIdConnect), isTrue);
      expect(capabilities.has(Capability.ldapAuth), isTrue);
      expect(capabilities.has(Capability.localAuth), isFalse);
    });

    test('background providers map to their capabilities', () {
      final capabilities = ServerCapabilities.derive(
        info: ServerInfo(
          version: ServerVersion.tryParse('v2.7.0'),
          enabledBackgroundProviders: const ['upload', 'unsplash'],
        ),
        apiVersions: _both,
      );
      expect(capabilities.has(Capability.backgroundUpload), isTrue);
      expect(capabilities.has(Capability.backgroundUnsplash), isTrue);
    });

    test('the capability set is unmodifiable', () {
      final capabilities = ServerCapabilities.derive(
        info: _info('v2.7.0'),
        apiVersions: _both,
      );
      expect(
        () => capabilities.all.add(Capability.adminPanel),
        throwsUnsupportedError,
      );
    });
  });
}
