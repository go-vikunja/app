import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

void main() {
  group('effectiveMinimumPriority', () {
    test('an unset minimum priority is medium, as on the web', () {
      expect(const UserSettings().effectiveMinimumPriority, 2);
      expect(
        const UserSettings().effectiveMinimumPriority,
        TaskPriority.medium.value,
      );
    });

    test('a set one is taken as it is', () {
      for (final priority in [1, 2, 3, 4, 5]) {
        expect(
          UserSettings(minimumPriority: priority).effectiveMinimumPriority,
          priority,
        );
      }
    });
  });

  test('the defaults: no overview filter, no minimum priority, oldest '
      'comments first', () {
    const settings = UserSettings();
    expect(settings.filterIdUsedOnOverview, isNull);
    expect(settings.minimumPriority, 0);
    expect(settings.commentSortOrder, CommentSortOrder.oldestFirst);
  });

  test('comment sort orders by wire name, the web default otherwise', () {
    expect(CommentSortOrder.fromWire('asc'), CommentSortOrder.oldestFirst);
    expect(CommentSortOrder.fromWire('desc'), CommentSortOrder.newestFirst);
    for (final other in [null, '', 'DESC', 'newest', 1, true]) {
      expect(
        CommentSortOrder.fromWire(other),
        CommentSortOrder.oldestFirst,
        reason: '$other',
      );
    }
    expect(CommentSortOrder.newestFirst.wireName, 'desc');
  });

  test('the display settings: unset date display, time format and default '
      'view, the automatic colour scheme', () {
    const settings = UserSettings();
    expect(settings.dateDisplay, isNull);
    expect(settings.timeFormat, isNull);
    expect(settings.colorSchema, ColorSchema.auto);
    expect(settings.defaultViewKind, isNull);
  });

  test("date displays by the web's wire names, null otherwise", () {
    expect(
      [for (final display in DateDisplay.values) display.wireName],
      [
        'relative',
        'mm-dd-yyyy',
        'dd-mm-yyyy',
        'yyyy-mm-dd',
        'mm/dd/yyyy',
        'dd/mm/yyyy',
        'yyyy/mm/dd',
        'dayMonthYear',
        'weekdayDayMonthYear',
      ],
    );
    for (final display in DateDisplay.values) {
      expect(DateDisplay.fromWire(display.wireName), display);
    }
    for (final other in [null, '', 'MM-DD-YYYY', 'daymonthyear', 5, true]) {
      expect(DateDisplay.fromWire(other), isNull, reason: '$other');
    }
  });

  test('time formats by wire name, null otherwise', () {
    expect(TimeFormat.fromWire('12h'), TimeFormat.twelveHour);
    expect(TimeFormat.fromWire('24h'), TimeFormat.twentyFourHour);
    for (final other in [null, '', '12H', '24', 24, false]) {
      expect(TimeFormat.fromWire(other), isNull, reason: '$other');
    }
  });

  test('colour schemes by wire name, auto otherwise', () {
    expect(ColorSchema.fromWire('light'), ColorSchema.light);
    expect(ColorSchema.fromWire('dark'), ColorSchema.dark);
    expect(ColorSchema.fromWire('auto'), ColorSchema.auto);
    for (final other in [null, '', 'Dark', 'purple', 1]) {
      expect(ColorSchema.fromWire(other), ColorSchema.auto, reason: '$other');
    }
  });

  test('the account settings of a new user: no name, no emails, not '
      'discoverable, the overdue summary on at 9:00', () {
    const settings = UserSettings();
    expect(settings.name, '');
    expect(settings.emailRemindersEnabled, isFalse);
    expect(settings.discoverableByName, isFalse);
    expect(settings.discoverableByEmail, isFalse);
    expect(settings.overdueTasksRemindersEnabled, isTrue);
    expect(settings.overdueTasksRemindersTime, const ClockTime(9, 0));
  });

  group('ClockTime', () {
    test("parses Go's 15:04 layout, with or without a leading zero", () {
      expect(ClockTime.tryParse('9:00'), const ClockTime(9, 0));
      expect(ClockTime.tryParse('09:00'), const ClockTime(9, 0));
      expect(ClockTime.tryParse('23:59'), const ClockTime(23, 59));
      expect(ClockTime.tryParse('0:05'), const ClockTime(0, 5));
    });

    test('refuses what the server refuses', () {
      for (final value in [
        '7:5',
        '09:00:00',
        '9',
        '9.30',
        '',
        '24:00',
        '12:60',
        ' 9:00',
        '9:00 ',
        '123:00',
        null,
        900,
      ]) {
        expect(ClockTime.tryParse(value), isNull, reason: '$value');
      }
    });

    test('is sent zero-padded, as the web sends it', () {
      expect(const ClockTime(9, 0).wireName, '09:00');
      expect(const ClockTime(21, 5).wireName, '21:05');
      expect(const ClockTime(0, 0).wireName, '00:00');
    });

    test('equal by hour and minute', () {
      expect(const ClockTime(7, 30), const ClockTime(7, 30));
      expect(const ClockTime(7, 30).hashCode, const ClockTime(7, 30).hashCode);
      expect(const ClockTime(7, 30), isNot(const ClockTime(7, 31)));
      expect(const ClockTime(7, 30).toString(), 'ClockTime(07:30)');
    });
  });

  group('copyWith', () {
    const full = UserSettings(
      name: 'Dora',
      emailRemindersEnabled: true,
      discoverableByName: true,
      discoverableByEmail: true,
      overdueTasksRemindersEnabled: false,
      overdueTasksRemindersTime: ClockTime(18, 30),
      defaultProjectId: 3,
      weekStart: 1,
      timezone: 'Europe/Berlin',
      language: 'de-DE',
      quickAddMagicMode: QuickAddMagicMode.todoist,
      quickAddDefaultReminders: [Duration(minutes: -15)],
      filterIdUsedOnOverview: -553,
      minimumPriority: 3,
      commentSortOrder: CommentSortOrder.newestFirst,
      dateDisplay: DateDisplay.dayMonthYear,
      timeFormat: TimeFormat.twelveHour,
      colorSchema: ColorSchema.dark,
      defaultViewKind: ProjectViewKind.kanban,
    );

    test('without arguments keeps every field', () {
      expect(full.copyWith(), full);
      expect(const UserSettings().copyWith(), const UserSettings());
    });

    test('replaces each field on its own', () {
      expect(full.copyWith(name: 'Boots').name, 'Boots');
      expect(full.copyWith(emailRemindersEnabled: false), isNot(full));
      expect(
        full.copyWith(discoverableByName: false).discoverableByName,
        false,
      );
      expect(
        full.copyWith(discoverableByEmail: false).discoverableByEmail,
        false,
      );
      expect(
        full
            .copyWith(overdueTasksRemindersEnabled: true)
            .overdueTasksRemindersEnabled,
        isTrue,
      );
      expect(
        full
            .copyWith(overdueTasksRemindersTime: const ClockTime(7, 0))
            .overdueTasksRemindersTime,
        const ClockTime(7, 0),
      );
      expect(full.copyWith(defaultProjectId: 9).defaultProjectId, 9);
      expect(full.copyWith(weekStart: 6).weekStart, 6);
      expect(full.copyWith(timezone: 'UTC').timezone, 'UTC');
      expect(full.copyWith(language: 'en').language, 'en');
      expect(
        full
            .copyWith(quickAddMagicMode: QuickAddMagicMode.disabled)
            .quickAddMagicMode,
        QuickAddMagicMode.disabled,
      );
      expect(
        full
            .copyWith(quickAddDefaultReminders: const [])
            .quickAddDefaultReminders,
        isEmpty,
      );
      expect(
        full.copyWith(filterIdUsedOnOverview: -600).filterIdUsedOnOverview,
        -600,
      );
      expect(full.copyWith(minimumPriority: 5).minimumPriority, 5);
      expect(
        full
            .copyWith(commentSortOrder: CommentSortOrder.oldestFirst)
            .commentSortOrder,
        CommentSortOrder.oldestFirst,
      );
      expect(
        full.copyWith(dateDisplay: DateDisplay.relative).dateDisplay,
        DateDisplay.relative,
      );
      expect(
        full.copyWith(timeFormat: TimeFormat.twentyFourHour).timeFormat,
        TimeFormat.twentyFourHour,
      );
      expect(
        full.copyWith(colorSchema: ColorSchema.light).colorSchema,
        ColorSchema.light,
      );
      expect(
        full.copyWith(defaultViewKind: ProjectViewKind.list).defaultViewKind,
        ProjectViewKind.list,
      );
    });

    test('null unsets the nullable fields', () {
      final cleared = full.copyWith(
        defaultProjectId: null,
        filterIdUsedOnOverview: null,
        dateDisplay: null,
        timeFormat: null,
        defaultViewKind: null,
      );

      expect(cleared.defaultProjectId, isNull);
      expect(cleared.filterIdUsedOnOverview, isNull);
      expect(cleared.dateDisplay, isNull);
      expect(cleared.timeFormat, isNull);
      expect(cleared.defaultViewKind, isNull);
      expect(cleared.name, 'Dora');
      expect(cleared.minimumPriority, 3);
    });

    test('every new field counts for equality', () {
      const plain = UserSettings();
      for (final changed in const [
        UserSettings(name: 'Dora'),
        UserSettings(emailRemindersEnabled: true),
        UserSettings(discoverableByName: true),
        UserSettings(discoverableByEmail: true),
        UserSettings(overdueTasksRemindersEnabled: false),
        UserSettings(overdueTasksRemindersTime: ClockTime(10, 0)),
      ]) {
        expect(changed, isNot(plain));
        expect(changed.hashCode, isNot(plain.hashCode));
      }
    });
  });

  group('equality', () {
    const base = UserSettings(
      defaultProjectId: 3,
      weekStart: 1,
      timezone: 'Europe/Berlin',
      language: 'de-DE',
      quickAddMagicMode: QuickAddMagicMode.todoist,
      quickAddDefaultReminders: [Duration(minutes: -15)],
      filterIdUsedOnOverview: -553,
      minimumPriority: 3,
    );

    test('settings with the same fields are equal', () {
      const same = UserSettings(
        defaultProjectId: 3,
        weekStart: 1,
        timezone: 'Europe/Berlin',
        language: 'de-DE',
        quickAddMagicMode: QuickAddMagicMode.todoist,
        quickAddDefaultReminders: [Duration(minutes: -15)],
        filterIdUsedOnOverview: -553,
        minimumPriority: 3,
      );

      expect(same, base);
      expect(same.hashCode, base.hashCode);
    });

    test('the overview filter and the minimum priority count', () {
      const otherFilter = UserSettings(
        defaultProjectId: 3,
        weekStart: 1,
        timezone: 'Europe/Berlin',
        language: 'de-DE',
        quickAddMagicMode: QuickAddMagicMode.todoist,
        quickAddDefaultReminders: [Duration(minutes: -15)],
        filterIdUsedOnOverview: -554,
        minimumPriority: 3,
      );
      const noFilter = UserSettings(
        defaultProjectId: 3,
        weekStart: 1,
        timezone: 'Europe/Berlin',
        language: 'de-DE',
        quickAddMagicMode: QuickAddMagicMode.todoist,
        quickAddDefaultReminders: [Duration(minutes: -15)],
        minimumPriority: 3,
      );
      const otherPriority = UserSettings(
        defaultProjectId: 3,
        weekStart: 1,
        timezone: 'Europe/Berlin',
        language: 'de-DE',
        quickAddMagicMode: QuickAddMagicMode.todoist,
        quickAddDefaultReminders: [Duration(minutes: -15)],
        filterIdUsedOnOverview: -553,
      );

      expect(otherFilter, isNot(base));
      expect(noFilter, isNot(base));
      expect(otherPriority, isNot(base));
    });

    test('the comment sort order counts', () {
      const newestFirst = UserSettings(
        defaultProjectId: 3,
        weekStart: 1,
        timezone: 'Europe/Berlin',
        language: 'de-DE',
        quickAddMagicMode: QuickAddMagicMode.todoist,
        quickAddDefaultReminders: [Duration(minutes: -15)],
        filterIdUsedOnOverview: -553,
        minimumPriority: 3,
        commentSortOrder: CommentSortOrder.newestFirst,
      );

      expect(newestFirst, isNot(base));
      expect(newestFirst.hashCode, isNot(base.hashCode));
    });

    test('every display setting counts', () {
      const plain = UserSettings();
      for (final changed in const [
        UserSettings(dateDisplay: DateDisplay.relative),
        UserSettings(timeFormat: TimeFormat.twentyFourHour),
        UserSettings(colorSchema: ColorSchema.dark),
        UserSettings(defaultViewKind: ProjectViewKind.kanban),
      ]) {
        expect(changed, isNot(plain));
        expect(changed.hashCode, isNot(plain.hashCode));
      }
      expect(
        const UserSettings(
          dateDisplay: DateDisplay.yearMonthDayDashed,
          timeFormat: TimeFormat.twelveHour,
          colorSchema: ColorSchema.light,
          defaultViewKind: ProjectViewKind.list,
        ),
        const UserSettings(
          dateDisplay: DateDisplay.yearMonthDayDashed,
          timeFormat: TimeFormat.twelveHour,
          colorSchema: ColorSchema.light,
          defaultViewKind: ProjectViewKind.list,
        ),
      );
    });
  });
}
