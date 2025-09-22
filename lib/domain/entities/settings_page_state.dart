import 'package:vikunja_app/core/theming/theme_mode.dart';

class SettingsPageState {
  bool ignoreCertificates;
  bool sentryEnabled;
  bool versionNotifications;

  int refreshInterval;

  FlutterThemeMode themeMode;
  bool dynamicColors;

  String currentVersion;

  SettingsPageState(
    this.ignoreCertificates,
    this.sentryEnabled,
    this.versionNotifications,
    this.refreshInterval,
    this.themeMode,
    this.dynamicColors,
    this.currentVersion,
  );
}
