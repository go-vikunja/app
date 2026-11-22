import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/text/project_titles.dart';
import 'package:vikunja_mobile/core/text/server_address_display.dart';
import 'package:vikunja_mobile/features/account_settings/application/server_languages.dart';
import 'package:vikunja_mobile/features/account_settings/application/time_zone_choices.dart';
import 'package:vikunja_mobile/features/account_settings/application/web_settings_pages.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_deletion.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_failure.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_rows.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/avatar_labels.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/default_project_picker.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/searchable_option_sheet.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/web_password_note.dart';
import 'package:vikunja_mobile/features/common/presentation/option_sheet.dart';
import 'package:vikunja_mobile/features/common/presentation/settings_section.dart';
import 'package:vikunja_mobile/features/common/presentation/user_avatar.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/view_labels.dart';
import 'package:vikunja_mobile/features/tasks/application/display_settings.dart';
import 'package:vikunja_mobile/features/tasks/presentation/moment_formatter.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/time_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_formatting.dart';

typedef SaveSetting = void Function(
  AccountSettingsField field,
  UserSettingsChanges changes,
);

typedef ChooseSetting = void Function<T extends Object>(
  AccountSettingsField field, {
  required String title,
  required List<SheetOption<T>> options,
  required UserSettingsChanges Function(T value) changes,
});

/// What the sections that change a setting share.
@immutable
final class SettingsEditing {
  const new({
    required this.settings,
    required this.errors,
    required this.canChange,
    required this.onSave,
    required this.onChoose,
  });

  /// With the change being saved applied.
  final UserSettings settings;
  final Map<AccountSettingsField, String> errors;
  final bool canChange;
  final SaveSetting onSave;
  final ChooseSetting onChoose;

  VoidCallback? whenChangeable(VoidCallback action) =>
      canChange ? action : null;
}

/// The notes above the sections: a scheduled deletion, where the settings
/// are kept, and why they cannot be changed right now.
List<Widget> accountSettingsNotes({
  required AppLocalizations l10n,
  required RegisteredAccount entry,
  required UserProfile? profile,
  required bool isLocalUser,
  required bool offline,
  required VoidCallback onRetry,
  required VoidCallback? onSignInAgain,
  required ValueChanged<WebSettingsPage> onOpenWeb,
}) => [
  if (profile?.deletionScheduledAt case final scheduledAt?)
    DeletionScheduledNote(
      scheduledAt: scheduledAt,
      isLocalUser: isLocalUser,
      accountLockout: entry.connection.capabilities.has(
        Capability.accountLockout,
      ),
      onCancel: () => onOpenWeb(WebSettingsPage.deletion),
    ),
  SettingsNote(
    text: l10n.accountSettingsIntro(displayHost(entry.connection.rootUri)),
  ),
  if (entry.account.needsReauth)
    SettingsNote(
      text: l10n.accountSettingsSignInAgain,
      icon: Icons.lock_clock_outlined,
      emphasized: true,
      action: TextButton(
        onPressed: onSignInAgain,
        child: Text(l10n.reauthAction),
      ),
    )
  else if (offline)
    SettingsNote(
      text: l10n.accountSettingsOffline,
      icon: Icons.cloud_off_outlined,
      emphasized: true,
      action: TextButton(onPressed: onRetry, child: Text(l10n.retry)),
    ),
];

