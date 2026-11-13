import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/network/client_identity.dart';

import '../../helpers/auth_fakes.dart';

void main() {
  test('builds the User-Agent from app and platform details', () {
    const identity = ClientIdentity(
      appVersion: '0.1.0',
      buildNumber: '7',
      platform: 'android',
      osVersion: '15',
    );

    expect(identity.userAgent, 'Vikunja-App/0.1.0+7 (android 15)');
  });

  test('omits missing parts and strips characters unsafe in headers', () {
    const identity = ClientIdentity(
      appVersion: '0.1.0 beta',
      buildNumber: '',
      platform: 'ios',
      osVersion: '',
    );

    expect(identity.userAgent, 'Vikunja-App/0.1.0beta (ios)');
  });

  test('extracts the iOS version from the dart:io description', () {
    expect(extractOsVersion('Version 17.4 (Build 21E213)'), '17.4');
    expect(extractOsVersion('Version 18.0.1 (Build 22A3370)'), '18.0.1');
    expect(extractOsVersion('unknown'), '');
  });

  group('Android version', () {
    test('comes from the channel and is remembered', () async {
      final preferences = MemoryPreferencesStore();

      final version = await loadAndroidVersion(
        fromChannel: () async => '16',
        preferences: preferences,
      );

      expect(version, '16');
      expect(await preferences.getString(androidVersionKey), '16');
    });

    test(
      'comes from the remembered value in an engine without the channel',
      () async {
        final preferences = MemoryPreferencesStore();
        await preferences.setString(androidVersionKey, '16');

        final version = await loadAndroidVersion(
          fromChannel: () async => throw MissingPluginException('no handler'),
          preferences: preferences,
        );

        expect(version, '16');
      },
    );

    test(
      'is empty when neither the channel nor a remembered value has it',
      () async {
        final version = await loadAndroidVersion(
          fromChannel: () async => throw MissingPluginException('no handler'),
          preferences: MemoryPreferencesStore(),
        );

        expect(version, '');
      },
    );

    test('falls back to the remembered value on a channel error', () async {
      final preferences = MemoryPreferencesStore();
      await preferences.setString(androidVersionKey, '15');

      final version = await loadAndroidVersion(
        fromChannel: () async => throw PlatformException(code: 'boom'),
        preferences: preferences,
      );

      expect(version, '15');
    });

    test(
      'an empty channel answer does not overwrite the remembered value',
      () async {
        final preferences = MemoryPreferencesStore();
        await preferences.setString(androidVersionKey, '15');

        final version = await loadAndroidVersion(
          fromChannel: () async => null,
          preferences: preferences,
        );

        expect(version, '');
        expect(await preferences.getString(androidVersionKey), '15');
      },
    );
  });
}
