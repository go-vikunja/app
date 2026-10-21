import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

const _stored = UserSettings(
  name: 'Dora',
  defaultProjectId: 3,
  weekStart: 1,
  timezone: 'Europe/Berlin',
  quickAddDefaultReminders: [Duration(minutes: -15)],
  filterIdUsedOnOverview: -553,
  minimumPriority: 3,
  dateDisplay: DateDisplay.dayMonthYear,
  timeFormat: TimeFormat.twelveHour,
  defaultViewKind: ProjectViewKind.kanban,
);

void main() {
  test('no field set is empty', () {
    expect(const UserSettingsChanges().isEmpty, isTrue);
    expect(const UserSettingsChanges(name: '').isEmpty, isFalse);
    expect(
      const UserSettingsChanges(dateDisplay: SettingChange.clear()).isEmpty,
      isFalse,
    );
  });

  group('applyTo', () {
    test('empty changes keep the settings', () {
      expect(const UserSettingsChanges().applyTo(_stored), _stored);
    });

    test('sets every field', () {
      const changes = UserSettingsChanges(
        name: 'Boots',
        emailRemindersEnabled: true,
        discoverableByName: true,
        discoverableByEmail: true,
        overdueTasksRemindersEnabled: false,
        overdueTasksRemindersTime: ClockTime(7, 45),
        defaultProjectId: SettingChange.set(9),
        weekStart: 6,
        timezone: 'America/New_York',
        language: 'fr-FR',
        quickAddMagicMode: QuickAddMagicMode.disabled,
        quickAddDefaultReminders: [Duration(days: 1)],
        filterIdUsedOnOverview: SettingChange.set(-600),
        minimumPriority: 5,
        commentSortOrder: CommentSortOrder.newestFirst,
        dateDisplay: SettingChange.set(DateDisplay.relative),
        timeFormat: SettingChange.set(TimeFormat.twentyFourHour),
        colorSchema: ColorSchema.light,
        defaultViewKind: SettingChange.set(ProjectViewKind.list),
      );

      expect(
        changes.applyTo(_stored),
        const UserSettings(
          name: 'Boots',
          emailRemindersEnabled: true,
          discoverableByName: true,
          discoverableByEmail: true,
          overdueTasksRemindersEnabled: false,
          overdueTasksRemindersTime: ClockTime(7, 45),
          defaultProjectId: 9,
          weekStart: 6,
          timezone: 'America/New_York',
          language: 'fr-FR',
          quickAddMagicMode: QuickAddMagicMode.disabled,
          quickAddDefaultReminders: [Duration(days: 1)],
          filterIdUsedOnOverview: -600,
          minimumPriority: 5,
          commentSortOrder: CommentSortOrder.newestFirst,
          dateDisplay: DateDisplay.relative,
          timeFormat: TimeFormat.twentyFourHour,
          colorSchema: ColorSchema.light,
          defaultViewKind: ProjectViewKind.list,
        ),
      );
    });

    test('clear unsets the nullable settings and keeps the rest', () {
      const changes = UserSettingsChanges(
        defaultProjectId: SettingChange.clear(),
        filterIdUsedOnOverview: SettingChange.clear(),
        dateDisplay: SettingChange.clear(),
        timeFormat: SettingChange.clear(),
        defaultViewKind: SettingChange.clear(),
      );

      final applied = changes.applyTo(_stored);

      expect(applied.defaultProjectId, isNull);
      expect(applied.filterIdUsedOnOverview, isNull);
      expect(applied.dateDisplay, isNull);
      expect(applied.timeFormat, isNull);
      expect(applied.defaultViewKind, isNull);
      expect(applied.name, 'Dora');
      expect(applied.weekStart, 1);
      expect(applied.quickAddDefaultReminders, [const Duration(minutes: -15)]);
    });
  });

  group('equality', () {
    test('changes with the same fields are equal', () {
      const a = UserSettingsChanges(
        name: 'Dora',
        overdueTasksRemindersTime: ClockTime(9, 0),
        quickAddDefaultReminders: [Duration(hours: -1)],
        dateDisplay: SettingChange.clear(),
        defaultProjectId: SettingChange.set(3),
      );
      const b = UserSettingsChanges(
        name: 'Dora',
        overdueTasksRemindersTime: ClockTime(9, 0),
        quickAddDefaultReminders: [Duration(hours: -1)],
        dateDisplay: SettingChange.clear(),
        defaultProjectId: SettingChange.set(3),
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('a set value differs from a clear and from no change', () {
      const set = UserSettingsChanges(
        timeFormat: SettingChange.set(TimeFormat.twelveHour),
      );
      const clear = UserSettingsChanges(timeFormat: SettingChange.clear());

      expect(set, isNot(clear));
      expect(clear, isNot(const UserSettingsChanges()));
      expect(
        const UserSettingsChanges(quickAddDefaultReminders: []),
        isNot(const UserSettingsChanges()),
      );
      expect(
        const UserSettingsChanges(
          quickAddDefaultReminders: [Duration(hours: 1)],
        ),
        isNot(const UserSettingsChanges(quickAddDefaultReminders: [])),
      );
    });

    test('SettingChange compares its value', () {
      expect(const SettingChange.set(3), const SettingChange.set(3));
      expect(const SettingChange.set(3), isNot(const SettingChange.set(4)));
      expect(
        const SettingChange<int>.clear(),
        const SettingChange<int>.clear(),
      );
      expect(const SettingChange<int>.clear().value, isNull);
    });
  });

  test('toString names the fields set, without the name, timezone or '
      'language', () {
    const changes = UserSettingsChanges(
      name: 'Dora Secret',
      timezone: 'Europe/Berlin',
      language: 'de-DE',
      weekStart: 1,
      overdueTasksRemindersTime: ClockTime(9, 0),
      dateDisplay: SettingChange.clear(),
    );

    final text = changes.toString();

    expect(text, isNot(contains('Secret')));
    expect(text, isNot(contains('Berlin')));
    expect(text, isNot(contains('de-DE')));
    expect(
      text,
      'UserSettingsChanges(name, overdueTasksRemindersTime: 09:00, '
      'weekStart: 1, timezone, language, dateDisplay: clear)',
    );
  });
}
