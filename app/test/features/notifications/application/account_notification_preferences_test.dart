import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/notifications/notification_preferences.dart';
import 'package:vikunja_mobile/core/notifications/notification_providers.dart';
import 'package:vikunja_mobile/features/notifications/application/account_notification_preferences.dart';

void main() {
  late _HeldPreferences store;
  late ProviderContainer container;

  setUp(() {
    store = _HeldPreferences();
    container = ProviderContainer(
      overrides: [
        notificationPreferencesStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
  });

  test('a read that ends after the switches were left is dropped, with the '
      'stored value or a failure', () async {
    for (final id in ['alice', 'bob']) {
      container
          .listen(accountNotificationPreferencesProvider(id), (_, _) {})
          .close();
    }
    await pumpEventQueue();
    expect(
      container.exists(accountNotificationPreferencesProvider('alice')),
      isFalse,
    );
    expect(
      container.exists(accountNotificationPreferencesProvider('bob')),
      isFalse,
    );

    store.reads['alice']!.complete(const NotificationPreferences());
    store.reads['bob']!.completeError(StateError('unreadable'));
    await pumpEventQueue();
  });

  test('the stored value once read, then each write to this account', () async {
    const off = NotificationPreferences(reminders: false);
    final values = <NotificationPreferences?>[];
    container.listen(
      accountNotificationPreferencesProvider('alice'),
      (_, next) => values.add(next.value),
    );

    store.reads['alice']!.complete(const NotificationPreferences());
    await pumpEventQueue();
    await store.write('bob', off);
    await store.write('alice', off);
    await pumpEventQueue();

    expect(values, [const NotificationPreferences(), off]);
  });
}

final class _HeldPreferences implements NotificationPreferencesStore {
  final reads = <String, Completer<NotificationPreferences>>{};
  final _changes =
      StreamController<(String, NotificationPreferences)>.broadcast();

  @override
  Future<NotificationPreferences> read(String accountId) =>
      (reads[accountId] = Completer<NotificationPreferences>()).future;

  @override
  Future<void> write(
    String accountId,
    NotificationPreferences preferences,
  ) async {
    _changes.add((accountId, preferences));
  }

  @override
  Future<void> delete(String accountId) async {}

  @override
  Stream<(String, NotificationPreferences)> get changes => _changes.stream;
}
