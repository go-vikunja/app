import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/links/widget_link_key.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/notifications/notification_actions.dart';
import 'package:vikunja_mobile/core/notifications/notification_gateway.dart';
import 'package:vikunja_mobile/core/notifications/notification_os_ids.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
import 'package:vikunja_mobile/core/text/server_address_display.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/l10n/generated/app_localizations.dart';

part 'session_reminders.g.dart';

final _log = Logger('SessionReminders');

/// The account's reminder in [NotificationOsIds]' reserved range, the same
/// in every isolate.
int sessionReminderOsId(String accountId) {
  final digest = sha256.convert(utf8.encode('$accountId:session')).bytes;
  final hash =
      (digest[0] << 24) | (digest[1] << 16) | (digest[2] << 8) | digest[3];
  const span =
      NotificationOsIds.sessionRemindersLast -
      NotificationOsIds.sessionRemindersFirst +
      1;
  return NotificationOsIds.sessionRemindersFirst + (hash & 0x7fffffff) % span;
}

/// When the account's sync or its activity sync last completed, null
/// before either did. Each starts with a request that refreshes an access
/// token about to expire, so the session's 72 hours (D22) began at most one
/// access token's lifetime (10 minutes) before.
DateTime? lastServerContact(Map<String, String> syncState) {
  DateTime? read(String key) =>
      DateTime.tryParse(syncState[key] ?? '')?.toUtc();
  final synced = read(SyncStateKeys.lastSyncedAt);
  final activity = read(SyncStateKeys.activitySyncedAt);
  if (synced == null || activity == null) return synced ?? activity;
  return synced.isAfter(activity) ? synced : activity;
}

/// [at] when it falls in the day, from 08:00 to 21:00 local time by
/// [utcOffsetAt]; otherwise the 21:00 that begins its night.
DateTime beforeTheNight(
  DateTime at,
  Duration Function(DateTime utc) utcOffsetAt,
) {
  final utc = at.toUtc();
  final local = utc.add(utcOffsetAt(utc));
  if (local.hour >= 8 && local.hour < 21) return utc;
  final evening = DateTime.utc(
    local.year,
    local.month,
    local.day - (local.hour < 8 ? 1 : 0),
    21,
  );
  // The offset of the evening itself, which a change to or from summer
  // time in the night makes differ from the offset at [at].
  return evening.subtract(utcOffsetAt(evening.subtract(utcOffsetAt(utc))));
}

/// The reminder to open the app before a user account's session ends: the
/// server ends it 72 hours after the last refresh (D22), which only a
/// contact with the server makes, and the background sync may not run
/// (iOS, a restricted app on Android). One per signed-in user account,
/// [ahead] of that end counted from [lastServerContact], or at the 21:00
/// before when that falls in the night ([beforeTheNight]), on the
/// activity channel, while the OS lets the app notify: like the "Sign in
/// again" notice, whatever the account's Activity switch says. Never for a
/// link-share guest, whose session signs in again with the link's hash
/// (D62). Headless: a background run uses it like the app.
final class SessionReminders {
  new({
    required this._gateway,
    required this._account,
    required this._lastContact,
    required this._l10n,
    Future<String?> Function()? linkKey,
    DateTime Function()? now,
    Duration Function(DateTime utc)? utcOffsetAt,
    this.step = const Duration(hours: 1),
  }) : _linkKey = linkKey ?? _noLinkKey,
       _now = now ?? DateTime.now,
       _utcOffsetAt = utcOffsetAt ?? deviceUtcOffsetAt;

  static const sessionLifetime = Duration(hours: 72);
  static const ahead = Duration(hours: 12);

  static const _keyPrefix = 'session-reminder:';

  /// The payload key; a tap only opens the app.
  static String key(String accountId) => '$_keyPrefix$accountId';

  static bool isKey(String key) => key.startsWith(_keyPrefix);

  final NotificationGateway _gateway;

  /// The registry's entry as stored now: another isolate may have ended or
  /// removed the account.
  final Future<Account?> Function(String accountId) _account;
  final Future<DateTime?> Function(String accountId) _lastContact;
  final AppLocalizations Function() _l10n;
  final Future<String?> Function() _linkKey;
  final DateTime Function() _now;
  final Duration Function(DateTime utc) _utcOffsetAt;

  /// A move by less than this leaves the reminder as it is: the app syncs
  /// every minute while it is in front.
  final Duration step;

  static Future<String?> _noLinkKey() async => null;

  /// Per account, the reminder time this instance last decided on, null for
  /// none; absent when it has not decided yet.
  final _decided = <String, DateTime?>{};
  final _requested = <String, bool>{};
  final _running = <String, Future<void>?>{};

