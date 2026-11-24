import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/notifications/notification_payload_records.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';

final class _CountingPreferences implements PrefixedPreferencesStore {
  final Map<String, String> values = {};
  final List<String> writes = [];

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async {
    writes.add('set $key');
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    writes.add('remove $key');
    values.remove(key);
  }

  @override
  Future<Map<String, String>> stringsUnder(String prefix) async => {
    for (final MapEntry(:key, :value) in values.entries)
      if (key.startsWith(prefix)) key: value,
  };
}

void main() {
  late _CountingPreferences preferences;
  late NotificationPayloadRecords records;

  setUp(() {
    preferences = _CountingPreferences();
    records = NotificationPayloadRecords(preferences);
  });

  test("keeps one preference per id, also for a session reminder's "
      'negative id, and reads only its own', () async {
    preferences.values['notifications.permissionAsked'] = 'true';
    preferences.values['notifications.payload.old'] = 'no id';
    await records.put(77, 'a');
    await records.put(-12, 'b');

    expect(await records.all(), {77: 'a', -12: 'b'});
    expect(preferences.values['notifications.payload.77'], 'a');
    expect(preferences.values['notifications.payload.-12'], 'b');
  });

  test('a payload kept already is not written again; another one replaces '
      'it', () async {
    await records.put(77, 'a');
    await records.put(77, 'a');
    await records.put(77, 'b');

    expect(preferences.writes, [
      'set notifications.payload.77',
      'set notifications.payload.77',
    ]);
    expect(await records.all(), {77: 'b'});
  });

  test('removes what is kept and writes nothing for the rest', () async {
    await records.put(77, 'a');
    await records.put(78, 'b');
    preferences.writes.clear();

    await records.removeAll([77, 99]);

    expect(preferences.writes, ['remove notifications.payload.77']);
    expect(await records.all(), {78: 'b'});
  });
}
