class UserSettings {
  int defaultProjectId;
  final bool discoverableByEmail, discoverableByName, emailRemindersEnabled;
  final Map<String, dynamic>? frontendSettings;
  final String language;
  final String name;
  final bool overdueTasksRemindersEnabled;
  final String overdueTasksRemindersTime;
  final String timezone;
  final int weekStart;

  UserSettings({
    this.defaultProjectId = 0,
    this.discoverableByEmail = false,
    this.discoverableByName = false,
    this.emailRemindersEnabled = false,
    this.frontendSettings,
    this.language = '',
    this.name = '',
    this.overdueTasksRemindersEnabled = false,
    this.overdueTasksRemindersTime = '',
    this.timezone = '',
    this.weekStart = 0,
  });

  UserSettings copyWith({
    int? defaultProjectId,
    bool? discoverableByEmail,
    bool? discoverableByName,
    bool? emailRemindersEnabled,
    Map<String, dynamic>? frontendSettings,
    String? language,
    String? name,
    bool? overdueTasksRemindersEnabled,
    String? overdueTasksRemindersTime,
    String? timezone,
    int? weekStart,
  }) {
    return UserSettings(
      defaultProjectId: defaultProjectId ?? this.defaultProjectId,
      discoverableByEmail: discoverableByEmail ?? this.discoverableByEmail,
      discoverableByName: discoverableByName ?? this.discoverableByName,
      emailRemindersEnabled:
          emailRemindersEnabled ?? this.emailRemindersEnabled,
      frontendSettings: frontendSettings ?? this.frontendSettings,
      language: language ?? this.language,
      name: name ?? this.name,
      overdueTasksRemindersEnabled:
          overdueTasksRemindersEnabled ?? this.overdueTasksRemindersEnabled,
      overdueTasksRemindersTime:
          overdueTasksRemindersTime ?? this.overdueTasksRemindersTime,
      timezone: timezone ?? this.timezone,
      weekStart: weekStart ?? this.weekStart,
    );
  }
}

class User {
  final int id;
  final String name, username;
  final DateTime created, updated;
  UserSettings? settings;

  User({
    this.id = 0,
    this.name = '',
    required this.username,
    DateTime? created,
    DateTime? updated,
    this.settings,
  }) : created = created ?? DateTime.now(),
       updated = updated ?? DateTime.now();

  String avatarUrl(String baseUrl) {
    return "$baseUrl/avatar/$username";
  }
}

class UserToken {
  final String token;
  final int error;
  final String errorString;

  UserToken(this.token, {this.error = 0, this.errorString = ""});
}
