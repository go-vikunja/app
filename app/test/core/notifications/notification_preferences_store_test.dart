import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/notifications/notification_preferences.dart';
import 'package:vikunja_mobile/core/notifications/notification_preferences_store.dart';

import '../../helpers/auth_fakes.dart';

void main() {
  late MemoryPreferencesStore preferences;
  late StoredNotificationPreferences store;

  setUp(() {
    preferences = MemoryPreferencesStore();
    store = StoredNotificationPreferences(preferences);
    addTearDown(store.dispose);
  });

  test('defaults to everything on', () async {
    expect(await store.read('a1'), const NotificationPreferences());
  });

  test('writes JSON under notifications.<accountId>, reads it back and '
      'reports the change', () async {
    final changes = <(String, NotificationPreferences)>[];
    store.changes.listen(changes.add);

    await store.write('a1', const NotificationPreferences(dueDates: false));
    await pumpEventQueue();

    expect(
      preferences.values['notifications.a1'],
      '{"reminders":true,"dueDates":false,"activity":true}',
    );
    expect(
      await store.read('a1'),
      const NotificationPreferences(dueDates: false),
    );
    expect(await store.read('a2'), const NotificationPreferences());
    expect(changes, [('a1', const NotificationPreferences(dueDates: false))]);
  });

  test(
    'activity is stored too; a value written without it reads as on',
    () async {
      await store.write('a1', const NotificationPreferences(activity: false));
      preferences.values['notifications.a2'] =
          '{"reminders":false,"dueDates":true}';

      expect(
        await store.read('a1'),
        const NotificationPreferences(activity: false),
      );
      expect(
        await store.read('a2'),
        const NotificationPreferences(reminders: false),
      );
      expect(const NotificationPreferences(activity: false).anyEnabled, isTrue);
      expect(
        const NotificationPreferences(
          reminders: false,
          dueDates: false,
        ).anyEnabled,
        isFalse,
      );
    },
  );

  test('an unreadable value counts as the defaults', () async {
    preferences.values['notifications.a1'] = 'not json';
    preferences.values['notifications.a2'] = '{"reminders":"yes"}';

    expect(await store.read('a1'), const NotificationPreferences());
    expect(await store.read('a2'), const NotificationPreferences());
  });

  test('delete removes the key', () async {
    await store.write('a1', const NotificationPreferences(reminders: false));

    await store.delete('a1');

    expect(preferences.values, isEmpty);
    expect(await store.read('a1'), const NotificationPreferences());
  });
}
