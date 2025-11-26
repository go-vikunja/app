import 'package:vikunja_app/core/theming/theme_mode.dart';

abstract class SettingsRepository {
  Future<bool> getIgnoreCertificates();

  Future<void> setIgnoreCertificates(bool value);

  Future<bool> getSentryEnabled();

  Future<void> setSentryEnabled(bool value);

  Future<bool> getVersionNotifications();

  Future<void> setVersionNotifications(bool value);

  Future<int> getRefreshInterval();

  Future<void> setRefreshInterval(int minutes);

  Future<FlutterThemeMode> getThemeMode();

  Future<void> setThemeMode(FlutterThemeMode newMode);

  Future<void> setDynamicColors(bool dynamicColors);

  Future<bool> getDynamicColors();

  Future<bool> getLandingPageOnlyDueDateTasks();

  Future<void> setLandingPageOnlyDueDateTasks(bool value);

  Future<bool> getDisplayDoneTasks(int projectId);

  Future<void> setDisplayDoneTasks(int projectId, bool value);

  Future<List<String>> getPastServers();

  Future<void> setPastServers(List<String> server);

  Future<bool> getSentryDialogShown();

  Future<void> setSentryDialogShown(bool value);

  Future<void> saveUserToken(String? token);

  Future<String?> getUserToken();

  Future<void> saveServer(String? server);

  Future<String?> getServer();

  // Locale override (null -> system default)
  Future<String?> getLocaleOverride();
  Future<void> setLocaleOverride(String? localeCode);
}
