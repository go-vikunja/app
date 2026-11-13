import 'dart:io';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:vikunja_mobile/core/platform/device_channel.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';

final _log = Logger('ClientIdentity');

final class ClientIdentity {
  const new({
    required this.appVersion,
    required this.buildNumber,
    required this.platform,
    required this.osVersion,
  });

  static Future<ClientIdentity> load({PreferencesStore? preferences}) async {
    final packageInfo = await PackageInfo.fromPlatform();
    return ClientIdentity(
      appVersion: packageInfo.version,
      buildNumber: packageInfo.buildNumber,
      platform: Platform.operatingSystem,
      osVersion: await _loadOsVersion(preferences ?? SharedPreferencesStore()),
    );
  }

  static Future<String> _loadOsVersion(PreferencesStore preferences) async {
    if (Platform.isAndroid) {
      // dart:io reports the Linux kernel version on Android.
      return await loadAndroidVersion(
        fromChannel: () => deviceChannel.invokeMethod<String>('osVersion'),
        preferences: preferences,
      );
    }
    return extractOsVersion(Platform.operatingSystemVersion);
  }

  final String appVersion;
  final String buildNumber;
  final String platform;
  final String osVersion;

  String get userAgent {
    final build = buildNumber.isEmpty ? '' : '+${_token(buildNumber)}';
    final system = [
      _token(platform),
      _token(osVersion),
    ].where((part) => part.isNotEmpty).join(' ');
    return 'Vikunja-App/${_token(appVersion)}$build ($system)';
  }

  static String _token(String value) =>
      value.replaceAll(RegExp('[^A-Za-z0-9.+_-]'), '');
}

/// Where the UI isolate leaves the Android version for the others.
const androidVersionKey = 'client.androidVersion';

/// The Android version from `MainActivity`'s channel, remembered for the
/// engines that plugins start in the background (WorkManager, notification
/// actions): `MainActivity` registers the channel only on the UI engine.
Future<String> loadAndroidVersion({
  required Future<String?> Function() fromChannel,
  required PreferencesStore preferences,
}) async {
  try {
    final version = await fromChannel() ?? '';
    if (version.isNotEmpty) {
      await _remember(preferences, version);
    }
    return version;
  } on MissingPluginException {
    return await _remembered(preferences);
  } on Object catch (error) {
    _log.warning('Android version unavailable: ${error.runtimeType}');
    return await _remembered(preferences);
  }
}

Future<void> _remember(PreferencesStore preferences, String version) async {
  try {
    if (await preferences.getString(androidVersionKey) == version) return;
    await preferences.setString(androidVersionKey, version);
  } on Object catch (error) {
    _log.info('Android version not remembered: ${error.runtimeType}');
  }
}

Future<String> _remembered(PreferencesStore preferences) async {
  try {
    return await preferences.getString(androidVersionKey) ?? '';
  } on Object catch (error) {
    _log.info('Remembered Android version unreadable: ${error.runtimeType}');
    return '';
  }
}

/// iOS reports e.g. `Version 17.4 (Build 21E213)`.
String extractOsVersion(String raw) =>
    RegExp(r'\d+(?:\.\d+)+').firstMatch(raw)?.group(0) ?? '';