Widget profileSection({
  required BuildContext context,
  required AppLocalizations l10n,
  required RegisteredAccount entry,
  required AvatarProvider? avatarProvider,
  required UserProfile? profile,
  required bool isLocalUser,
  required String provider,
  required TextEditingController nameController,
  required bool nameDirty,
  required bool canChange,
  required String? error,
  required VoidCallback onNameChanged,
  required VoidCallback onSaveName,
}) {
  final account = entry.account;
  return SettingsSection(
    title: l10n.accountSettingsProfile,
    children: [
      ListTile(
        leading: UserAvatar(
          user: User(
            id: account.userId,
            username: account.username,
            name: account.displayName,
          ),
          radius: 20,
          accountId: entry.id,
          primary: true,
        ),
        title: Text(l10n.accountSettingsAvatar),
        subtitle: switch (avatarProvider) {
          final provider? => Text(avatarProviderLabel(l10n, provider)),
          null => null,
        },
        trailing: const Icon(Icons.chevron_right),
        onTap: () =>
            unawaited(GoRouter.of(context).push(AppRoutes.accountAvatar)),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: TextField(
          controller: nameController,
          enabled: canChange && isLocalUser,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: l10n.accountSettingsName,
            helperText: switch (profile) {
              null => l10n.accountSettingsWaitingForProfile,
              _ when isLocalUser => l10n.accountSettingsNameHelp(
                account.username,
              ),
              _ => l10n.accountSettingsNameManaged(provider),
            },
            helperMaxLines: 4,
            errorText: error,
            errorMaxLines: 4,
            suffixIcon: nameDirty && canChange
                ? IconButton(
                    onPressed: onSaveName,
                    tooltip: l10n.accountSettingsNameSave,
                    icon: const Icon(Icons.check),
                  )
                : null,
          ),
          onChanged: (_) => onNameChanged(),
          onSubmitted: (_) => onSaveName(),
        ),
      ),
    ],
  );
}

/// Password and email on the web's pages for a local account; the sign-in
/// provider's name for any other.
Widget signInSection({
  required AppLocalizations l10n,
  required ServerConnection connection,
  required UserProfile? profile,
  required bool isLocalUser,
  required String provider,
  required ValueChanged<WebSettingsPage> onOpenWeb,
}) => SettingsSection(
  title: l10n.accountSettingsSignIn,
  children: [
    if (profile == null)
      SettingsNote(
        text: l10n.accountSettingsWaitingForProfile,
        icon: Icons.hourglass_empty,
      )
    else if (isLocalUser) ...[
      ListTile(
        leading: const Icon(Icons.password),
        title: Text(l10n.accountSettingsChangePassword),
        subtitle: Text(l10n.accountSettingsChangePasswordHint),
        trailing: const Icon(Icons.open_in_new),
        onTap: () => onOpenWeb(WebSettingsPage.password),
      ),
      ListTile(
        leading: const Icon(Icons.alternate_email),
        title: Text(l10n.accountSettingsChangeEmail),
        subtitle: Text(switch (profile.pendingEmail) {
          final email? when email.isNotEmpty =>
            l10n.accountSettingsPendingEmail(email),
          _ => l10n.accountSettingsOpensWeb,
        }),
        trailing: const Icon(Icons.open_in_new),
        onTap: () => onOpenWeb(WebSettingsPage.email),
      ),
      if (connection.capabilities.has(Capability.accountLockout))
        SettingsNote(
          text: webAsksPasswordNote(l10n, accountLockout: true),
          icon: Icons.lock_outline,
        ),
    ] else
      ListTile(
        leading: const Icon(Icons.verified_user_outlined),
        title: Text(l10n.accountSettingsManagedBySignInNamed(provider)),
      ),
  ],
);

