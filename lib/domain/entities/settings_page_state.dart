import 'package:vikunja_app/core/theming/theme_mode.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/entities/user.dart';
import 'package:vikunja_app/domain/entities/version.dart';

class SettingsPageState {
  User user;
  List<Project> projects;

  bool ignoreCertificates;
  bool sentryEnabled;
  bool versionNotifications;

  int refreshInterval;

  FlutterThemeMode themeMode;
  bool dynamicColors;

  Version? currentVersion;

  SettingsPageState(
    this.user,
    this.projects,
    this.ignoreCertificates,
    this.sentryEnabled,
    this.versionNotifications,
    this.refreshInterval,
    this.themeMode,
    this.dynamicColors,
    this.currentVersion,
  );
}
