import 'dart:io';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/platform/app_round_trips.dart';
import 'package:vikunja_mobile/core/platform/device_channel.dart';
import 'package:vikunja_mobile/core/security/app_excursions.dart';

part 'app_settings_page.g.dart';

final _log = Logger('AppSettingsPage');

/// The app's own page in the system settings: on Android its App info,
/// the way to its battery use; on iOS its page in Settings, with
/// Background App Refresh.
abstract interface class AppSettingsPage {
  /// Whether the page opened; never throws. Leaving for it does not lock
  /// the app.
  Future<bool> open();
}

final class PlatformAppSettingsPage implements AppSettingsPage {
  new({required this._excursions, this._channel = deviceChannel, bool? mobile})
    : _mobile = mobile ?? (Platform.isAndroid || Platform.isIOS);

  final AppExcursions _excursions;
  final MethodChannel _channel;
  final bool _mobile;

  @override
  Future<bool> open() async {
    if (!_mobile) return false;
    try {
      return await _excursions.launchAway(
        () async =>
            await _channel.invokeMethod<bool>('openAppSettings') ?? false,
        opened: (opened) => opened,
      );
    } on Object catch (error) {
      _log.warning('Could not open the app settings: ${error.runtimeType}');
      return false;
    }
  }
}

@Riverpod(keepAlive: true)
AppSettingsPage appSettingsPage(Ref ref) =>
    PlatformAppSettingsPage(excursions: ref.watch(appExcursionsProvider));
