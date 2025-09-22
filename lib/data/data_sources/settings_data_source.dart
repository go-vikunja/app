import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:vikunja_app/core/theming/theme_mode.dart';

class SettingsDatasource {
  final FlutterSecureStorage _storage;

  SettingsDatasource(this._storage);

  Future<bool> getIgnoreCertificates() {
    return _storage
        .read(key: "ignore-certificates")
        .then((value) => value == "1");
  }

  Future<void> setIgnoreCertificates(bool value) {
    return _storage.write(key: "ignore-certificates", value: value ? "1" : "0");
  }

  Future<bool> getSentryEnabled() {
    return _storage.read(key: "sentry-enabled").then((value) => value == "1");
  }

  Future<void> setSentryEnabled(bool value) {
    return _storage.write(key: "sentry-enabled", value: value ? "1" : "0");
  }

  Future<bool> getVersionNotifications() {
    return _storage
        .read(key: "get-version-notifications")
        .then((value) => value == "1");
  }

  Future<void> setVersionNotifications(bool value) {
    return _storage.write(
      key: "get-version-notifications",
      value: value ? "1" : "0",
    );
  }

  Future<int> getRefreshInterval() {
    return _storage
        .read(key: "workmanager-duration")
        .then((value) => int.tryParse(value ?? "0") ?? 0);
  }

  Future<void> setRefreshInterval(int minutes) {
    return _storage.write(
      key: "workmanager-duration",
      value: minutes.toString(),
    );
  }

  Future<FlutterThemeMode> getThemeMode() async {
    String? themeMode = await _storage.read(key: "theme_mode");
    if (themeMode == null) setThemeMode(FlutterThemeMode.system);
    switch (themeMode) {
      case "system":
        return FlutterThemeMode.system;
      case "light":
        return FlutterThemeMode.light;
      case "dark":
        return FlutterThemeMode.dark;
      default:
        return FlutterThemeMode.system;
    }
  }

  Future<void> setThemeMode(FlutterThemeMode newMode) async {
    await _storage.write(
      key: "theme_mode",
      value: newMode.toString().split('.').last,
    );
  }

  Future<void> setDynamicColors(bool dynamicColors) async {
    await _storage.write(
      key: "dynamic_colors",
      value: dynamicColors.toString(),
    );
  }

  Future<bool> getDynamicColors() async {
    String? dynamicColors = await _storage.read(key: "dynamic_colors");
    return dynamicColors == "true";
  }

  Future<bool> getLandingPageOnlyDueDateTasks() {
    return _storage
        .read(key: "landing-page-due-date-tasks")
        .then((value) => value == "1");
  }

  Future<void> setLandingPageOnlyDueDateTasks(bool value) {
    return _storage.write(
      key: "landing-page-due-date-tasks",
      value: value ? "1" : "0",
    );
  }

  Future<bool> getDisplayDoneTasks(int projectId) async {
    var value = await _storage.read(key: "display_done_tasks_list_$projectId");

    return value == "1";
  }

  Future<void> setDisplayDoneTasks(int projectId, bool value) {
    return _storage.write(
      key: "display_done_tasks_list_$projectId",
      value: value ? "1" : "0",
    );
  }

  Future<List<String>> getPastServers() async {
    String jsonString = await _storage.read(key: "recent-servers") ?? "[]";
    List<dynamic> server = jsonDecode(jsonString);
    return server.map((e) => e as String).toList();
  }

  Future<void> setPastServers(List<String> server) {
    return _storage.write(key: "recent-servers", value: jsonEncode(server));
  }

  Future<bool> getSentryDialogShown() {
    return _storage
        .read(key: "sentry-modal-shown")
        .then((value) => value == "1");
  }

  Future<void> setSentryDialogShown(bool value) {
    return _storage.write(key: "sentry-modal-shown", value: value ? "1" : "0");
  }

  Future<String?> getServer() {
    return _storage.read(key: "server-address");
  }

  Future<String?> getUserToken() {
    return _storage.read(key: "user-token");
  }

  Future<void> saveServer(String? server) {
    return _storage.write(key: "server-address", value: server);
  }

  Future<void> saveUserToken(String? token) {
    return _storage.write(key: "user-token", value: token);
  }
}
