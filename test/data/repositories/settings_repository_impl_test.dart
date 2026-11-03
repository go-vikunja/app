/// `SettingsRepositoryImpl` is pure pass-through. These tests check that each
/// method reaches the matching data-source method and returns its value —
/// nothing about storage keys or encodings, which
/// `test/data/data_sources/settings_data_source_test.dart` owns.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/theming/theme_mode.dart';
import 'package:vikunja_app/data/data_sources/settings_data_source.dart';
import 'package:vikunja_app/data/repositories/settings_repository_impl.dart';

/// Records the method name of every call and answers from public fields.
class _SpySettingsDatasource implements SettingsDatasource {
  final List<String> calls = [];

  bool boolValue = true;
  int intValue = 17;
  String? stringValue = 'value';
  FlutterThemeMode themeMode = FlutterThemeMode.dark;
  List<String> servers = ['https://a.example'];

  Future<T> _record<T>(String name, T value) {
    calls.add(name);
    return Future.value(value);
  }

  @override
  Future<bool> getIgnoreCertificates() =>
      _record('getIgnoreCertificates', boolValue);
  @override
  Future<void> setIgnoreCertificates(bool v) =>
      _record('setIgnoreCertificates', null);
  @override
  Future<bool> getSentryEnabled() => _record('getSentryEnabled', boolValue);
  @override
  Future<void> setSentryEnabled(bool v) => _record('setSentryEnabled', null);
  @override
  Future<bool> getVersionNotifications() =>
      _record('getVersionNotifications', boolValue);
  @override
  Future<void> setVersionNotifications(bool v) =>
      _record('setVersionNotifications', null);
  @override
  Future<int> getRefreshInterval() => _record('getRefreshInterval', intValue);
  @override
  Future<void> setRefreshInterval(int v) => _record('setRefreshInterval', null);
  @override
  Future<FlutterThemeMode> getThemeMode() => _record('getThemeMode', themeMode);
  @override
  Future<void> setThemeMode(FlutterThemeMode v) =>
      _record('setThemeMode', null);
  @override
  Future<void> setDynamicColors(bool v) => _record('setDynamicColors', null);
  @override
  Future<bool> getDynamicColors() => _record('getDynamicColors', boolValue);
  @override
  Future<bool> getLandingPageOnlyDueDateTasks() =>
      _record('getLandingPageOnlyDueDateTasks', boolValue);
  @override
  Future<void> setLandingPageOnlyDueDateTasks(bool v) =>
      _record('setLandingPageOnlyDueDateTasks', null);
  @override
  Future<bool> getDisplayDoneTasks(int projectId) =>
      _record('getDisplayDoneTasks:$projectId', boolValue);
  @override
  Future<void> setDisplayDoneTasks(int projectId, bool v) =>
      _record('setDisplayDoneTasks:$projectId', null);
  @override
  Future<List<String>> getPastServers() => _record('getPastServers', servers);
  @override
  Future<void> setPastServers(List<String> v) =>
      _record('setPastServers', null);
  @override
  Future<bool> getSentryDialogShown() =>
      _record('getSentryDialogShown', boolValue);
  @override
  Future<void> setSentryDialogShown(bool v) =>
      _record('setSentryDialogShown', null);
  @override
  Future<String?> getServer() => _record('getServer', stringValue);
  @override
  Future<void> saveServer(String? v) => _record('saveServer', null);
  @override
  Future<String?> getUserToken() => _record('getUserToken', stringValue);
  @override
  Future<void> saveUserToken(String? v) => _record('saveUserToken', null);
  @override
  Future<String?> getRefreshToken() => _record('getRefreshToken', stringValue);
  @override
  Future<void> saveRefreshToken(String? v) => _record('saveRefreshToken', null);
  @override
  Future<String?> getLocaleOverride() =>
      _record('getLocaleOverride', stringValue);
  @override
  Future<void> setLocaleOverride(String? v) =>
      _record('setLocaleOverride', null);

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _SpySettingsDatasource spy;
  late SettingsRepositoryImpl repository;

  setUp(() {
    spy = _SpySettingsDatasource();
    repository = SettingsRepositoryImpl(spy);
  });

  test('every getter returns the data source value', () async {
    expect(await repository.getIgnoreCertificates(), isTrue);
    expect(await repository.getSentryEnabled(), isTrue);
    expect(await repository.getVersionNotifications(), isTrue);
    expect(await repository.getRefreshInterval(), 17);
    expect(await repository.getThemeMode(), FlutterThemeMode.dark);
    expect(await repository.getDynamicColors(), isTrue);
    expect(await repository.getLandingPageOnlyDueDateTasks(), isTrue);
    expect(await repository.getDisplayDoneTasks(4), isTrue);
    expect(await repository.getPastServers(), ['https://a.example']);
    expect(await repository.getSentryDialogShown(), isTrue);
    expect(await repository.getServer(), 'value');
    expect(await repository.getUserToken(), 'value');
    expect(await repository.getRefreshToken(), 'value');
    expect(await repository.getLocaleOverride(), 'value');
  });

  test('every setter reaches the matching data source method', () async {
    await repository.setIgnoreCertificates(true);
    await repository.setSentryEnabled(true);
    await repository.setVersionNotifications(true);
    await repository.setRefreshInterval(5);
    await repository.setThemeMode(FlutterThemeMode.light);
    await repository.setDynamicColors(true);
    await repository.setLandingPageOnlyDueDateTasks(true);
    await repository.setDisplayDoneTasks(4, true);
    await repository.setPastServers(['https://b.example']);
    await repository.setSentryDialogShown(true);
    await repository.saveServer('https://b.example');
    await repository.saveUserToken('token');
    await repository.saveRefreshToken('refresh');
    await repository.setLocaleOverride('de');

    expect(spy.calls, [
      'setIgnoreCertificates',
      'setSentryEnabled',
      'setVersionNotifications',
      'setRefreshInterval',
      'setThemeMode',
      'setDynamicColors',
      'setLandingPageOnlyDueDateTasks',
      'setDisplayDoneTasks:4',
      'setPastServers',
      'setSentryDialogShown',
      'saveServer',
      'saveUserToken',
      'saveRefreshToken',
      'setLocaleOverride',
    ]);
  });

  test('getDisplayDoneTasks forwards the project id it was given', () async {
    await repository.getDisplayDoneTasks(42);

    expect(spy.calls, ['getDisplayDoneTasks:42']);
  });
}
