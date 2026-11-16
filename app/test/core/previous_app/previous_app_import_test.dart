import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_mobile/app/l10n/shipped_locales.dart';
import 'package:vikunja_mobile/app/theme/theme_providers.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/previous_install.dart';
import 'package:vikunja_mobile/core/previous_app/previous_app_import.dart';
import 'package:vikunja_mobile/core/previous_app/previous_app_platform.dart';
import 'package:vikunja_mobile/core/previous_app/previous_app_record.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/previous_app_fakes.dart';

const _readKeys = [
  'read server-address',
  'read recent-servers',
  'read refresh-token',
  'read theme_mode',
  'read dynamic_colors',
  'read locale_override',
];

void main() {
  late List<String> log;
  late MemoryPreferencesStore preferences;
  late RecordingSecureStore secureStore;
  late FakePreviousAppPlatform platform;

  setUp(() {
    log = [];
    preferences = MemoryPreferencesStore();
    secureStore = RecordingSecureStore(log);
    platform = FakePreviousAppPlatform(log: log);
  });

  PreviousAppImport import({bool android = true}) => PreviousAppImport(
    preferences: preferences,
    secureStore: secureStore,
    platform: platform,
    android: android,
  );

  Future<PreviousAppFindings?> run() => import().run();

  group('runs only on the first Android start', () {
    setUp(() => secureStore.values.addAll(previousAppValues()));

    test('not on iOS', () async {
      expect(await import(android: false).run(), isNull);
      expect(log, isEmpty);
      expect(preferences.values, isEmpty);
    });

    test('not once the install marker is set', () async {
      preferences.values[installMarkerKey] = '1';

      expect(await run(), isNull);
      expect(log, isEmpty);
      expect(preferences.values.keys, [installMarkerKey]);
    });

    test('not with a registry, which a build before the marker left', () async {
      preferences.values[AccountRegistry.storageKey] = '{"v":1}';

      expect(await run(), isNull);
      expect(log, isEmpty);
    });

    test('an empty registry counts as none', () async {
      preferences.values[AccountRegistry.storageKey] = '';

      expect(await run(), isNotNull);
    });
  });

  test('a fresh install finds nothing, changes no setting and still cleans '
      'up', () async {
    expect(await run(), isNull);

    expect(preferences.values, isEmpty);
    expect(log.where((call) => !call.startsWith('read ')), [
      'traces',
      'cancelNotifications',
      'clear',
    ]);
  });

  test("the previous app's values: the server normalized, the recent "
      'servers newest first, the token found, the record stored, and all of '
      'it before the cleanup', () async {
    secureStore.values.addAll(
      previousAppValues(
        recentServers: jsonEncode([
          'one.example.com',
          'https://vikunja.example.com',
          'http://two.example.com:3456/',
          'not a server',
          'three.example.com/api/v1',
          'https://one.example.com/',
          'four.example.com',
          'five.example.com',
          'six.example.com',
          'seven.example.com',
        ]),
      ),
    );

    final findings = await run();

    final expected = PreviousAppRecord(
      server: Uri.parse('https://vikunja.example.com'),
      recentServers: [
        Uri.parse('https://seven.example.com'),
        Uri.parse('https://six.example.com'),
        Uri.parse('https://five.example.com'),
        Uri.parse('https://four.example.com'),
        Uri.parse('https://one.example.com'),
      ],
    );
    expect(findings?.record, expected);
    expect(findings?.refreshToken, 'previous-refresh-token');
    expect(await PreviousAppRecord.read(preferences), expected);
    expect(log, isNot(contains('read user-token')));
    expect(log, ['traces', ..._readKeys, 'cancelNotifications', 'clear']);
  });

  test('the recent servers keep each server once, at its newest use, and '
      'drop the server itself', () async {
    secureStore.values.addAll(
      previousAppValues(
        recentServers: jsonEncode([
          'a.example.com',
          'b.example.com',
          'https://a.example.com/',
          'vikunja.example.com',
        ]),
      ),
    );

    final findings = await run();

    expect(findings?.record.recentServers, [
      Uri.parse('https://a.example.com'),
      Uri.parse('https://b.example.com'),
    ]);
  });

  test('without a server address, as after a sign-out, the newest valid '
      'recent server is filled in', () async {
    secureStore.values.addAll(
      previousAppValues(
        server: null,
        refreshToken: null,
        userToken: null,
        recentServers: jsonEncode([
          'old.example.com',
          'last.example.com',
          'not a server',
        ]),
      ),
    );

    final findings = await run();

    expect(findings?.record.server, Uri.parse('https://last.example.com'));
    expect(findings?.record.recentServers, [
      Uri.parse('https://old.example.com'),
    ]);
    expect(findings?.refreshToken, isNull);
  });

  test('an unreadable server address and recent list count as none', () async {
    secureStore.values.addAll(
      previousAppValues(server: 'ftp://example.com', recentServers: '{not'),
    );

    final findings = await run();

    expect(findings?.record.server, isNull);
    expect(findings?.record.recentServers, isEmpty);
    expect(findings?.refreshToken, 'previous-refresh-token');
  });

  group('each trace alone is the previous app', () {
    for (final (name, traces, widgets) in [
      ('its secure entries', const PreviousAppTraces(secureEntries: 3), 0),
      (
        'its notification channels',
        const PreviousAppTraces(legacyChannels: true),
        0,
      ),
      ('its widgets', const PreviousAppTraces(legacyWidgets: 2), 2),
      ('its widget data', const PreviousAppTraces(homeWidgetData: true), 0),
      (
        'its scheduled reminders',
        const PreviousAppTraces(scheduledNotifications: true),
        0,
      ),
    ]) {
      test(name, () async {
        platform.tracesAnswer = traces;

        final findings = await run();

        expect(findings?.record, PreviousAppRecord(placedWidgets: widgets));
        expect(findings?.refreshToken, isNull);
        expect(
          await PreviousAppRecord.read(preferences),
          PreviousAppRecord(placedWidgets: widgets),
        );
        expect(log.last, 'clear');
      });
    }
  });

  group('settings', () {
    test("the previous app's system colors, on", () async {
      secureStore.values.addAll(previousAppValues(dynamicColors: 'true'));

      await run();

      expect(preferences.values[useSystemColorsKey], 'true');
    });

    test('missing system colors were the previous default, off', () async {
      secureStore.values.addAll(previousAppValues());

      await run();

      expect(preferences.values[useSystemColorsKey], 'false');
    });

    test('traces alone leave the system colors alone', () async {
      platform.tracesAnswer = const PreviousAppTraces(secureEntries: 4);

      await run();

      expect(preferences.values.containsKey(useSystemColorsKey), isFalse);
    });

    for (final (theme, stored) in [
      ('dark', 'dark'),
      ('light', 'light'),
      ('system', null),
      ('purple', null),
    ]) {
      test(
        'the theme $theme sets ${stored ?? 'nothing, the default being '
                'the system'} on this device',
        () async {
          secureStore.values.addAll(previousAppValues(theme: theme));

          await run();

          expect(preferences.values[themeModeKey], stored);
        },
      );
    }

    for (final (name, server) in [
      ('without a server', null),
      ('for the public demo', 'try.vikunja.io'),
    ]) {
      test('the theme is carried over $name too, as it stays on this '
          'device', () async {
        secureStore.values.addAll(
          previousAppValues(server: server, theme: 'dark'),
        );

        await run();

        expect(preferences.values[themeModeKey], 'dark');
      });
    }

    test('nothing of the theme is kept for later', () async {
      secureStore.values.addAll(previousAppValues(theme: 'dark'));

      await run();

      expect(
        preferences.values.keys,
        unorderedEquals([
          useSystemColorsKey,
          themeModeKey,
          PreviousAppRecord.storageKey,
        ]),
      );
    });

    // Esperanto cannot ship: Material has no texts for it.
    for (final (locale, call) in [
      for (final shipped in shippedLocales)
        (shipped.toLanguageTag(), 'setAppLanguage ${shipped.toLanguageTag()}'),
      ('eo', null),
      ('de-DE', null),
      (null, null),
    ]) {
      test('the language $locale', () async {
        secureStore.values.addAll(previousAppValues(locale: locale));

        await run();

        expect(log.where((call) => call.startsWith('setAppLanguage')), [?call]);
      });
    }

    test('the settings are applied before the cleanup', () async {
      secureStore.values.addAll(previousAppValues(locale: 'de'));

      await run();

      expect(log.indexOf('setAppLanguage de'), lessThan(log.indexOf('clear')));
      expect(
        log.indexOf('setAppLanguage de'),
        lessThan(log.indexOf('cancelNotifications')),
      );
    });
  });

  test('a rerun after the record was stored reads no secret, finds no token, '
      'cleans up again and returns the stored record', () async {
    secureStore.values.addAll(previousAppValues());
    await run();
    log.clear();

    final findings = await run();

    expect(log, ['cancelNotifications', 'clear']);
    expect(findings?.refreshToken, isNull);
    expect(findings?.record.server, Uri.parse('https://vikunja.example.com'));
  });

  group('failures stay apart', () {
    test('traces that fail still let the values be read', () async {
      platform.failures['traces'] = Exception('channel');
      secureStore.values.addAll(previousAppValues());

      final findings = await run();

      expect(findings?.refreshToken, 'previous-refresh-token');
      expect(log, ['traces', ..._readKeys, 'cancelNotifications', 'clear']);
    });

    test('a key that cannot be read leaves the others', () async {
      secureStore
        ..values.addAll(previousAppValues())
        ..failingReads.add('server-address');

      final findings = await run();

      expect(findings?.record.server, isNull);
      expect(findings?.refreshToken, 'previous-refresh-token');
    });

    test('a failed cancel still clears', () async {
      platform.failures['cancelNotifications'] = Exception('plugin');

      await run();

      expect(log.last, 'clear');
    });

    test('a failed clear still returns the findings', () async {
      platform.failures['clear'] = Exception('native');
      secureStore.values.addAll(previousAppValues());

      expect((await run())?.refreshToken, 'previous-refresh-token');
    });

    test('a clear that does not finish in time is not waited for, and the '
        'findings are returned', () async {
      platform.onClear = () => Completer<void>().future;
      secureStore.values.addAll(previousAppValues());

      final findings = await PreviousAppImport(
        preferences: preferences,
        secureStore: secureStore,
        platform: platform,
        android: true,
        clearTimeout: const Duration(milliseconds: 10),
      ).run().timeout(const Duration(seconds: 5));

      expect(findings?.refreshToken, 'previous-refresh-token');
      expect(log.last, 'clear');
    });

    test('a record that cannot be stored is still returned', () async {
      final failing = _FailingWrites();
      secureStore.values.addAll(previousAppValues());

      final findings = await PreviousAppImport(
        preferences: failing,
        secureStore: secureStore,
        platform: platform,
        android: true,
      ).run();

      expect(findings?.record.server, Uri.parse('https://vikunja.example.com'));
      expect(log.last, 'clear');
    });
  });

  test('the token is never logged and never in the findings text', () async {
    const token = 'previous-refresh-token';
    secureStore
      ..values.addAll(previousAppValues())
      ..failingReads.add('theme_mode');
    platform.failures['clear'] = Exception('native');
    final records = <LogRecord>[];
    final level = Logger.root.level;
    Logger.root.level = Level.ALL;
    final subscription = Logger.root.onRecord.listen(records.add);
    addTearDown(() {
      Logger.root.level = level;
      return subscription.cancel();
    });

    final findings = await run();

    expect(findings?.refreshToken, token);
    expect(records, isNotEmpty);
    for (final record in records) {
      expect(record.message, isNot(contains(token)));
      expect('${record.error}', isNot(contains(token)));
    }
    expect('$findings', isNot(contains(token)));
  });

  group('the stored record', () {
    test('reads back what was written', () async {
      final record = PreviousAppRecord(
        server: Uri.parse('https://vikunja.example.com/sub'),
        recentServers: [Uri.parse('http://192.168.1.20:3456')],
        placedWidgets: 2,
      );

      await record.write(preferences);

      expect(jsonDecode(preferences.values[PreviousAppRecord.storageKey]!), {
        'v': 1,
        'server': 'https://vikunja.example.com/sub',
        'recentServers': ['http://192.168.1.20:3456'],
        'placedWidgets': 2,
      });
      expect(await PreviousAppRecord.read(preferences), record);
    });

    for (final (name, stored) in [
      (
        'another version',
        '{"v":2,"server":null,"recentServers":[],'
            '"placedWidgets":0}',
      ),
      ('broken JSON', '{"v":1,'),
      (
        'a server that is no address',
        '{"v":1,"server":"tasks",'
            '"recentServers":[],"placedWidgets":0}',
      ),
      (
        'a recent server of the wrong type',
        '{"v":1,"server":null,'
            '"recentServers":[3],"placedWidgets":0}',
      ),
      (
        'a widget count of the wrong type',
        '{"v":1,"server":null,'
            '"recentServers":[],"placedWidgets":"2"}',
      ),
      ('a missing field', '{"v":1,"server":null,"recentServers":[]}'),
    ]) {
      test('reads $name as none', () async {
        preferences.values[PreviousAppRecord.storageKey] = stored;

        expect(await PreviousAppRecord.read(preferences), isNull);
      });
    }

    test('reads preferences that fail as none', () async {
      preferences.failNextRead.add(PreviousAppRecord.storageKey);

      expect(await PreviousAppRecord.read(preferences), isNull);
    });
  });
}

final class _FailingWrites implements PreferencesStore {
  @override
  Future<String?> getString(String key) async => null;

  @override
  Future<void> setString(String key, String value) async =>
      throw Exception('Preferences unwritable');

  @override
  Future<void> remove(String key) async {}
}