Widget defaultsSection({
  required BuildContext context,
  required AppLocalizations l10n,
  required SettingsEditing editing,
  required List<Project> projects,
  required List<SavedFilterRef> savedFilters,
}) {
  final SettingsEditing(:settings, :errors, :onSave, :onChoose) = editing;
  String weekdayName(int day) =>
      intl.DateFormat.EEEE(l10n.localeName).format(DateTime(2023, 1, 1 + day));

  return SettingsSection(
    title: l10n.accountSettingsDefaults,
    children: [
      SettingChoiceTile(
        leading: const Icon(Icons.folder_outlined),
        title: l10n.accountSettingsDefaultProject,
        value: defaultProjectLabel(l10n, settings.defaultProjectId, projects),
        error: errors[AccountSettingsField.defaultProject],
        onTap: editing.whenChangeable(() async {
          final picked = await pickDefaultProject(
            context,
            projects: projects,
            selectedId: settings.defaultProjectId,
          );
          if (picked == null || picked == (settings.defaultProjectId ?? 0)) {
            return;
          }
          onSave(
            AccountSettingsField.defaultProject,
            UserSettingsChanges(
              defaultProjectId: picked == 0
                  ? const SettingChange.clear()
                  : SettingChange.set(picked),
            ),
          );
        }),
      ),
      SettingChoiceTile(
        leading: const Icon(Icons.view_agenda_outlined),
        title: l10n.accountSettingsDefaultView,
        value: _defaultViewLabel(l10n, settings.defaultViewKind),
        error: errors[AccountSettingsField.defaultView],
        onTap: editing.whenChangeable(
          () => onChoose<SettingChange<ProjectViewKind>>(
            AccountSettingsField.defaultView,
            title: l10n.accountSettingsDefaultView,
            options: [
              SheetOption(
                value: const SettingChange.clear(),
                label: l10n.accountSettingsDefaultViewFirst,
                selected: settings.defaultViewKind == null,
              ),
              for (final kind in ProjectViewKind.values)
                SheetOption(
                  value: SettingChange.set(kind),
                  label: viewKindLabel(l10n, kind),
                  selected: settings.defaultViewKind == kind,
                ),
            ],
            changes: (value) => UserSettingsChanges(defaultViewKind: value),
          ),
        ),
      ),
      SettingChoiceTile(
        leading: const Icon(Icons.auto_awesome_outlined),
        title: l10n.accountSettingsQuickAddMagic,
        value: _magicModeLabel(l10n, settings.quickAddMagicMode),
        error: errors[AccountSettingsField.quickAddMagic],
        onTap: editing.whenChangeable(
          () => onChoose<QuickAddMagicMode>(
            AccountSettingsField.quickAddMagic,
            title: l10n.accountSettingsQuickAddMagic,
            options: [
              for (final mode in QuickAddMagicMode.values)
                SheetOption(
                  value: mode,
                  label: _magicModeLabel(l10n, mode),
                  selected: settings.quickAddMagicMode == mode,
                ),
            ],
            changes: (value) => UserSettingsChanges(quickAddMagicMode: value),
          ),
        ),
      ),
      SettingChoiceTile(
        leading: const Icon(Icons.flag_outlined),
        title: l10n.accountSettingsMinimumPriority,
        value: priorityLabel(
          l10n,
          TaskPriority.fromValue(settings.effectiveMinimumPriority),
        ),
        error: errors[AccountSettingsField.minimumPriority],
        onTap: editing.whenChangeable(
          () => onChoose<TaskPriority>(
            AccountSettingsField.minimumPriority,
            title: l10n.accountSettingsMinimumPriority,
            options: [
              for (final priority in TaskPriority.values)
                if (priority != TaskPriority.unset)
                  SheetOption(
                    value: priority,
                    label: priorityLabel(l10n, priority),
                    selected:
                        settings.effectiveMinimumPriority == priority.value,
                  ),
            ],
            changes: (value) =>
                UserSettingsChanges(minimumPriority: value.value),
          ),
        ),
      ),
      SettingChoiceTile(
        leading: const Icon(Icons.filter_alt_outlined),
        title: l10n.accountSettingsOverviewFilter,
        value: _overviewFilterLabel(
          l10n,
          settings.filterIdUsedOnOverview,
          savedFilters,
        ),
        error: errors[AccountSettingsField.overviewFilter],
        onTap: editing.whenChangeable(
          () => onChoose<SettingChange<int>>(
            AccountSettingsField.overviewFilter,
            title: l10n.accountSettingsOverviewFilter,
            options: [
              SheetOption(
                value: const SettingChange.clear(),
                label: l10n.accountSettingsOverviewFilterNone,
                selected: settings.filterIdUsedOnOverview == null,
              ),
              for (final filter in savedFilters)
                SheetOption(
                  value: SettingChange.set(filter.projectId),
                  label: projectDisplayTitle(
                    l10n,
                    filter.title,
                    projectId: filter.projectId,
                  ),
                  selected: settings.filterIdUsedOnOverview == filter.projectId,
                ),
            ],
            changes: (value) =>
                UserSettingsChanges(filterIdUsedOnOverview: value),
          ),
        ),
      ),
      SettingChoiceTile(
        leading: const Icon(Icons.date_range_outlined),
        title: l10n.accountSettingsWeekStart,
        value: weekdayName(settings.weekStart.clamp(0, 6)),
        error: errors[AccountSettingsField.weekStart],
        onTap: editing.whenChangeable(
          () => onChoose<int>(
            AccountSettingsField.weekStart,
            title: l10n.accountSettingsWeekStart,
            options: [
              for (var day = 0; day < 7; day++)
                SheetOption(
                  value: day,
                  label: weekdayName(day),
                  selected: settings.weekStart == day,
                ),
            ],
            changes: (value) => UserSettingsChanges(weekStart: value),
          ),
        ),
      ),
    ],
  );
}

