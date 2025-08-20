import 'package:vikunja_app/core/theming/theme_mode.dart';
import 'package:vikunja_app/data/data_sources/settings_data_source.dart';
import 'package:vikunja_app/domain/repositories/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  final SettingsDatasource _datasource;

  SettingsRepositoryImpl(this._datasource);

  @override
  Future<bool> getIgnoreCertificates() {
    return _datasource.getIgnoreCertificates();
  }

  @override
  Future<void> setIgnoreCertificates(bool value) {
    return _datasource.setIgnoreCertificates(value);
  }

  @override
  Future<bool> getSentryEnabled() {
    return _datasource.getSentryEnabled();
  }

  @override
  Future<void> setSentryEnabled(bool value) {
    return _datasource.setSentryEnabled(value);
  }

  @override
  Future<bool> getVersionNotifications() {
    return _datasource.getVersionNotifications();
  }

  @override
  Future<void> setVersionNotifications(bool value) {
    return _datasource.setVersionNotifications(value);
  }

  @override
  Future<int> getRefreshInterval() {
    return _datasource.getRefreshInterval();
  }

  @override
  Future<void> setRefreshInterval(int minutes) {
    return _datasource.setRefreshInterval(minutes);
  }

  @override
  Future<FlutterThemeMode> getThemeMode() async {
    return _datasource.getThemeMode();
  }

  @override
  Future<void> setThemeMode(FlutterThemeMode newMode) async {
    await _datasource.setThemeMode(newMode);
  }

  @override
  Future<void> setDynamicColors(bool dynamicColors) async {
    await _datasource.setDynamicColors(dynamicColors);
  }

  @override
  Future<bool> getDynamicColors() async {
    return _datasource.getDynamicColors();
  }

  @override
  Future<bool> getLandingPageOnlyDueDateTasks() {
    return _datasource.getLandingPageOnlyDueDateTasks();
  }

  @override
  Future<void> setLandingPageOnlyDueDateTasks(bool value) {
    return _datasource.setLandingPageOnlyDueDateTasks(value);
  }

  @override
  Future<bool> getDisplayDoneTasks(int projectId) async {
    return _datasource.getDisplayDoneTasks(projectId);
  }

  @override
  Future<void> setDisplayDoneTasks(int projectId, bool value) {
    return _datasource.setDisplayDoneTasks(projectId, value);
  }

  @override
  Future<List<String>> getPastServers() async {
    return _datasource.getPastServers();
  }

  @override
  Future<void> setPastServers(List<String> server) {
    return _datasource.setPastServers(server);
  }

  @override
  Future<bool> getSentryDialogShown() {
    return _datasource.getSentryDialogShown();
  }

  @override
  Future<void> setSentryDialogShown(bool value) {
    return _datasource.setSentryDialogShown(value);
  }

  @override
  Future<String?> getServer() {
    return _datasource.getServer();
  }

  @override
  Future<String?> getUserToken() {
    return _datasource.getUserToken();
  }

  @override
  Future<void> saveServer(String? server) {
    return _datasource.saveServer(server);
  }

  @override
  Future<void> saveUserToken(String? token) {
    return _datasource.saveUserToken(token);
  }
}
