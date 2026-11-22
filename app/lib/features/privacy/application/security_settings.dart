import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_mobile/core/platform/app_round_trips.dart';
import 'package:vikunja_mobile/core/platform/device_channel.dart';
import 'package:vikunja_mobile/core/security/app_excursions.dart';

final _log = Logger('SecuritySettings');

/// Opens Android's security settings, where the device's screen lock is
/// set up; whether they opened, never throws. Leaving for them does not
/// lock the app.
Future<bool> openSecuritySettings(
  AppExcursions excursions, {
  MethodChannel channel = deviceChannel,
}) async {
  try {
    return await excursions.launchAway(
      () async =>
          await channel.invokeMethod<bool>('openSecuritySettings') ?? false,
      opened: (opened) => opened,
    );
  } on Object catch (error) {
    _log.warning('Could not open the security settings: ${error.runtimeType}');
    return false;
  }
}
