import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/settings/user_settings_json.dart';

void main() {
  test('round-trips every field', () {
    const settings = UserSettings(
      defaultProjectId: 12,
      weekStart: 1,
      timezone: 'Europe/Berlin',
      language: 'de-DE',
      quickAddMagicMode: QuickAddMagicMode.todoist,
      quickAddDefaultReminders: [Duration(minutes: -15), Duration(days: 1)],
      filterIdUsedOnOverview: -553,
      minimumPriority: 4,
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
      '"filter_id_used_on_overview": -1, "minimum_priority": 6}',
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
  });
}
