import 'dart:async';
import 'dart:math' as math;

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
import 'package:vikunja_mobile/core/notifications/subscriber_reminders.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/security/privacy_providers.dart';
import 'package:vikunja_mobile/core/security/privacy_settings.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/l10n/generated/app_localizations.dart';

part 'notification_providers.g.dart';

final _log = Logger('Notifications');

/// How many of an account's soonest notifications the OS is given. iOS
/// keeps 64 pending for the whole app and drops what goes beyond, so the
/// [accounts] signed in share 60 evenly, leaving slack for the test
/// notification and a snooze. Each share keeps one for the account's
/// reminder to open the app before its session ends (`SessionReminders`),
/// which is pending too. An even share needs nothing from the other
/// accounts' schedulers, which a headless isolate does not run. Android
/// keeps 100 per account; it has room for more but gains nothing from it.
int notificationWindow({TargetPlatform? platform, int accounts = 1}) =>
    (platform ?? defaultTargetPlatform) == TargetPlatform.iOS
    ? math.max(1, 60 ~/ math.max(1, accounts) - 1)
    : 100;

@Riverpod(keepAlive: true)
NotificationPreferencesStore notificationPreferencesStore(Ref ref) {
  final store = StoredNotificationPreferences(
    ref.watch(preferencesStoreProvider),
  );
  ref.onDispose(store.dispose);
  return store;
}

/// One account's scheduler, reconciling when built (app start, and the
/// first run of a background action; the app's first build in a process
/// re-arms on Android, see [_rearmsFirstRun]) and when the app comes back
/// to the front, and rescheduling everything when the notification
/// content, the app lock or the app's language changes; a content that
/// shows less also withdraws what the account has in the tray. Built
/// again, and so reconciling at once, when a refreshed `/info` moves the
/// server to one whose reminders follow the subscriptions (D80), and on iOS
/// when the number of accounts changes their share of the window. Null
/// once the account is gone. Disposed with the account's database on
/// sign-out, after which [NotificationSchedulers] still holds it for the
/// wipe.
@Riverpod(keepAlive: true)
NotificationScheduler? notificationScheduler(Ref ref, String accountId) {
  final user = ref.watch(
    accountsProvider.select((accounts) {
      final entry = accounts.value?.find(accountId);
      if (entry == null) return null;
      return (userId: entry.account.userId, follow: entry.subscriberId != null);
    }),
  );
  if (user == null) return null;
  final window = ref.watch(
    accountsProvider.select(
      (accounts) =>
          notificationWindow(accounts: accounts.value?.accounts.length ?? 1),
    ),
  );
  final gateway = ref.watch(notificationGatewayProvider);
  final scheduler = NotificationScheduler(
    accountId: accountId,
    userId: user.userId,
    followSubscriptions: user.follow,
    db: ref.watch(appDatabaseProvider(accountId)),
    gateway: gateway,
    preferences: ref.watch(notificationPreferencesStoreProvider),
    presentation: () async {
      final privacy = await _currentPrivacy(ref);
      return _presentation(ref.read(deviceAppLocalizationsProvider), privacy);
    },
    window: window,
    linkKey: () => readWidgetLinkKey(ref.read(preferencesStoreProvider)),
    now: ref.watch(clockProvider),
  );
  final rearmDue = ref
      .watch(notificationSchedulersProvider)
      .register(scheduler);
  ref
    ..listen(privacySettingsProvider, (previous, next) {
      if (_changesWhatIsScheduled(previous?.value, next.value)) {
        scheduler.reconcileQuietly(force: true);
      }
      if (_showsLess(previous?.value, next.value)) {
        unawaited(_withdrawShown(gateway, accountId));
      }
    })
    ..listen(
      deviceAppLocalizationsProvider,
      (_, _) => scheduler.reconcileQuietly(force: true),
    );
  final lifecycle = AppLifecycleListener(onResume: scheduler.reconcileQuietly);
  ref.onDispose(() {
    lifecycle.dispose();
    unawaited(scheduler.dispose());
  });
  scheduler.reconcileQuietly(rearm: rearmDue && _rearmsFirstRun(ref));
  return scheduler;
}

/// Android answers the pending ids from the plugin's own record, which a
/// force stop leaves behind while it drops every alarm, and from which the
/// plugin re-arms only after a boot or an update. So the app's first run
/// of an account in a process schedules everything again. A headless
/// container leaves that to the app: after a force stop, the background
/// runs only come back once the app has run.
bool _rearmsFirstRun(Ref ref) =>
    defaultTargetPlatform == TargetPlatform.android &&
    !ref.read(runsHeadlessProvider);

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
