/// Exercises the storage keys and value encodings the app persists.
///
/// `SettingsRepositoryImpl` is pure delegation over this class, so its own test
/// only checks that each call reaches the right data-source method.
library;

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/theming/theme_mode.dart';
import 'package:vikunja_app/data/data_sources/settings_data_source.dart';

void main() {
  late Map<String, String> stored;
  late SettingsDatasource datasource;

  setUp(() {
    stored = <String, String>{};
    FlutterSecureStoragePlatform.instance = TestFlutterSecureStoragePlatform(
      stored,
    );
    datasource = SettingsDatasource(const FlutterSecureStorage());
  });

  group('boolean flags', () {
    // Every boolean is stored as "1"/"0" under a fixed key; anything else,
    // including a missing key, reads as false.
    final flags =
        <
          String,
          ({
            String key,
            Future<bool> Function() read,
            Future<void> Function(bool) write,
          })
        >{
          'ignoreCertificates': (
            key: 'ignore-certificates',
            read: () => datasource.getIgnoreCertificates(),
            write: (v) => datasource.setIgnoreCertificates(v),
          ),
          'sentryEnabled': (
            key: 'sentry-enabled',
            read: () => datasource.getSentryEnabled(),
            write: (v) => datasource.setSentryEnabled(v),
          ),
          'versionNotifications': (
            key: 'get-version-notifications',
            read: () => datasource.getVersionNotifications(),
            write: (v) => datasource.setVersionNotifications(v),
          ),
          'landingPageOnlyDueDateTasks': (
            key: 'landing-page-due-date-tasks',
            read: () => datasource.getLandingPageOnlyDueDateTasks(),
            write: (v) => datasource.setLandingPageOnlyDueDateTasks(v),
          ),
          'sentryDialogShown': (
            key: 'sentry-modal-shown',
            read: () => datasource.getSentryDialogShown(),
            write: (v) => datasource.setSentryDialogShown(v),
          ),
        };

    flags.forEach((name, flag) {
      test('$name writes "1" and reads back true', () async {
        await flag.write(true);

        expect(stored[flag.key], '1');
        expect(await flag.read(), isTrue);
      });

      test('$name writes "0" and reads back false', () async {
        await flag.write(false);

        expect(stored[flag.key], '0');
        expect(await flag.read(), isFalse);
      });

      test('$name reads false when nothing was ever stored', () async {
        expect(await flag.read(), isFalse);
      });
    });
  });

  group('refresh interval', () {
    test('round-trips a positive number of minutes', () async {
      await datasource.setRefreshInterval(45);

      expect(stored['workmanager-duration'], '45');
      expect(await datasource.getRefreshInterval(), 45);
    });

    test('reads 0 when nothing was stored', () async {
      expect(await datasource.getRefreshInterval(), 0);
    });

    test('reads 0 when the stored value is not a number', () async {
      stored['workmanager-duration'] = 'not-a-number';

      expect(await datasource.getRefreshInterval(), 0);
    });
  });

  group('theme mode', () {
    test('round-trips each mode as its bare enum name', () async {
      for (final mode in FlutterThemeMode.values) {
        await datasource.setThemeMode(mode);

        expect(stored['theme_mode'], mode.name);
        expect(await datasource.getThemeMode(), mode);
      }
    });

    test(
      'defaults to system and persists that default on first read',
      () async {
        expect(await datasource.getThemeMode(), FlutterThemeMode.system);
        expect(stored['theme_mode'], 'system');
      },
    );

    test('falls back to system for an unrecognised stored value', () async {
      stored['theme_mode'] = 'solarized';

      expect(await datasource.getThemeMode(), FlutterThemeMode.system);
    });
  });

  group('dynamic colors', () {
    test('stores the literal "true" and reads it back', () async {
      await datasource.setDynamicColors(true);

      expect(stored['dynamic_colors'], 'true');
      expect(await datasource.getDynamicColors(), isTrue);
    });

    test('stores the literal "false" and reads it back', () async {
      await datasource.setDynamicColors(false);

      expect(stored['dynamic_colors'], 'false');
      expect(await datasource.getDynamicColors(), isFalse);
    });

    test('reads false when nothing was stored', () async {
      expect(await datasource.getDynamicColors(), isFalse);
    });
  });

  group('per-project display-done flag', () {
    test('keys the flag by project id', () async {
      await datasource.setDisplayDoneTasks(7, true);

      expect(stored['display_done_tasks_list_7'], '1');
      expect(await datasource.getDisplayDoneTasks(7), isTrue);
    });

    test('keeps projects independent of one another', () async {
      await datasource.setDisplayDoneTasks(7, true);
      await datasource.setDisplayDoneTasks(8, false);

      expect(await datasource.getDisplayDoneTasks(7), isTrue);
      expect(await datasource.getDisplayDoneTasks(8), isFalse);
      expect(await datasource.getDisplayDoneTasks(9), isFalse);
    });
  });

  group('past servers', () {
    test('stores the list as a json array', () async {
      await datasource.setPastServers([
        'https://a.example',
        'https://b.example',
      ]);

      expect(
        stored['recent-servers'],
        '["https://a.example","https://b.example"]',
      );
      expect(await datasource.getPastServers(), [
        'https://a.example',
        'https://b.example',
      ]);
    });

    test('reads an empty list when nothing was stored', () async {
      expect(await datasource.getPastServers(), isEmpty);
    });

    test('round-trips an empty list', () async {
      await datasource.setPastServers([]);

      expect(await datasource.getPastServers(), isEmpty);
    });
  });

  group('credentials', () {
    test('server address round-trips', () async {
      await datasource.saveServer('https://vikunja.example.com');

      expect(stored['server-address'], 'https://vikunja.example.com');
      expect(await datasource.getServer(), 'https://vikunja.example.com');
    });

    test('user token round-trips', () async {
      await datasource.saveUserToken('access-123');

      expect(stored['user-token'], 'access-123');
      expect(await datasource.getUserToken(), 'access-123');
    });

    test('refresh token round-trips', () async {
      await datasource.saveRefreshToken('refresh-123');

      expect(stored['refresh-token'], 'refresh-123');
      expect(await datasource.getRefreshToken(), 'refresh-123');
    });

    test('reads null for credentials that were never stored', () async {
      expect(await datasource.getServer(), isNull);
      expect(await datasource.getUserToken(), isNull);
      expect(await datasource.getRefreshToken(), isNull);
    });

    test('clearAuthData removes token, refresh token and server', () async {
      await datasource.saveUserToken('access-123');
      await datasource.saveRefreshToken('refresh-123');
      await datasource.saveServer('https://vikunja.example.com');

      await datasource.clearAuthData();

      expect(await datasource.getUserToken(), isNull);
      expect(await datasource.getRefreshToken(), isNull);
      expect(await datasource.getServer(), isNull);
    });
  });

  group('locale override', () {
    test('round-trips a language code', () async {
      await datasource.setLocaleOverride('de');

      expect(stored['locale_override'], 'de');
      expect(await datasource.getLocaleOverride(), 'de');
    });

    test('clearing the override removes the key', () async {
      await datasource.setLocaleOverride('de');

      await datasource.setLocaleOverride(null);

      expect(await datasource.getLocaleOverride(), isNull);
    });

    test('reads null when no override was ever set', () async {
      expect(await datasource.getLocaleOverride(), isNull);
    });
  });
}
