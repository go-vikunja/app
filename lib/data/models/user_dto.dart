import 'package:flutter/cupertino.dart';
import 'package:vikunja_app/domain/entities/user.dart';
import 'package:vikunja_app/global.dart';

class UserSettingsDto {
  final int default_project_id;
  final bool discoverable_by_email,
      discoverable_by_name,
      email_reminders_enabled;
  final Map<String, dynamic>? frontend_settings;
  final String language;
  final String name;
  final bool overdue_tasks_reminders_enabled;
  final String overdue_tasks_reminders_time;
  final String timezone;
  final int week_start;

  UserSettingsDto({
    this.default_project_id = 0,
    this.discoverable_by_email = false,
    this.discoverable_by_name = false,
    this.email_reminders_enabled = false,
    this.frontend_settings = null,
    this.language = '',
    this.name = '',
    this.overdue_tasks_reminders_enabled = false,
    this.overdue_tasks_reminders_time = '',
    this.timezone = '',
    this.week_start = 0,
  });

  UserSettingsDto.fromJson(Map<String, dynamic> json)
      : default_project_id = json['default_project_id'],
        discoverable_by_email = json['discoverable_by_email'],
        discoverable_by_name = json['discoverable_by_name'],
        email_reminders_enabled = json['email_reminders_enabled'],
        frontend_settings = json['frontend_settings'],
        language = json['language'],
        name = json['name'],
        overdue_tasks_reminders_enabled =
            json['overdue_tasks_reminders_enabled'],
        overdue_tasks_reminders_time = json['overdue_tasks_reminders_time'],
        timezone = json['timezone'],
        week_start = json['week_start'];

  toJson() => {
        'default_project_id': default_project_id,
        'discoverable_by_email': discoverable_by_email,
        'discoverable_by_name': discoverable_by_name,
        'email_reminders_enabled': email_reminders_enabled,
        'frontend_settings': frontend_settings,
        'language': language,
        'name': name,
        'overdue_tasks_reminders_enabled': overdue_tasks_reminders_enabled,
        'overdue_tasks_reminders_time': overdue_tasks_reminders_time,
        'timezone': timezone,
        'week_start': week_start,
      };

  UserSettings toDomain() => UserSettings(
        default_project_id: default_project_id,
        discoverable_by_email: discoverable_by_email,
        discoverable_by_name: discoverable_by_name,
        email_reminders_enabled: email_reminders_enabled,
        frontend_settings: frontend_settings,
        language: language,
        name: name,
        overdue_tasks_reminders_enabled: overdue_tasks_reminders_enabled,
        overdue_tasks_reminders_time: overdue_tasks_reminders_time,
        timezone: timezone,
        week_start: week_start,
      );

  static UserSettingsDto fromDomain(UserSettings u) => UserSettingsDto(
        default_project_id: u.default_project_id,
        discoverable_by_email: u.discoverable_by_email,
        discoverable_by_name: u.discoverable_by_name,
        email_reminders_enabled: u.email_reminders_enabled,
        frontend_settings: u.frontend_settings,
        language: u.language,
        name: u.name,
        overdue_tasks_reminders_enabled: u.overdue_tasks_reminders_enabled,
        overdue_tasks_reminders_time: u.overdue_tasks_reminders_time,
        timezone: u.timezone,
        week_start: u.week_start,
      );

  UserSettingsDto copyWith({
    int? default_project_id,
    bool? discoverable_by_email,
    bool? discoverable_by_name,
    bool? email_reminders_enabled,
    Map<String, dynamic>? frontend_settings,
    String? language,
    String? name,
    bool? overdue_tasks_reminders_enabled,
    String? overdue_tasks_reminders_time,
    String? timezone,
    int? week_start,
  }) {
    return UserSettingsDto(
      default_project_id: default_project_id ?? this.default_project_id,
      discoverable_by_email:
          discoverable_by_email ?? this.discoverable_by_email,
      discoverable_by_name: discoverable_by_name ?? this.discoverable_by_name,
      email_reminders_enabled:
          email_reminders_enabled ?? this.email_reminders_enabled,
      frontend_settings: frontend_settings ?? this.frontend_settings,
      language: language ?? this.language,
      name: name ?? this.name,
      overdue_tasks_reminders_enabled: overdue_tasks_reminders_enabled ??
          this.overdue_tasks_reminders_enabled,
      overdue_tasks_reminders_time:
          overdue_tasks_reminders_time ?? this.overdue_tasks_reminders_time,
      timezone: timezone ?? this.timezone,
      week_start: week_start ?? this.week_start,
    );
  }
}

class UserDto {
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
  })  : this.created = created ?? DateTime.now(),
        this.updated = updated ?? DateTime.now();

  UserDto.fromJson(Map<String, dynamic> json)
      : id = json.containsKey('id') ? json['id'] : 0,
        name = json.containsKey('name') ? json['name'] : '',
        username = json['username'],
        created = DateTime.parse(json['created']),
        updated = DateTime.parse(json['updated']) {
    if (json.containsKey('settings')) {
      this.settings = UserSettingsDto.fromJson(json['settings']);
    }
    ;
  }

  toJSON() => {
        'id': id,
        'name': name,
        'username': username,
        'created': created.toUtc().toIso8601String(),
        'updated': updated.toUtc().toIso8601String(),
        'user_settings': settings?.toJson(),
      };

  User toDomain() => User(
      id: id,
      name: name,
      username: username,
      created: created,
      updated: updated,
      settings: settings?.toDomain());

  static UserDto fromDomain(User u) => UserDto(
      id: u.id,
      name: u.name,
      username: u.username,
      created: u.created,
      updated: u.updated,
      settings:
          u.settings != null ? UserSettingsDto.fromDomain(u.settings!) : null);

  String avatarUrl(BuildContext context) {
    return VikunjaGlobal.of(context).client.base + "/avatar/${this.username}";
  }
}

class UserTokenPairDto {
  final UserDto? user;
  final String? token;
  final int error;
  final String errorString;
  UserTokenPairDto(this.user, this.token,
      {this.error = 0, this.errorString = ""});

  UserTokenPair toDomain() {
    return UserTokenPair(user?.toDomain(), token,
        error: error, errorString: errorString);
  }

  static UserTokenPairDto fromDomain(UserTokenPair u) => UserTokenPairDto(
      u.user != null ? UserDto.fromDomain(u.user!) : null, u.token,
      error: u.error, errorString: u.errorString);
}

class BaseTokenPairDto {
  final String base;
  final String token;
  BaseTokenPairDto(this.base, this.token);

  BaseTokenPair toDomain() => BaseTokenPair(base, token);

  static BaseTokenPairDto fromDomain(BaseTokenPair b) =>
      BaseTokenPairDto(b.base, b.token);
}