Widget timeAndLanguageSection({
  required BuildContext context,
  required AppLocalizations l10n,
  required SettingsEditing editing,
  required MomentFormatter formatter,
  required DateTime now,
}) {
  final SettingsEditing(:settings, :errors, :onSave, :onChoose) = editing;
  return SettingsSection(
    title: l10n.accountSettingsTimeAndLanguage,
    children: [
      SettingChoiceTile(
        leading: const Icon(Icons.public_outlined),
        title: l10n.accountSettingsTimezone,
        value: settings.timezone.isEmpty
            ? l10n.accountSettingsTimezoneServerDefault
            : settings.timezone.replaceAll('_', ' '),
        help: l10n.accountSettingsTimezoneHelp,
        error: errors[AccountSettingsField.timezone],
        onTap: editing.whenChangeable(() async {
          final picked = await _pickTimeZone(context, settings.timezone);
          if (picked == null || picked == settings.timezone) return;
          onSave(
            AccountSettingsField.timezone,
            UserSettingsChanges(timezone: picked),
          );
        }),
      ),
      SettingChoiceTile(
        leading: const Icon(Icons.translate_outlined),
        title: l10n.accountSettingsLanguage,
        value: switch (settings.language) {
          '' => l10n.accountSettingsLanguageNotSet,
          final code => serverLanguageOf(code)?.name ?? code,
        },
        help: l10n.accountSettingsLanguageHelp,
        error: errors[AccountSettingsField.language],
        onTap: editing.whenChangeable(() async {
          final picked = await _pickLanguage(context, settings.language);
          if (picked == null || picked == settings.language) return;
          onSave(
            AccountSettingsField.language,
            UserSettingsChanges(language: picked),
          );
        }),
      ),
      SettingChoiceTile(
        leading: const Icon(Icons.calendar_today_outlined),
        title: l10n.accountSettingsDateDisplay,
        value: l10n.accountSettingsDateExample(switch (settings.dateDisplay) {
          DateDisplay.relative => formatter.relative(
            now.add(const Duration(days: 3)),
            now: now,
          ),
          _ => formatter.absolute(now),
        }),
        error: errors[AccountSettingsField.dateDisplay],
        onTap: editing.whenChangeable(
          () => onChoose<SettingChange<DateDisplay>>(
            AccountSettingsField.dateDisplay,
            title: l10n.accountSettingsDateDisplay,
            options: [
              SheetOption(
                value: const SettingChange.clear(),
                label: l10n.accountSettingsDateDisplayDevice,
                selected: settings.dateDisplay == null,
              ),
              for (final displayOption in DateDisplay.values)
                SheetOption(
                  value: SettingChange.set(displayOption),
                  label: _dateDisplayLabel(l10n, displayOption, now),
                  selected: settings.dateDisplay == displayOption,
                ),
            ],
            changes: (value) => UserSettingsChanges(dateDisplay: value),
          ),
        ),
      ),
      SettingChoiceTile(
        leading: const Icon(Icons.schedule_outlined),
        title: l10n.accountSettingsTimeFormat,
        value: _timeFormatLabel(l10n, settings.timeFormat, now),
        error: errors[AccountSettingsField.timeFormat],
        onTap: editing.whenChangeable(
          () => onChoose<SettingChange<TimeFormat>>(
            AccountSettingsField.timeFormat,
            title: l10n.accountSettingsTimeFormat,
            options: [
              SheetOption(
                value: const SettingChange.clear(),
                label: l10n.accountSettingsTimeFormatDevice,
                selected: settings.timeFormat == null,
              ),
              for (final format in TimeFormat.values)
                SheetOption(
                  value: SettingChange.set(format),
                  label: _timeFormatLabel(l10n, format, now),
                  selected: settings.timeFormat == format,
                ),
            ],
            changes: (value) => UserSettingsChanges(timeFormat: value),
          ),
        ),
      ),
    ],
  );
}

