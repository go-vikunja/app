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
  });
}
