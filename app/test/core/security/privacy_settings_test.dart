import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/security/privacy_providers.dart';
import 'package:vikunja_mobile/core/security/privacy_settings.dart';
import 'package:vikunja_mobile/core/security/privacy_settings_store.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';

import '../../helpers/app_lock_fakes.dart';
import '../../helpers/auth_fakes.dart';

void main() {
  const changed = PrivacySettings(
    appLock: true,
    lockAfter: LockAfter.fifteenMinutes,
    blockScreenshots: true,
    notificationContent: NotificationContent.noTitles,
    widgetTitles: false,
  );

  group('the JSON', () {
    test('keeps every field through a round trip', () {
      final json = jsonDecode(jsonEncode(changed.toJson()));

      expect(PrivacySettings.fromJson(json), changed);
    });

    test('is versioned and names the choices', () {
      expect(changed.toJson(), {
        'version': 1,
        'appLock': true,
        'lockAfter': 'fifteenMinutes',
        'blockScreenshots': true,
        'notificationContent': 'noTitles',
        'widgetTitles': false,
      });
    });

    test('defaults to the lock off after a minute, everything shown', () {
      const defaults = PrivacySettings();

      expect(defaults.appLock, isFalse);
      expect(defaults.lockAfter, LockAfter.oneMinute);
      expect(defaults.lockAfter.duration, const Duration(minutes: 1));
      expect(defaults.blockScreenshots, isFalse);
      expect(defaults.notificationContent, NotificationContent.all);
      expect(defaults.widgetTitles, isTrue);
      expect(PrivacySettings.fromJson(const {'version': 1}), defaults);
    });

    test('ignores unknown fields', () {
      expect(
        PrivacySettings.fromJson(const {
          'version': 1,
          'appLock': true,
          'faceUnlockOnly': true,
        }),
        const PrivacySettings(appLock: true),
      );
    });

    test('falls back to the default of a field with an unknown choice', () {
      expect(
        PrivacySettings.fromJson(const {
          'version': 1,
          'appLock': true,
          'lockAfter': 'tenSeconds',
          'notificationContent': 'emojiOnly',
        }),
        const PrivacySettings(appLock: true),
      );
    });

    for (final json in <Object?>[
      {'version': 2, 'appLock': false},
      {'appLock': false},
      {'version': '1'},
      {'version': 1, 'appLock': 'no'},
      {'version': 1, 'lockAfter': 60},
      ['version', 1],
      null,
    ]) {
      test('rejects $json', () {
        expect(
          () => PrivacySettings.fromJson(json),
          throwsA(isA<FormatException>()),
        );
      });
    }
  });

  group('the store', () {
    late MemoryPreferencesStore preferences;
    late PrivacySettingsStore store;

    setUp(() {
      preferences = MemoryPreferencesStore();
      store = PrivacySettingsStore(preferences);
    });

    test('reads the defaults while nothing is stored', () async {
      expect(await store.read(), const PrivacySettings());
    });

    test('reads back what it wrote, under one device key', () async {
      await store.write(changed);

      expect(preferences.values.keys, [PrivacySettingsStore.key]);
      expect(PrivacySettingsStore.key, 'privacy.settings');
      expect(await store.read(), changed);
    });

    for (final (name, stored) in [
      ('not JSON', '{appLock: true'),
      ('a later version', '{"version": 2, "appLock": false}'),
      ('a field of the wrong type', '{"version": 1, "appLock": "off"}'),
    ]) {
      test('cannot read $name', () async {
        preferences.values[PrivacySettingsStore.key] = stored;

        await expectLater(
          store.read(),
          throwsA(isA<PrivacySettingsUnreadable>()),
        );
      });
    }

    test('cannot read when the preferences fail', () async {
      await expectLater(
        PrivacySettingsStore(_FailingPreferences()).read(),
        throwsA(isA<PrivacySettingsUnreadable>()),
      );
    });
  });

  group('the providers', () {
    late MemoryPreferencesStore preferences;
    late ProviderContainer container;

    setUp(() {
      preferences = MemoryPreferencesStore();
      container = ProviderContainer(
        overrides: [preferencesStoreProvider.overrideWithValue(preferences)],
      );
      addTearDown(container.dispose);
    });

    test('read what is stored', () async {
      await storePrivacySettings(preferences, changed);

      expect(
        await container.read(privacySettingsControllerProvider.future),
        const StoredPrivacySettings(changed),
      );
      expect(await container.read(privacySettingsProvider.future), changed);
    });

    test('give the page the defaults for unreadable settings and the rest '
        'of the app the most private choices, write nothing back, until a '
        'save overwrites them', () async {
      preferences.values[PrivacySettingsStore.key] = 'garbage';

      final stored = await container.read(
        privacySettingsControllerProvider.future,
      );

      expect(stored.unreadable, isTrue);
      expect(stored.settings, const PrivacySettings());
      expect(
        await container.read(privacySettingsProvider.future),
        const PrivacySettings(
          appLock: true,
          blockScreenshots: true,
          notificationContent: NotificationContent.noTitles,
          widgetTitles: false,
        ),
      );
      expect(preferences.values[PrivacySettingsStore.key], 'garbage');

      await container
          .read(privacySettingsControllerProvider.notifier)
          .save(const PrivacySettings());

      expect(
        container.read(privacySettingsControllerProvider).value,
        const StoredPrivacySettings(PrivacySettings()),
      );
      expect(
        jsonDecode(preferences.values[PrivacySettingsStore.key]!),
        const PrivacySettings().toJson(),
      );
    });

    test('change one field of the current settings', () async {
      await storePrivacySettings(preferences, changed);

      await container
          .read(privacySettingsControllerProvider.notifier)
          .change(
            (settings) => settings.copyWith(lockAfter: LockAfter.immediately),
          );

      final expected = changed.copyWith(lockAfter: LockAfter.immediately);
      expect(await container.read(privacySettingsProvider.future), expected);
      expect(await PrivacySettingsStore(preferences).read(), expected);
    });

    test('keep the settings when the store refuses a save', () async {
      final failing = ProviderContainer(
        overrides: [
          preferencesStoreProvider.overrideWithValue(_FailingPreferences()),
        ],
      );
      addTearDown(failing.dispose);
      final before = await failing.read(
        privacySettingsControllerProvider.future,
      );

      await expectLater(
        failing.read(privacySettingsControllerProvider.notifier).save(changed),
        throwsA(isA<StateError>()),
      );

      expect(failing.read(privacySettingsControllerProvider).value, before);
    });
  });
}

final class _FailingPreferences implements PreferencesStore {
  @override
  Future<String?> getString(String key) async => throw StateError('locked');

  @override
  Future<void> setString(String key, String value) async =>
      throw StateError('locked');

  @override
  Future<void> remove(String key) async => throw StateError('locked');
}
