import 'package:vikunja_app/core/services.dart';
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
  void setIgnoreCertificates(bool value) {
    _datasource.setIgnoreCertificates(value);
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
  void setVersionNotifications(bool value) {
    _datasource.setVersionNotifications(value);
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
}
