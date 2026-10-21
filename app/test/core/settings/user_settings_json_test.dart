import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/settings/user_settings_json.dart';

void main() {
  test('round-trips every field', () {
    const settings = UserSettings(
      name: 'Anna Example',
      emailRemindersEnabled: true,
      discoverableByName: true,
      discoverableByEmail: true,
      overdueTasksRemindersEnabled: false,
      overdueTasksRemindersTime: ClockTime(7, 5),
      defaultProjectId: 12,
      weekStart: 1,
      timezone: 'Europe/Berlin',
      language: 'de-DE',
      quickAddMagicMode: QuickAddMagicMode.todoist,
      quickAddDefaultReminders: [Duration(minutes: -15), Duration(days: 1)],
      filterIdUsedOnOverview: -553,
      minimumPriority: 4,
      commentSortOrder: CommentSortOrder.newestFirst,
      dateDisplay: DateDisplay.weekdayDayMonthYear,
      timeFormat: TimeFormat.twelveHour,
      colorSchema: ColorSchema.dark,
      defaultViewKind: ProjectViewKind.table,
    );

    expect(decodeUserSettings(encodeUserSettings(settings)), settings);
    expect(
      decodeUserSettings(encodeUserSettings(const UserSettings())),
      const UserSettings(),
    );
  });

  test('nothing stored yet is the defaults', () {
    expect(decodeUserSettings(null), const UserSettings());
  });

  test('a value this version cannot read is the defaults', () {
    for (final stored in ['', 'not json', '[1, 2]', '"text"', '42']) {
      expect(decodeUserSettings(stored), const UserSettings(), reason: stored);
    }
  });

  test('odd fields fall back one by one', () {
    final settings = decodeUserSettings(
      '{"default_project_id": -1, "week_start": 9, "timezone": 3, '
      '"language": null, "quick_add_magic_mode": "loud", '
      '"quick_add_default_reminders": [600, "x", 1.5, null], '
      '"filter_id_used_on_overview": -1, "minimum_priority": 6, '
      '"comment_sort_order": "newest"}',
    );

    expect(
      settings,
      const UserSettings(quickAddDefaultReminders: [Duration(minutes: 10)]),
    );
  });

  test('only a saved filter counts for the Overview, and only 1 to 5 as '
      'the minimum priority', () {
    UserSettings decode(Object? filterId, Object? minimumPriority) =>
        decodeUserSettings(
          '{"filter_id_used_on_overview": ${filterId ?? 'null'}, '
          '"minimum_priority": ${minimumPriority ?? 'null'}}',
        );

    expect(decode(-2, 1).filterIdUsedOnOverview, -2);
    expect(decode(-2, 1).minimumPriority, 1);
    expect(decode(-14, 5).minimumPriority, 5);
    for (final odd in [-1, 0, 7, null, '"-14"', -2.5]) {
      expect(decode(odd, 3).filterIdUsedOnOverview, isNull, reason: '$odd');
    }
    for (final odd in [0, -1, 6, null, '"3"', 2.5]) {
      expect(decode(-2, odd).minimumPriority, 0, reason: '$odd');
    }
  });

  test('settings stored before these fields existed read as unset', () {
    final settings = decodeUserSettings('{"week_start": 1}');

    expect(settings.filterIdUsedOnOverview, isNull);
    expect(settings.minimumPriority, 0);
    expect(settings.effectiveMinimumPriority, 2);
    expect(settings.commentSortOrder, CommentSortOrder.oldestFirst);
  });

  test('every date display, time format, colour scheme and default view '
      'round-trips', () {
    for (final display in DateDisplay.values) {
      final settings = UserSettings(dateDisplay: display);
      expect(decodeUserSettings(encodeUserSettings(settings)), settings);
    }
    for (final format in TimeFormat.values) {
      final settings = UserSettings(timeFormat: format);
      expect(decodeUserSettings(encodeUserSettings(settings)), settings);
    }
    for (final schema in ColorSchema.values) {
      final settings = UserSettings(colorSchema: schema);
      expect(decodeUserSettings(encodeUserSettings(settings)), settings);
    }
    for (final kind in ProjectViewKind.values) {
      final settings = UserSettings(defaultViewKind: kind);
      expect(decodeUserSettings(encodeUserSettings(settings)), settings);
    }
  });

  test('unset display settings are not stored, so they stay unset', () {
    final encoded = encodeUserSettings(const UserSettings());

    expect(encoded, isNot(contains('date_display')));
    expect(encoded, isNot(contains('time_format')));
    expect(encoded, isNot(contains('default_view')));
    expect(encoded, contains('"color_schema":"auto"'));
  });

  test('settings stored before the display settings read as never set', () {
    final settings = decodeUserSettings(
      '{"week_start": 1, "timezone": "Europe/Berlin", '
      '"comment_sort_order": "desc"}',
    );

    expect(settings.dateDisplay, isNull);
    expect(settings.timeFormat, isNull);
    expect(settings.colorSchema, ColorSchema.auto);
    expect(settings.defaultViewKind, isNull);
    expect(settings.commentSortOrder, CommentSortOrder.newestFirst);
  });

  test('odd display settings fall back to unset and auto', () {
    for (final odd in ['5', '"Relative"', '"12H"', '"first"', 'null', '[]']) {
      final settings = decodeUserSettings(
        '{"date_display": $odd, "time_format": $odd, '
        '"color_schema": $odd, "default_view": $odd}',
      );

      expect(settings, const UserSettings(), reason: odd);
    }
  });

  test('comments come oldest first unless the stored order says desc', () {
    CommentSortOrder decode(String value) =>
        decodeUserSettings('{"comment_sort_order": $value}').commentSortOrder;

    expect(decode('"desc"'), CommentSortOrder.newestFirst);
    expect(decode('"asc"'), CommentSortOrder.oldestFirst);
    for (final odd in ['"DESC"', '""', 'null', '1', '["desc"]']) {
      expect(decode(odd), CommentSortOrder.oldestFirst, reason: odd);
    }
    expect(
      encodeUserSettings(
        const UserSettings(commentSortOrder: CommentSortOrder.newestFirst),
      ),
      contains('"comment_sort_order":"desc"'),
    );
  });

  test('settings stored before the account settings page read as the '
      "server's defaults for a new user", () {
    final settings = decodeUserSettings('{"week_start": 1}');

    expect(settings.name, '');
    expect(settings.emailRemindersEnabled, isFalse);
    expect(settings.discoverableByName, isFalse);
    expect(settings.discoverableByEmail, isFalse);
    expect(settings.overdueTasksRemindersEnabled, isTrue);
    expect(settings.overdueTasksRemindersTime, const ClockTime(9, 0));
  });

  test('odd account fields fall back one by one', () {
    final settings = decodeUserSettings(
      '{"name": 5, "email_reminders_enabled": "yes", '
      '"discoverable_by_name": 1, "discoverable_by_email": null, '
      '"overdue_tasks_reminders_enabled": "no", '
      '"overdue_tasks_reminders_time": "25:00"}',
    );

    expect(settings, const UserSettings());
  });
}