Widget emailNotificationsSection({
  required BuildContext context,
  required AppLocalizations l10n,
  required ServerConnection connection,
  required SettingsEditing editing,
  required MomentFormatter formatter,
  required DisplaySettings display,
}) {
  final SettingsEditing(:settings, :errors, :canChange, :onSave) = editing;
  return SettingsSection(
    title: l10n.accountSettingsEmailNotifications,
    children: [
      if (!connection.info.emailRemindersEnabled)
        SettingsNote(
          text: l10n.accountSettingsEmailsOff,
          icon: Icons.unsubscribe_outlined,
        ),
      SettingSwitch(
        icon: Icons.mail_outline,
        title: l10n.accountSettingsEmailReminders,
        subtitle: l10n.accountSettingsEmailRemindersSubtitle,
        value: settings.emailRemindersEnabled,
        error: errors[AccountSettingsField.emailReminders],
        onChanged: canChange
            ? (value) => onSave(
                AccountSettingsField.emailReminders,
                UserSettingsChanges(emailRemindersEnabled: value),
              )
            : null,
      ),
      SettingSwitch(
        icon: Icons.notification_important_outlined,
        title: l10n.accountSettingsOverdueReminders,
        subtitle: l10n.accountSettingsOverdueRemindersSubtitle,
        value: settings.overdueTasksRemindersEnabled,
        error: errors[AccountSettingsField.overdueReminders],
        onChanged: canChange
            ? (value) => onSave(
                AccountSettingsField.overdueReminders,
                UserSettingsChanges(overdueTasksRemindersEnabled: value),
              )
            : null,
      ),
      if (settings.overdueTasksRemindersEnabled)
        SettingChoiceTile(
          leading: const Icon(Icons.alarm_outlined),
          title: l10n.accountSettingsOverdueTime,
          value: formatter.timeOfDay(
            DateTime(
              2000,
              1,
              1,
              settings.overdueTasksRemindersTime.hour,
              settings.overdueTasksRemindersTime.minute,
            ),
          ),
          error: errors[AccountSettingsField.overdueTime],
          onTap: editing.whenChangeable(() async {
            final current = settings.overdueTasksRemindersTime;
            final picked = await pickTimeOfDay(
              context,
              initial: TimeOfDay(hour: current.hour, minute: current.minute),
              display: display,
              title: l10n.accountSettingsOverdueTime,
            );
            if (picked == null) return;
            final time = ClockTime(picked.hour, picked.minute);
            if (time == current) return;
            onSave(
              AccountSettingsField.overdueTime,
              UserSettingsChanges(overdueTasksRemindersTime: time),
            );
          }),
        ),
    ],
  );
}

Widget privacySection({
  required AppLocalizations l10n,
  required SettingsEditing editing,
}) {
  final SettingsEditing(:settings, :errors, :canChange, :onSave) = editing;
  return SettingsSection(
    title: l10n.accountSettingsPrivacy,
    children: [
      SettingSwitch(
        icon: Icons.person_search_outlined,
        title: l10n.accountSettingsDiscoverableByName,
        subtitle: l10n.accountSettingsDiscoverableByNameSubtitle,
        value: settings.discoverableByName,
        error: errors[AccountSettingsField.discoverableByName],
        onChanged: canChange
            ? (value) => onSave(
                AccountSettingsField.discoverableByName,
                UserSettingsChanges(discoverableByName: value),
              )
            : null,
      ),
      SettingSwitch(
        icon: Icons.contact_mail_outlined,
        title: l10n.accountSettingsDiscoverableByEmail,
        subtitle: l10n.accountSettingsDiscoverableByEmailSubtitle,
        value: settings.discoverableByEmail,
        error: errors[AccountSettingsField.discoverableByEmail],
        onChanged: canChange
            ? (value) => onSave(
                AccountSettingsField.discoverableByEmail,
                UserSettingsChanges(discoverableByEmail: value),
              )
            : null,
      ),
    ],
  );
}

