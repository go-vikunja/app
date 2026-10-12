import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/notifications/notification_preferences.dart';
import 'package:vikunja_mobile/core/notifications/notification_preferences_store.dart';
import 'package:vikunja_mobile/core/notifications/notification_scheduler.dart';
import 'package:vikunja_mobile/core/notifications/notification_schedulers.dart';
import 'package:vikunja_mobile/core/notifications/notification_texts.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';

part 'notification_providers.g.dart';

/// How many of the soonest notifications the OS is given: iOS drops the
/// oldest beyond 64 pending, so some slack stays for the test notification
/// and a snooze; Android has room for more but gains nothing from it.
int notificationWindow([TargetPlatform? platform]) =>
    (platform ?? defaultTargetPlatform) == TargetPlatform.iOS ? 60 : 100;

@Riverpod(keepAlive: true)
NotificationPreferencesStore notificationPreferencesStore(Ref ref) {
  final store = StoredNotificationPreferences(
    ref.watch(preferencesStoreProvider),
  );
  ref.onDispose(store.dispose);
  return store;
}

/// One account's scheduler, reconciling when built (app start, and the
/// first run of a background action) and when the app comes back to the
/// front; null once the account is gone. Disposed with the account's
/// database on sign-out, after which [NotificationSchedulers] still holds
/// it for the wipe.
@Riverpod(keepAlive: true)
NotificationScheduler? notificationScheduler(Ref ref, String accountId) {
  final userId = ref.watch(
    accountsProvider.select(
      (accounts) => accounts.value?.find(accountId)?.account.userId,
    ),
  );
  if (userId == null) return null;
  final scheduler = NotificationScheduler(
    accountId: accountId,
    userId: userId,
    db: ref.watch(appDatabaseProvider(accountId)),
    gateway: ref.watch(notificationGatewayProvider),
    preferences: ref.watch(notificationPreferencesStoreProvider),
    describe: describeNotificationsWith(
      ref.watch(deviceAppLocalizationsProvider),
    ),
    window: notificationWindow(),
    now: ref.watch(clockProvider),
  );
  ref.watch(notificationSchedulersProvider).register(scheduler);
  final lifecycle = AppLifecycleListener(onResume: scheduler.reconcileQuietly);
  ref.onDispose(() {
    lifecycle.dispose();
    unawaited(scheduler.dispose());
  });
  scheduler.reconcileQuietly();
  return scheduler;
}

/// One scheduler per signed-in account while the shell listens, the
/// active one included: the ids of the accounts that have one. A
/// provider nobody listens to is paused, so the shell keeps a listener on
/// it, like on `inactiveOutboxesProvider`.
@Riverpod(keepAlive: true)
Set<String> accountNotificationSchedulers(Ref ref) {
  // The list is value-compared as a string, so a registry write that only
  // changes other fields does not rebuild this.
  final joinedIds = ref.watch(
    accountsProvider.select(
      (accounts) => accounts.value?.accounts.map((e) => e.id).join('\n'),
    ),
  );
  if (joinedIds == null || joinedIds.isEmpty) return const {};
  return {
    for (final accountId in joinedIds.split('\n'))
      if (ref.watch(notificationSchedulerProvider(accountId)) != null)
        accountId,
  };
}
