import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/src/dto/user_settings_codec.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

void main() {
  test('reads the fields the app uses', () {
    final settings = parseUserSettings({
      'name': '',
      'email_reminders_enabled': true,
      'default_project_id': 6,
      'week_start': 1,
      'language': 'de-DE',
      'timezone': 'Europe/Berlin',
      'frontend_settings': {
        'quick_add_magic_mode': 'todoist',
        'quick_add_default_reminders': [
          {'relative_period': -900, 'relative_to': 'due_date'},
          {'relative_period': 3600},
        ],
        'play_sound_when_done': false,
        'filter_id_used_on_overview': -553,
        'minimum_priority': 3,
        'comment_sort_order': 'desc',
      },
      'extra_settings_links': null,
    });

    expect(
      settings,
      const UserSettings(
        emailRemindersEnabled: true,
        defaultProjectId: 6,
        weekStart: 1,
        timezone: 'Europe/Berlin',
        language: 'de-DE',
        quickAddMagicMode: QuickAddMagicMode.todoist,
        quickAddDefaultReminders: [Duration(minutes: -15), Duration(hours: 1)],
        filterIdUsedOnOverview: -553,
        minimumPriority: 3,
        commentSortOrder: CommentSortOrder.newestFirst,
      ),
    );
    expect(settings.effectiveMinimumPriority, 3);
  });

  test('reads the account settings: name, emails, privacy and the overdue '
      'summary', () {
    final settings = parseUserSettings({
      'name': 'Dora',
      'email_reminders_enabled': true,
      'discoverable_by_name': true,
      'discoverable_by_email': true,
      'overdue_tasks_reminders_enabled': false,
      'overdue_tasks_reminders_time': '18:30',
    });

    expect(
      settings,
      const UserSettings(
        name: 'Dora',
        emailRemindersEnabled: true,
        discoverableByName: true,
        discoverableByEmail: true,
        overdueTasksRemindersEnabled: false,
        overdueTasksRemindersTime: ClockTime(18, 30),
      ),
    );
  });

  test("the server's own reminder time without a leading zero", () {
    expect(
      parseUserSettings({'overdue_tasks_reminders_time': '9:00'})
          .overdueTasksRemindersTime,
      const ClockTime(9, 0),
    );
  });

  test('odd account settings fall back to those of a new user', () {
    final settings = parseUserSettings({
      'name': 7,
      'email_reminders_enabled': 'yes',
      'discoverable_by_name': 1,
      'discoverable_by_email': null,
      'overdue_tasks_reminders_enabled': 'no',
      'overdue_tasks_reminders_time': '09:00:00',
    });

    expect(settings.name, '');
    expect(settings.emailRemindersEnabled, isFalse);
    expect(settings.discoverableByName, isFalse);
    expect(settings.discoverableByEmail, isFalse);
    expect(settings.overdueTasksRemindersEnabled, isTrue);
    expect(settings.overdueTasksRemindersTime, const ClockTime(9, 0));
  });

  test('reads the display settings the web stores', () {
    final settings = parseUserSettings({
      'frontend_settings': {
        'date_display': 'dd/mm/yyyy',
        'time_format': '12h',
        'color_schema': 'dark',
        'default_view': 'kanban',
      },
    });

    expect(settings.dateDisplay, DateDisplay.dayMonthYearSlashed);
    expect(settings.timeFormat, TimeFormat.twelveHour);
    expect(settings.colorSchema, ColorSchema.dark);
    expect(settings.defaultViewKind, ProjectViewKind.kanban);
  });

  test('every date display and default view the web offers', () {
    for (final display in DateDisplay.values) {
      expect(
        parseUserSettings({
          'frontend_settings': {'date_display': display.wireName},
        }).dateDisplay,
        display,
      );
    }
    for (final kind in ProjectViewKind.values) {
      expect(
        parseUserSettings({
          'frontend_settings': {'default_view': kind.wireName},
        }).defaultViewKind,
        kind,
      );
    }
    expect(
      parseUserSettings({
        'frontend_settings': {'default_view': 'first'},
      }).defaultViewKind,
      isNull,
    );
  });

  test('display settings never set stay unset, the colour scheme auto', () {
    for (final frontend in <Object?>[null, <String, Object?>{}]) {
      final settings = parseUserSettings({'frontend_settings': frontend});

      expect(settings.dateDisplay, isNull);
      expect(settings.timeFormat, isNull);
      expect(settings.colorSchema, ColorSchema.auto);
      expect(settings.defaultViewKind, isNull);
    }
  });

  test('comments oldest first unless the web stored desc', () {
    for (final (stored, expected) in [
      ('asc', CommentSortOrder.oldestFirst),
      ('desc', CommentSortOrder.newestFirst),
      ('DESC', CommentSortOrder.oldestFirst),
      (null, CommentSortOrder.oldestFirst),
      (1, CommentSortOrder.oldestFirst),
    ]) {
      final settings = parseUserSettings({
        'frontend_settings': {'comment_sort_order': stored},
      });

      expect(settings.commentSortOrder, expected, reason: '$stored');
    }
    expect(
      parseUserSettings({'frontend_settings': null}).commentSortOrder,
      CommentSortOrder.oldestFirst,
    );
  });

  test('the web writes null for no overview filter', () {
    final settings = parseUserSettings({
      'frontend_settings': {
        'filter_id_used_on_overview': null,
        'minimum_priority': null,
      },
    });

    expect(settings.filterIdUsedOnOverview, isNull);
    expect(settings.minimumPriority, 0);
    expect(settings.effectiveMinimumPriority, 2);
  });

  test('frontend settings null, as for a user who never saved any', () {
    final settings = parseUserSettings({
      'default_project_id': 6,
      'week_start': 0,
      'language': '',
      'timezone': 'GMT',
      'frontend_settings': null,
    });

    expect(settings, const UserSettings(defaultProjectId: 6, timezone: 'GMT'));
    expect(settings.quickAddMagicMode, QuickAddMagicMode.vikunja);
    expect(settings.quickAddDefaultReminders, isEmpty);
  });

  for (final mode in QuickAddMagicMode.values) {
    test('the mode ${mode.wireName}', () {
      expect(
        parseUserSettings({
          'frontend_settings': {'quick_add_magic_mode': mode.wireName},
        }).quickAddMagicMode,
        mode,
      );
    });
  }

  group('odd values fall back to the defaults', () {
    for (final json in <Object?>[
      null,
      'settings',
      42,
      <Object?>[],
      <String, Object?>{},
    ]) {
      test('settings $json', () {
        expect(parseUserSettings(json), const UserSettings());
      });
    }

    test('default project 0 or negative or not a number is none', () {
      for (final id in <Object?>[0, -3, '6', 6.5, null]) {
        expect(
          parseUserSettings({'default_project_id': id}).defaultProjectId,
          isNull,
          reason: '$id',
        );
      }
    });

    test('week start outside 0..6', () {
      for (final day in <Object?>[-1, 7, '1', 1.0]) {
        expect(
          parseUserSettings({'week_start': day}).weekStart,
          0,
          reason: '$day',
        );
      }
    });

    test('timezone and language that are not strings', () {
      final settings = parseUserSettings({'timezone': 1, 'language': false});
      expect(settings.timezone, '');
      expect(settings.language, '');
    });

    test('frontend settings that are not an object', () {
      for (final frontend in <Object?>['{}', 1, <Object?>[], true]) {
        expect(
          parseUserSettings({
            'default_project_id': 4,
            'frontend_settings': frontend,
          }),
          const UserSettings(defaultProjectId: 4),
          reason: '$frontend',
        );
      }
    });

    test('an unknown mode is the web default', () {
      for (final mode in <Object?>['Todoist', 'off', '', 1, null]) {
        expect(
          parseUserSettings({
            'frontend_settings': {'quick_add_magic_mode': mode},
          }).quickAddMagicMode,
          QuickAddMagicMode.vikunja,
          reason: '$mode',
        );
      }
    });

    test('default reminders without an int period are skipped', () {
      final settings = parseUserSettings({
        'frontend_settings': {
          'quick_add_default_reminders': [
            {'relative_period': -600},
            {'relative_period': '-600'},
            {'relative_period': 1.5},
            {'relative_to': 'due_date'},
            -600,
            null,
            {'relative_period': 0},
          ],
        },
      });

      expect(settings.quickAddDefaultReminders, const [
        Duration(minutes: -10),
        Duration.zero,
      ]);
    });

    test('an overview filter that is no saved filter is none', () {
      for (final id in <Object?>[-1, 0, 5, -553.0, '-553', true, <Object?>[]]) {
        expect(
          parseUserSettings({
            'frontend_settings': {'filter_id_used_on_overview': id},
          }).filterIdUsedOnOverview,
          isNull,
          reason: '$id',
        );
      }
      expect(
        parseUserSettings({
          'frontend_settings': {'filter_id_used_on_overview': -2},
        }).filterIdUsedOnOverview,
        -2,
      );
    });

    test('a minimum priority outside 1..5 is unset', () {
      for (final priority in <Object?>[0, -1, 6, 2.0, '3', false]) {
        expect(
          parseUserSettings({
            'frontend_settings': {'minimum_priority': priority},
          }).minimumPriority,
          0,
          reason: '$priority',
        );
      }
      for (final priority in [1, 5]) {
        expect(
          parseUserSettings({
            'frontend_settings': {'minimum_priority': priority},
          }).minimumPriority,
          priority,
        );
      }
    });

    test('display settings the server stored unchecked', () {
      for (final odd in <Object?>[5, 'Relative', 'MM-DD-YYYY', '', true]) {
        final settings = parseUserSettings({
          'frontend_settings': {
            'date_display': odd,
            'time_format': odd,
            'color_schema': odd,
            'default_view': odd,
          },
        });

        expect(settings.dateDisplay, isNull, reason: '$odd');
        expect(settings.timeFormat, isNull, reason: '$odd');
        expect(settings.colorSchema, ColorSchema.auto, reason: '$odd');
        expect(settings.defaultViewKind, isNull, reason: '$odd');
      }
      expect(
        parseUserSettings({
          'frontend_settings': {'color_schema': 'purple', 'time_format': '24'},
        }),
        const UserSettings(),
      );
    });

    test('default reminders that are not a list', () {
      for (final reminders in <Object?>[
        {'relative_period': -600},
        '[]',
        null,
      ]) {
        expect(
          parseUserSettings({
            'frontend_settings': {'quick_add_default_reminders': reminders},
          }).quickAddDefaultReminders,
          isEmpty,
          reason: '$reminders',
        );
      }
    });
  });
}
