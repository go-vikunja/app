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

  test('the defaults: no overview filter, no minimum priority', () {
    const settings = UserSettings();
    expect(settings.filterIdUsedOnOverview, isNull);
    expect(settings.minimumPriority, 0);
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
  });
}
