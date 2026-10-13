import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:vikunja_mobile/core/notifications/notification_preferences.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';

final _log = Logger('NotificationPreferences');

/// `notifications.<accountId>` in the preferences store, as JSON. A value
/// that cannot be read counts as the defaults.
final class StoredNotificationPreferences
    implements NotificationPreferencesStore {
  new(this._store);

  static String keyFor(String accountId) => 'notifications.$accountId';

  final PreferencesStore _store;
  final _changes =
      StreamController<(String, NotificationPreferences)>.broadcast();

  @override
  Stream<(String accountId, NotificationPreferences preferences)> get changes =>
      _changes.stream;

  @override
  Future<NotificationPreferences> read(String accountId) async {
    final json = await _store.getString(keyFor(accountId));
    if (json == null) return const NotificationPreferences();
    try {
      final decoded = jsonDecode(json);
      if (decoded case {
        'reminders': final bool reminders,
        'dueDates': final bool dueDates,
      }) {
        return NotificationPreferences(
          reminders: reminders,
          dueDates: dueDates,
          // Stored before step 16 without the key: on, like a new account.
          activity: switch (decoded) {
            {'activity': final bool activity} => activity,
            _ => true,
          },
        );
      }
    } on FormatException {
      // Falls through to the defaults.
    }
    _log.warning('Unreadable notification preferences of account $accountId');
    return const NotificationPreferences();
  }

  @override
  Future<void> write(
    String accountId,
    NotificationPreferences preferences,
  ) async {
    await _store.setString(
      keyFor(accountId),
      jsonEncode({
        'reminders': preferences.reminders,
        'dueDates': preferences.dueDates,
        'activity': preferences.activity,
      }),
    );
    if (!_changes.isClosed) _changes.add((accountId, preferences));
  }

  @override
  Future<void> delete(String accountId) => _store.remove(keyFor(accountId));

  void dispose() => unawaited(_changes.close());
}
