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