Future<String?> _pickTimeZone(BuildContext context, String current) {
  final l10n = context.l10n;
  final choices = timeZoneChoices(DateTime.now());
  final byName = {for (final choice in choices) choice.name: choice};
  final suggested = deviceTimeZoneSuggestions(current);
  SearchableOption<String> option(TimeZoneChoice choice) => SearchableOption(
    value: choice.name,
    label: choice.label,
    detail: formatUtcOffset(choice.offset),
    searchTerms: [choice.name],
    selected: choice.name == current,
  );
  return showSearchableOptionSheet<String>(
    context,
    title: l10n.accountSettingsTimezone,
    searchLabel: l10n.accountSettingsTimezoneSearch,
    options: [for (final choice in choices) option(choice)],
    suggested: [
      for (final name in suggested)
        if (byName[name] case final choice?) option(choice),
    ],
    suggestedHeading: suggested.length == 1
        ? l10n.accountSettingsTimezoneDevice
        : l10n.accountSettingsTimezoneSameAsDevice,
    allHeading: l10n.accountSettingsTimezoneAll,
  );
}

Future<String?> _pickLanguage(BuildContext context, String current) {
  final l10n = context.l10n;
  return showSearchableOptionSheet<String>(
    context,
    title: l10n.accountSettingsLanguage,
    searchLabel: l10n.accountSettingsLanguageSearch,
    options: [
      for (final language in serverLanguages)
        SearchableOption(
          value: language.code,
          label: language.name,
          detail: language.code,
          selected: language.code == current,
        ),
    ],
  );
}

String _defaultViewLabel(AppLocalizations l10n, ProjectViewKind? kind) =>
    kind == null
    ? l10n.accountSettingsDefaultViewFirst
    : viewKindLabel(l10n, kind);

String _magicModeLabel(AppLocalizations l10n, QuickAddMagicMode mode) =>
    switch (mode) {
      QuickAddMagicMode.disabled => l10n.accountSettingsQuickAddMagicDisabled,
      QuickAddMagicMode.vikunja => l10n.accountSettingsQuickAddMagicVikunja,
      QuickAddMagicMode.todoist => l10n.accountSettingsQuickAddMagicTodoist,
    };

String _overviewFilterLabel(
  AppLocalizations l10n,
  int? filterProjectId,
  List<SavedFilterRef> filters,
) {
  if (filterProjectId == null) return l10n.accountSettingsOverviewFilterNone;
  for (final filter in filters) {
    if (filter.projectId == filterProjectId) {
      return projectDisplayTitle(
        l10n,
        filter.title,
        projectId: filter.projectId,
      );
    }
  }
  return l10n.accountSettingsOverviewFilterUnknown;
}

/// The written forms are labelled with today's date, as on the web.
String _dateDisplayLabel(
  AppLocalizations l10n,
  DateDisplay display,
  DateTime now,
) => switch (display) {
  DateDisplay.relative => l10n.accountSettingsDateDisplayRelative,
  DateDisplay.monthDayYearDashed => l10n.accountSettingsDateMonthDayYearDashed,
  DateDisplay.dayMonthYearDashed => l10n.accountSettingsDateDayMonthYearDashed,
  DateDisplay.yearMonthDayDashed => l10n.accountSettingsDateYearMonthDayDashed,
  DateDisplay.monthDayYearSlashed =>
    l10n.accountSettingsDateMonthDayYearSlashed,
  DateDisplay.dayMonthYearSlashed =>
    l10n.accountSettingsDateDayMonthYearSlashed,
  DateDisplay.yearMonthDaySlashed =>
    l10n.accountSettingsDateYearMonthDaySlashed,
  DateDisplay.dayMonthYear => intl.DateFormat.yMMMMd(
    l10n.localeName,
  ).format(now),
  DateDisplay.weekdayDayMonthYear => intl.DateFormat.yMMMMEEEEd(
    l10n.localeName,
  ).format(now),
};

/// With an example time, `12-hour · 2:30 PM`.
String _timeFormatLabel(
  AppLocalizations l10n,
  TimeFormat? format,
  DateTime now,
) {
  final sample = DateTime(now.year, now.month, now.day, 14, 30);
  // The language's AM/PM, as MomentFormatter shows it, not en_GB's am/pm.
  String example(String pattern) => intl.DateFormat(
    pattern,
    intl.Intl.shortLocale(l10n.localeName),
  ).format(sample);
  return switch (format) {
    null => l10n.accountSettingsTimeFormatDevice,
    TimeFormat.twelveHour =>
      '${l10n.accountSettingsTimeFormat12} · ${example('h:mm a')}',
    TimeFormat.twentyFourHour =>
      '${l10n.accountSettingsTimeFormat24} · ${example('HH:mm')}',
  };
}
