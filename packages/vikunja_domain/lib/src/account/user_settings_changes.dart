import 'package:meta/meta.dart';
import 'package:vikunja_domain/src/account/user_settings.dart';
import 'package:vikunja_domain/src/project/project_view.dart';

/// A new value for a setting [UserSettings] holds as nullable; null in
/// [UserSettingsChanges] leaves the setting as it is.
@immutable
final class SettingChange<T extends Object> {
  const new set(T this.value);

  /// Back to unset: no default project, no saved filter on the Overview,
  /// the app's own date and time formats, the first view.
  const new clear() : value = null;

  final T? value;

  @override
  bool operator ==(Object other) =>
      other is SettingChange<T> && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value == null ? 'clear' : '$value';
}

/// The settings of one edit. Every null field is left as it is on the
/// server, together with everything [UserSettings] does not model.
@immutable
final class UserSettingsChanges {
  const new({
    this.name,
    this.emailRemindersEnabled,
    this.discoverableByName,
    this.discoverableByEmail,
    this.overdueTasksRemindersEnabled,
    this.overdueTasksRemindersTime,
    this.defaultProjectId,
    this.weekStart,
    this.timezone,
    this.language,
    this.quickAddMagicMode,
    this.quickAddDefaultReminders,
    this.filterIdUsedOnOverview,
    this.minimumPriority,
    this.commentSortOrder,
    this.dateDisplay,
    this.timeFormat,
    this.colorSchema,
    this.defaultViewKind,
  });

  /// Not checked by the server; an OIDC or LDAP sign-in overwrites it.
  final String? name;
  final bool? emailRemindersEnabled;
  final bool? discoverableByName;
  final bool? discoverableByEmail;
  final bool? overdueTasksRemindersEnabled;
  final ClockTime? overdueTasksRemindersTime;

  /// A project the user can write to that is not archived.
  final SettingChange<int>? defaultProjectId;

  /// 0 = Sunday … 6 = Saturday.
  final int? weekStart;

  /// An IANA name the server can load, case-sensitive; empty stores the
  /// server's default zone.
  final String? timezone;

  /// The server's language for emails; not checked by the server.
  final String? language;
  final QuickAddMagicMode? quickAddMagicMode;

  /// Relative to the due date, negative before it.
  final List<Duration>? quickAddDefaultReminders;

  /// A saved filter's pseudo project id (-2 or lower).
  final SettingChange<int>? filterIdUsedOnOverview;

  /// 1 (low) to 5 (do now).
  final int? minimumPriority;
  final CommentSortOrder? commentSortOrder;
  final SettingChange<DateDisplay>? dateDisplay;
  final SettingChange<TimeFormat>? timeFormat;
  final ColorSchema? colorSchema;
  final SettingChange<ProjectViewKind>? defaultViewKind;

  bool get isEmpty => this == const UserSettingsChanges();

  /// [settings] with these changes; an empty [timezone] stays empty here,
  /// where the server stores its own default zone.
  UserSettings applyTo(UserSettings settings) => settings.copyWith(
    name: name,
    emailRemindersEnabled: emailRemindersEnabled,
    discoverableByName: discoverableByName,
    discoverableByEmail: discoverableByEmail,
    overdueTasksRemindersEnabled: overdueTasksRemindersEnabled,
    overdueTasksRemindersTime: overdueTasksRemindersTime,
    defaultProjectId: switch (defaultProjectId) {
      null => settings.defaultProjectId,
      final change => change.value,
    },
    weekStart: weekStart,
    timezone: timezone,
    language: language,
    quickAddMagicMode: quickAddMagicMode,
    quickAddDefaultReminders: quickAddDefaultReminders,
    filterIdUsedOnOverview: switch (filterIdUsedOnOverview) {
      null => settings.filterIdUsedOnOverview,
      final change => change.value,
    },
    minimumPriority: minimumPriority,
    commentSortOrder: commentSortOrder,
    dateDisplay: switch (dateDisplay) {
      null => settings.dateDisplay,
      final change => change.value,
    },
    timeFormat: switch (timeFormat) {
      null => settings.timeFormat,
      final change => change.value,
    },
    colorSchema: colorSchema,
    defaultViewKind: switch (defaultViewKind) {
      null => settings.defaultViewKind,
      final change => change.value,
    },
  );