  /// Brings the account's reminder in step with its last contact, its
  /// state and what the OS allows. Without [force] nothing happens while
  /// the reminder time stays within [step] of the last decision, so the
  /// triggers that run often (every sync) cost a database read; what the
  /// OS allows and the texts need [force]. Runs of one account are
  /// serialized, and calls during one make it look once more. Gateway
  /// errors propagate.
  Future<void> update(String accountId, {bool force = false}) {
    _requested[accountId] = (_requested[accountId] ?? false) || force;
    return _running[accountId] ??= _loop(accountId)
        .whenComplete(() => _running[accountId] = null);
  }

  /// [update] for the triggers, which have nobody to report to.
  void updateQuietly(String accountId, {bool force = false}) => unawaited(
    update(accountId, force: force).then<void>(
      (_) {},
      onError: (Object error) => _log.warning(
        'Could not plan the session reminder of account $accountId: '
        '${error.runtimeType}',
      ),
    ),
  );

  /// Sign-out: after a run in progress, so that it cannot schedule it
  /// again.
  Future<void> cancel(String accountId) async {
    _requested.remove(accountId);
    await _running[accountId]?.then<void>((_) {}, onError: (Object _) {});
    _decided.remove(accountId);
    await _gateway.cancel(sessionReminderOsId(accountId));
  }

  Future<void> _loop(String accountId) async {
    while (_requested.containsKey(accountId)) {
      final force = _requested.remove(accountId)!;
      await _update(accountId, force: force);
    }
  }

  Future<void> _update(String accountId, {required bool force}) async {
    final account = await _account(accountId);
    if (account != null && account.isLinkShare) return;
    final fireAt = account == null || account.needsReauth
        ? null
        : await _reminderTime(accountId);
    if (!force &&
        _decided.containsKey(accountId) &&
        _near(_decided[accountId], fireAt)) {
      return;
    }
    if (fireAt == null) {
      await _gateway.cancel(sessionReminderOsId(accountId));
      _decided[accountId] = null;
      return;
    }
    // It has fired, or the OS holds it for now: what the tray shows stays
    // until a contact moves it.
    if (!fireAt.isAfter(_now())) return;
    final osId = sessionReminderOsId(accountId);
    // What the tray shows is from an earlier contact.
    await _gateway.cancel(osId);
    if ((await _gateway.capabilities()).permission ==
        NotificationPermission.granted) {
      final l10n = _l10n();
      await _gateway.scheduleActivity(
        osId: osId,
        fireAt: fireAt,
        title: l10n.sessionReminderNotificationTitle(
          displayHost(account!.serverRoot),
        ),
        body: l10n.sessionReminderNotificationBody(account.username),
        payload: NotificationPayload(
          accountId: accountId,
          taskId: 0,
          key: key(accountId),
          linkKey: await _linkKey(),
        ).toJson(),
      );
      // A sign-out in another isolate cancels the reminder only after it
      // removed the account, so one removed by now may have missed this.
      if (await _account(accountId) == null) {
        await _gateway.cancel(osId);
        _decided[accountId] = null;
        return;
      }
      _log.fine('Session reminder of account $accountId at $fireAt');
    }
    _decided[accountId] = fireAt;
  }

  /// A contact the device clock puts ahead of now counts as now. Once the
  /// 21:00 a night-time reminder was moved to has come, it counts as due:
  /// a later run in the night, such as a background run whose sync
  /// failed, would otherwise take it from the tray and ring it again.
  Future<DateTime?> _reminderTime(String accountId) async {
    final contact = await _lastContact(accountId);
    if (contact == null) return null;
    final now = _now().toUtc();
    final from = contact.isAfter(now) ? now : contact;
    return beforeTheNight(from.add(sessionLifetime - ahead), _utcOffsetAt);
  }

  bool _near(DateTime? decided, DateTime? fireAt) {
    if (decided == null || fireAt == null) return decided == fireAt;
    return decided.difference(fireAt).abs() < step;
  }
}

@Riverpod(keepAlive: true)
SessionReminders sessionReminders(Ref ref) {
  final registry = ref.watch(accountRegistryProvider);
  return SessionReminders(
    gateway: ref.watch(notificationGatewayProvider),
    account: (accountId) async => (await registry.find(accountId))?.account,
    lastContact: (accountId) async => lastServerContact(
      await ref.read(appDatabaseProvider(accountId)).syncStateDao.readAll(),
    ),
    l10n: () => ref.read(deviceAppLocalizationsProvider),
    linkKey: () => readWidgetLinkKey(ref.read(preferencesStoreProvider)),
    now: ref.watch(clockProvider),
    utcOffsetAt: ref.watch(utcOffsetAtProvider),
  );
}
