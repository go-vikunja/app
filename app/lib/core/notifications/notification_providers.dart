import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart'
    show AppLifecycleListener, AppLifecycleState, WidgetsBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/activity/activity_tray.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
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
import 'package:vikunja_mobile/core/widgets/widget_providers.dart';
import 'package:vikunja_mobile/l10n/generated/app_localizations.dart';

part 'notification_providers.g.dart';

final _log = Logger('Notifications');

/// How many of an account's soonest notifications the OS is given. The
/// [accounts] signed in share evenly what the system lets the app hold:
/// iOS keeps 64 pending and drops what goes beyond, so they share 60;
/// Android refuses every alarm once the app holds 500, even one that
/// replaces another under its id, so they share 480, at most 100 each as
/// more gains nothing, the rest left for the widget's redraw alarm and
/// WorkManager's own (decision log: Notifications and widgets). Each share
/// keeps one for the account's reminder to open the app before its session
/// ends (`SessionReminders`) and one for the snoozed entry `diffSchedule`
/// adds beyond the window, both pending too. An even share needs nothing
/// from the other accounts' schedulers, which a headless isolate does not
/// run.
int notificationWindow({TargetPlatform? platform, int accounts = 1}) {
  final sharing = math.max(1, accounts);
  return (platform ?? defaultTargetPlatform) == TargetPlatform.iOS
      ? math.max(1, 60 ~/ sharing - 2)
      : math.min(100, math.max(1, 480 ~/ sharing - 2));
}

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
/// to the front after it was hidden, and rescheduling everything when the
/// notification content, the app lock or the app's language changes; a
/// content that shows less also withdraws what the account has in the
/// tray. Built again, and so reconciling at once, when a refreshed `/info`
/// moves the server to one whose reminders follow the subscriptions, and
/// when the number of accounts changes their share of the window (on
/// Android from five accounts on). Null once the account is gone. Disposed
/// with the account's database on sign-out, after which
/// [NotificationSchedulers] still holds it for the wipe.
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
  final registry = ref.watch(runsHeadlessProvider)
      ? ref.watch(accountRegistryProvider)
      : null;
  final gateway = ref.watch(notificationGatewayProvider);
  final scheduler = NotificationScheduler(
    accountId: accountId,
    userId: user.userId,
    followSubscriptions: user.follow,
    db: ref.watch(appDatabaseProvider(accountId)),
    gateway: gateway,
    preferences: ref.watch(notificationPreferencesStoreProvider),
    presentation: () async {
      final privacy = await currentPrivacySettings(ref);
      return _presentation(ref.read(deviceAppLocalizationsProvider), privacy);
    },
    window: registry == null
        ? () async => window
        : () => _storedAccountsWindow(registry, window),
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
  // On iOS the app imports the widgets' Done taps first: the widget removed
  // their reminders, which this run would schedule again (decision log:
  // Notifications and widgets). Android's widget removes none, and there a
  // rebuild while waiting would lose the first run's re-arm.
  final waitsForWidgetTaps =
      defaultTargetPlatform == TargetPlatform.iOS &&
      !ref.read(runsHeadlessProvider);
  void reconcileStartOrResume({bool rearm = false}) {
    void reconcile() => scheduler.reconcileQuietly(rearm: rearm);
    if (!waitsForWidgetTaps) return reconcile();
    unawaited(afterWidgetTapImports(ref, reconcile));
  }

  // The notification shade, a system dialog and the app lock's own prompt
  // only make the app inactive. A permission or exact-alarm answer that
  // arrives that way reconciles through OsNotificationCapabilities.
  var hidden = !_inFront();
  final lifecycle = AppLifecycleListener(
    onHide: () => hidden = true,
    onResume: () {
      if (!hidden) return;
      hidden = false;
      reconcileStartOrResume();
    },
  );
  ref.onDispose(() {
    lifecycle.dispose();
    unawaited(scheduler.dispose());
  });
  reconcileStartOrResume(rearm: rearmDue && _rearmsFirstRun(ref));
  return scheduler;
}

/// A headless container does not see an account the app signed in after
/// the container read the registry, and its share would then push the
/// accounts past what the system holds (decision log: Notifications and
/// widgets), so each of its runs counts the stored accounts again. The
/// smaller window wins: an unreadable registry reads as empty.
Future<int> _storedAccountsWindow(AccountRegistry registry, int known) async {
  final stored = await registry.load();
  return math.min(known, notificationWindow(accounts: stored.accounts.length));
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

bool _inFront() => switch (WidgetsBinding.instance.lifecycleState) {
  null || AppLifecycleState.resumed || AppLifecycleState.inactive => true,
  _ => false,
};

NotificationPresentation _presentation(
  AppLocalizations l10n,
  PrivacySettings settings,
) => (
  describe: describeNotificationsWith(
    l10n,
    content: settings.notificationContent,
  ),
  privacy: reminderPrivacyOf(settings),
);

/// While the app lock is on, Done on iOS asks for the device unlock, and
/// Android leaves Done out (decision log: Security and privacy).
NotificationPrivacy reminderPrivacyOf(PrivacySettings settings) =>
    NotificationPrivacy(
      hiddenOnLockScreen:
          settings.notificationContent ==
          NotificationContent.hiddenOnLockScreen,
      doneNeedsUnlock: settings.appLock,
    );

/// Loading the settings changes nothing; the first value is what the
/// scheduler reads anyway.
bool _changesWhatIsScheduled(PrivacySettings? before, PrivacySettings? after) =>
    before != null &&
    after != null &&
    (before.notificationContent != after.notificationContent ||
        before.appLock != after.appLock);

/// Turning the app lock on counts: a reminder already shown keeps a Done
/// that runs without the unlock.
bool _showsLess(PrivacySettings? before, PrivacySettings? after) =>
    before != null &&
    after != null &&
    ((before.notificationContent != after.notificationContent &&
            after.notificationContent != NotificationContent.all) ||
        (!before.appLock && after.appLock));

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
