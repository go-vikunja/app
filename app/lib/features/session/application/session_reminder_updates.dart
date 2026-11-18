import 'dart:async';

import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/notifications/session_reminders.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/notifications/application/os_notification_capabilities.dart';

part 'session_reminder_updates.g.dart';

/// Keeps the session reminder of every signed-in user account in step
/// while the shell listens: after each write to the account's `sync_state`
/// (a sync or an activity sync completing, which a return to the front
/// starts too), and for all of them when the notification permission
/// (read again on every return) or the device's language changes and when
/// an account needs a new sign-in or has signed in again. The ids of the
/// user accounts.
@Riverpod(keepAlive: true)
Set<String> sessionReminderUpdates(Ref ref) {
  // Compared as a string, so a registry write that changes other fields
  // does not rebuild this.
  final joined = ref.watch(
    accountsProvider.select(
      (accounts) => accounts.value?.accounts
          .where((entry) => !entry.account.isLinkShare)
          .map((entry) => '${entry.id}\t${entry.account.needsReauth}')
          .join('\n'),
    ),
  );
  if (joined == null || joined.isEmpty) return const {};
  final accounts = [
    for (final line in joined.split('\n'))
      if (line.split('\t') case [final id, final needsReauth])
        (id: id, needsReauth: needsReauth == 'true'),
  ];
  final ids = {for (final account in accounts) account.id};
  final reminders = ref.watch(sessionRemindersProvider);
  void updateAll() {
    for (final id in ids) {
      reminders.updateQuietly(id, force: true);
    }
  }

  final subscriptions = <StreamSubscription<Object?>>[
    for (final account in accounts)
      if (!account.needsReauth)
        _syncStateWrites(
          ref,
          account.id,
        ).listen((_) => reminders.updateQuietly(account.id)),
  ];
  ref
    ..listen(osNotificationCapabilitiesProvider, (previous, next) {
      final before = previous?.value?.permission;
      if (before != null && before != next.value?.permission) updateAll();
    })
    ..listen(deviceAppLocalizationsProvider, (_, _) => updateAll())
    ..onDispose(() {
      for (final subscription in subscriptions) {
        unawaited(subscription.cancel());
      }
    });
  updateAll();
  return ids;
}

Stream<Object?> _syncStateWrites(Ref ref, String accountId) {
  final db = ref.watch(appDatabaseProvider(accountId));
  return db.tableUpdates(TableUpdateQuery.onTable(db.syncState));
}