  @override
  bool operator ==(Object other) =>
      other is UserSettingsChanges &&
      other.name == name &&
      other.emailRemindersEnabled == emailRemindersEnabled &&
      other.discoverableByName == discoverableByName &&
      other.discoverableByEmail == discoverableByEmail &&
      other.overdueTasksRemindersEnabled == overdueTasksRemindersEnabled &&
      other.overdueTasksRemindersTime == overdueTasksRemindersTime &&
      other.defaultProjectId == defaultProjectId &&
      other.weekStart == weekStart &&
      other.timezone == timezone &&
      other.language == language &&
      other.quickAddMagicMode == quickAddMagicMode &&
      _sameReminders(other.quickAddDefaultReminders) &&
      other.filterIdUsedOnOverview == filterIdUsedOnOverview &&
      other.minimumPriority == minimumPriority &&
      other.commentSortOrder == commentSortOrder &&
      other.dateDisplay == dateDisplay &&
      other.timeFormat == timeFormat &&
      other.colorSchema == colorSchema &&
      other.defaultViewKind == defaultViewKind;

  @override
  int get hashCode => Object.hashAll([
    name,
    emailRemindersEnabled,
    discoverableByName,
    discoverableByEmail,
    overdueTasksRemindersEnabled,
    overdueTasksRemindersTime,
    defaultProjectId,
    weekStart,
    timezone,
    language,
    quickAddMagicMode,
    switch (quickAddDefaultReminders) {
      null => null,
      final reminders => Object.hashAll(reminders),
    },
    filterIdUsedOnOverview,
    minimumPriority,
    commentSortOrder,
    dateDisplay,
    timeFormat,
    colorSchema,
    defaultViewKind,
  ]);

  bool _sameReminders(List<Duration>? other) {
    final mine = quickAddDefaultReminders;
    if (mine == null || other == null) return mine == other;
    if (mine.length != other.length) return false;
    for (var i = 0; i < mine.length; i++) {
      if (mine[i] != other[i]) return false;
    }
    return true;
  }

  /// Names the fields set, without user text such as the name.
  @override
  String toString() {
    final fields = [
      if (name != null) 'name',
      if (emailRemindersEnabled != null)
        'emailRemindersEnabled: $emailRemindersEnabled',
      if (discoverableByName != null) 'discoverableByName: $discoverableByName',
      if (discoverableByEmail != null)
        'discoverableByEmail: $discoverableByEmail',
      if (overdueTasksRemindersEnabled != null)
        'overdueTasksRemindersEnabled: $overdueTasksRemindersEnabled',
      if (overdueTasksRemindersTime != null)
        'overdueTasksRemindersTime: ${overdueTasksRemindersTime!.wireName}',
      if (defaultProjectId != null) 'defaultProjectId: $defaultProjectId',
      if (weekStart != null) 'weekStart: $weekStart',
      if (timezone != null) 'timezone',
      if (language != null) 'language',
      if (quickAddMagicMode != null) 'quickAddMagicMode: $quickAddMagicMode',
      if (quickAddDefaultReminders != null) 'quickAddDefaultReminders',
      if (filterIdUsedOnOverview != null)
        'filterIdUsedOnOverview: $filterIdUsedOnOverview',
      if (minimumPriority != null) 'minimumPriority: $minimumPriority',
      if (commentSortOrder != null) 'commentSortOrder: $commentSortOrder',
      if (dateDisplay != null) 'dateDisplay: $dateDisplay',
      if (timeFormat != null) 'timeFormat: $timeFormat',
      if (colorSchema != null) 'colorSchema: $colorSchema',
      if (defaultViewKind != null) 'defaultViewKind: $defaultViewKind',
    ];
    return 'UserSettingsChanges(${fields.join(', ')})';
  }
}
