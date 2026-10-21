import 'package:material_ui/material_ui.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';

/// One line for the device that signed in, e.g. `Rurana 0.31.0 · Android
/// 15` or `Firefox on Linux`; what cannot be read shows as the server
/// stored it.
String sessionDeviceLine(AppLocalizations l10n, DeviceDescription device) {
  final system = [?device.osName, ?device.osVersion].join(' ');
  final browser = device.browserName;
  return switch (device.kind) {
    DeviceKind.rurana => [
      ['Rurana', ?device.appVersion].join(' '),
      if (system.isNotEmpty) system,
    ].join(' · '),
    DeviceKind.browser when browser != null && system.isNotEmpty =>
      l10n.sessionsBrowserOn(browser, system),
    DeviceKind.browser when browser != null => browser,
    DeviceKind.dartClient => l10n.sessionsDartClient,
    _ when device.raw.isNotEmpty => device.raw,
    _ => l10n.sessionsUnknownDevice,
  };
}

IconData sessionDeviceIcon(DeviceDescription device) {
  final system = device.osName?.toLowerCase() ?? '';
  final mobile = system.contains('android') || system.contains('ios');
  return switch (device.kind) {
    DeviceKind.rurana when system.contains('ios') => Icons.phone_iphone,
    DeviceKind.rurana => Icons.phone_android,
    DeviceKind.browser when mobile => Icons.smartphone,
    DeviceKind.browser => Icons.language,
    DeviceKind.dartClient => Icons.code,
    DeviceKind.other => Icons.devices_other,
  };
}
