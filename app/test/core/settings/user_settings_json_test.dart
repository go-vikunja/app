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
      '"quick_add_default_reminders": [600, "x", 1.5, null]}',
    );

    expect(
      settings,
      const UserSettings(quickAddDefaultReminders: [Duration(minutes: 10)]),
    );
  });
}
