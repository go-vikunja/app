import 'package:vikunja_app/core/services.dart';

abstract class SettingsRepository {
  Future<bool> getIgnoreCertificates();

  void setIgnoreCertificates(bool value);

  Future<bool> getSentryEnabled();

  Future<void> setSentryEnabled(bool value);

  Future<bool> getVersionNotifications();

  void setVersionNotifications(bool value);

  Future<int> getRefreshInterval();

  Future<void> setRefreshInterval(int minutes);

  Future<FlutterThemeMode> getThemeMode();

  Future<void> setThemeMode(FlutterThemeMode newMode);

  Future<void> setDynamicColors(bool dynamicColors);

  Future<bool> getDynamicColors();

  Future<bool> getLandingPageOnlyDueDateTasks();

  Future<void> setLandingPageOnlyDueDateTasks(bool value);
}
