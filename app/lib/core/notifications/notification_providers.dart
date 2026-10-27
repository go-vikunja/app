import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/activity/activity_tray.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/links/widget_link_key.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/notifications/notification_gateway.dart';
import 'package:vikunja_mobile/core/notifications/notification_preferences.dart';
import 'package:vikunja_mobile/core/notifications/notification_preferences_store.dart';
import 'package:vikunja_mobile/core/notifications/notification_scheduler.dart';
import 'package:vikunja_mobile/core/notifications/notification_schedulers.dart';
import 'package:vikunja_mobile/core/notifications/notification_texts.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/security/privacy_providers.dart';
import 'package:vikunja_mobile/core/security/privacy_settings.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/l10n/generated/app_localizations.dart';

part 'notification_providers.g.dart';

final _log = Logger('Notifications');

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
/// front, and rescheduling everything when the notification content or
/// the app lock changes; a content that shows less also withdraws what the
/// account has in the tray. Null once the account is gone. Disposed with
/// the account's database on sign-out, after which
/// [NotificationSchedulers] still holds it for the wipe.
@Riverpod(keepAlive: true)
NotificationScheduler? notificationScheduler(Ref ref, String accountId) {
  final userId = ref.watch(
    accountsProvider.select(
      (accounts) => accounts.value?.find(accountId)?.account.userId,
    ),
  );
  if (userId == null) return null;
  final l10n = ref.watch(deviceAppLocalizationsProvider);
  final gateway = ref.watch(notificationGatewayProvider);
  final scheduler = NotificationScheduler(
    accountId: accountId,
    userId: userId,
    db: ref.watch(appDatabaseProvider(accountId)),
    gateway: gateway,
    preferences: ref.watch(notificationPreferencesStoreProvider),
    presentation: () async => _presentation(l10n, await _currentPrivacy(ref)),
    window: notificationWindow(),
    linkKey: () => readWidgetLinkKey(ref.read(preferencesStoreProvider)),
    now: ref.watch(clockProvider),
  );
  ref.watch(notificationSchedulersProvider).register(scheduler);
  ref.listen(privacySettingsProvider, (previous, next) {
    if (_changesWhatIsScheduled(previous?.value, next.value)) {
      scheduler.reconcileQuietly(force: true);
    }
    if (_showsLess(previous?.value, next.value)) {
      unawaited(_withdrawShown(gateway, accountId));
    }
  });
  final lifecycle = AppLifecycleListener(onResume: scheduler.reconcileQuietly);
  ref.onDispose(() {
    lifecycle.dispose();
    unawaited(scheduler.dispose());
  });
  scheduler.reconcileQuietly();
  return scheduler;
}

/// The device's privacy settings, which a headless container reads anew
/// for every run: the app may have changed them since the container
/// started, and a run with older ones would schedule every entry again
/// with those.
Future<PrivacySettings> _currentPrivacy(Ref ref) {
  if (ref.read(runsHeadlessProvider)) {
    ref.invalidate(privacySettingsControllerProvider);
  }
  return ref.read(privacySettingsProvider.future);
}

NotificationPresentation _presentation(
  AppLocalizations l10n,
  PrivacySettings settings,
) => (
  describe: describeNotificationsWith(
    l10n,
    content: settings.notificationContent,
  ),
  privacy: _privacyOf(settings),
);

/// Done on iOS asks for the device unlock while the app lock is on, as D39
/// left for the app lock.
NotificationPrivacy _privacyOf(PrivacySettings settings) => NotificationPrivacy(
  hiddenOnLockScreen:
      settings.notificationContent == NotificationContent.hiddenOnLockScreen,
  doneNeedsUnlock: settings.appLock,
);

/// Loading the settings changes nothing; the first value is what the
/// scheduler reads anyway.
bool _changesWhatIsScheduled(PrivacySettings? before, PrivacySettings? after) =>
    before != null &&
    after != null &&
    (before.notificationContent != after.notificationContent ||
        before.appLock != after.appLock);

bool _showsLess(PrivacySettings? before, PrivacySettings? after) =>
    before != null &&
    after != null &&
    before.notificationContent != after.notificationContent &&
    after.notificationContent != NotificationContent.all;

/// Delivered notifications keep the texts and the visibility they were
/// shown with.
Future<void> _withdrawShown(
  NotificationGateway gateway,
  String accountId,
) async {
  try {
    await ActivityTray(gateway).withdrawTaskNotifications(accountId);
  } on Object catch (error) {
    _log.warning(
      'Could not withdraw the notifications of account $accountId: '
      '${error.runtimeType}',
    );
  }
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
