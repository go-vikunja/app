import 'dart:io';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/platform/app_round_trips.dart';
import 'package:vikunja_mobile/core/platform/device_channel.dart';
import 'package:vikunja_mobile/core/security/app_excursions.dart';

part 'app_language_settings.g.dart';

final _log = Logger('AppLanguageSettings');

/// The system's page where the user picks the app's language: Android 13's
/// per-app language page, and on iOS the app's page in Settings with its
/// Language entry.
abstract interface class AppLanguageSettings {
  /// False below Android 13 and wherever the system has no such page.
  Future<bool> available();

  /// Whether the page opened. Leaving for it does not lock the app.
  Future<bool> open();
}

final class PlatformAppLanguageSettings implements AppLanguageSettings {
  new({
    required this._excursions,
    this._channel = deviceChannel,
    bool? android,
    bool? ios,
  }) : _android = android ?? Platform.isAndroid,
       _ios = ios ?? Platform.isIOS;

  final AppExcursions _excursions;
  final MethodChannel _channel;
  final bool _android;
  final bool _ios;

  @override
  Future<bool> available() async {
    if (_ios) return true;
    if (!_android) return false;
    return await _channel.invokeMethod<bool>('canOpenAppLocaleSettings') ??
        false;
  }

  @override
  Future<bool> open() async {
    final method = _android
        ? 'openAppLocaleSettings'
        : _ios
        ? 'openAppSettings'
        : null;
    if (method == null) return false;
    return await _excursions.launchAway(
      () async => await _channel.invokeMethod<bool>(method) ?? false,
      opened: (opened) => opened,
    );
  }
}

@Riverpod(keepAlive: true)
AppLanguageSettings appLanguageSettings(Ref ref) =>
    PlatformAppLanguageSettings(excursions: ref.watch(appExcursionsProvider));

/// False until [AppLanguageSettings.available] answered, and when it failed.
@Riverpod(keepAlive: true)
Future<bool> appLanguageSettingsAvailable(Ref ref) async {
  try {
    return await ref.watch(appLanguageSettingsProvider).available();
  } on Object catch (error) {
    _log.warning('App language settings unavailable: ${error.runtimeType}');
    return false;
  }
}
