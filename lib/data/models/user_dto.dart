import 'package:vikunja_app/data/models/dto.dart';
import 'package:vikunja_app/domain/entities/user.dart';

class UserSettingsDto extends Dto<UserSettings> {
  final int defaultProjectId;
  final bool discoverableByEmail, discoverableByName, emailRemindersEnabled;
  final Map<String, dynamic>? frontendSettings;
  final String language;
  final String name;
  final bool overdueTasksRemindersEnabled;
  final String overdueTasksRemindersTime;
  final String timezone;
  final int weekStart;

  UserSettingsDto({
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

  UserSettingsDto.fromJson(Map<String, dynamic> json)
    : defaultProjectId = json['default_project_id'],
      discoverableByEmail = json['discoverable_by_email'],
      discoverableByName = json['discoverable_by_name'],
      emailRemindersEnabled = json['email_reminders_enabled'],
      frontendSettings = json['frontend_settings'],
      language = json['language'],
      name = json['name'],
      overdueTasksRemindersEnabled = json['overdue_tasks_reminders_enabled'],
      overdueTasksRemindersTime = json['overdue_tasks_reminders_time'],
      timezone = json['timezone'],
      weekStart = json['week_start'];

  Map<String, Object?> toJson() => {
    'default_project_id': defaultProjectId,
    'discoverable_by_email': discoverableByEmail,
    'discoverable_by_name': discoverableByName,
    'email_reminders_enabled': emailRemindersEnabled,
    'frontend_settings': frontendSettings,
    'language': language,
    'name': name,
    'overdue_tasks_reminders_enabled': overdueTasksRemindersEnabled,
    'overdue_tasks_reminders_time': overdueTasksRemindersTime,
    'timezone': timezone,
    'week_start': weekStart,
  };

  @override
  UserSettings toDomain() => UserSettings(
    default_project_id: defaultProjectId,
    discoverable_by_email: discoverableByEmail,
    discoverable_by_name: discoverableByName,
    email_reminders_enabled: emailRemindersEnabled,
    frontend_settings: frontendSettings,
    language: language,
    name: name,
    overdue_tasks_reminders_enabled: overdueTasksRemindersEnabled,
    overdue_tasks_reminders_time: overdueTasksRemindersTime,
    timezone: timezone,
    week_start: weekStart,
  );

  static UserSettingsDto fromDomain(UserSettings u) => UserSettingsDto(
    defaultProjectId: u.default_project_id,
    discoverableByEmail: u.discoverable_by_email,
    discoverableByName: u.discoverable_by_name,
    emailRemindersEnabled: u.email_reminders_enabled,
    frontendSettings: u.frontend_settings,
    language: u.language,
    name: u.name,
    overdueTasksRemindersEnabled: u.overdue_tasks_reminders_enabled,
    overdueTasksRemindersTime: u.overdue_tasks_reminders_time,
    timezone: u.timezone,
    weekStart: u.week_start,
  );
}

class UserDto extends Dto<User> {
  final int id;
  final String name, username;
  final DateTime created, updated;
  UserSettingsDto? settings;

  UserDto({
    this.id = 0,
    this.name = '',
    required this.username,
    DateTime? created,
    DateTime? updated,
    this.settings,
  }) : created = created ?? DateTime.now(),
       updated = updated ?? DateTime.now();

  UserDto.fromJson(Map<String, dynamic> json)
    : id = json.containsKey('id') ? json['id'] : 0,
      name = json.containsKey('name') ? json['name'] : '',
      username = json['username'],
      created = DateTime.parse(json['created']),
      updated = DateTime.parse(json['updated']) {
    if (json.containsKey('settings')) {
      settings = UserSettingsDto.fromJson(json['settings']);
    }
  }

  Map<String, dynamic> toJSON() => {
    'id': id,
    'name': name,
    'username': username,
    'created': created.toUtc().toIso8601String(),
    'updated': updated.toUtc().toIso8601String(),
    'user_settings': settings?.toJson(),
  };

  @override
  User toDomain() => User(
    id: id,
    name: name,
    username: username,
    created: created,
    updated: updated,
    settings: settings?.toDomain(),
  );

  static UserDto fromDomain(User u) => UserDto(
    id: u.id,
    name: u.name,
    username: u.username,
    created: u.created,
    updated: u.updated,
    settings: u.settings != null
        ? UserSettingsDto.fromDomain(u.settings!)
        : null,
  );
}

class UserTokenDto extends Dto<UserToken> {
  final String token;

  UserTokenDto(this.token);

  @override
  UserToken toDomain() {
    return UserToken(token);
  }
}
