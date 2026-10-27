import 'package:logging/logging.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/activity/activity_item.dart';
import 'package:vikunja_mobile/core/activity/activity_notification_texts.dart';
import 'package:vikunja_mobile/core/activity/activity_tray.dart';
import 'package:vikunja_mobile/core/auth/account_title.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/notifications/notification_actions.dart';
import 'package:vikunja_mobile/core/notifications/notification_gateway.dart';
import 'package:vikunja_mobile/core/notifications/notification_os_ids.dart';
import 'package:vikunja_mobile/core/notifications/notification_preferences.dart';
import 'package:vikunja_mobile/core/security/privacy_settings.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';
import 'package:vikunja_mobile/l10n/generated/app_localizations.dart';

final _log = Logger('ActivityNotifier');

/// Turns new server notifications into OS notifications on the activity
/// channel, and tells the user once when an account's session has ended.
/// Headless, so the background runner uses it like the UI does. The
/// device's privacy choice of what notifications show is read for every
/// run; the session notification holds no task data and ignores it.
final class ActivityNotifier {
  new({
    required this._gateway,
    required this._preferences,
    required this._store,
    required this._l10n,
    this._content = _showEverything,
    this.shownPerRun = 5,
    this.keptPerAccount = 10,
  }) : _tray = ActivityTray(_gateway);

  final NotificationGateway _gateway;
  final NotificationPreferencesStore _preferences;
  final PreferencesStore _store;
  final AppLocalizations _l10n;
  final Future<NotificationContent> Function() _content;
  final ActivityTray _tray;

  static Future<NotificationContent> _showEverything() async =>
      NotificationContent.all;

  /// The newest this many of a run are shown one by one; one more
  /// notification stands for the rest.
  final int shownPerRun;

  /// How many activity notifications an account keeps in the tray.
  final int keptPerAccount;

  /// Set while the "Sign in again" notification of the account's ended
  /// session has been shown; cleared once the account works again.
  static String sessionEndedKey(String accountId) =>
      'notifications.sessionEnded.$accountId';

  /// Shows the kinds that are shown, when the account's activity
  /// preference is on and the OS lets the app notify: the newest
  /// [shownPerRun] one by one, the rest as one "More activity"
  /// notification, then the account's oldest beyond [keptPerAccount] go
  /// from the tray. Marks each of [fresh] handled once it is shown or
  /// deliberately not, so none is ever shown twice, nor later after the
  /// preference was off. A failing gateway throws and leaves the ones not
  /// yet shown to the next run. With [labelled] (several accounts signed
  /// in) each names its account, unless notifications show no titles.
  /// Returns how many were shown one by one.
  Future<int> show({
    required Account account,
    required AppDatabase db,
    required List<ServerNotification> fresh,
    bool labelled = false,
  }) async {
    if (fresh.isEmpty) return 0;
    final dao = db.serverNotificationsDao;
    if (!await _mayShow(account.id)) {
      await dao.markHandled(fresh.map((n) => n.id));
      return 0;
    }
    final content = await _content();
    final described = [
      for (final notification in fresh)
        if (describeActivity(
              ActivityItem.fromNotification(
                notification,
                userId: account.userId,
              ),
              l10n: _l10n,
              content: content,
            )
            case final text?)
          (notification, text),
    ];
    // Oldest first, so the newest ends on top of the tray.
    final oneByOne = described.length > shownPerRun
        ? described.sublist(described.length - shownPerRun)
        : described;
    final subtitle = labelled && content != NotificationContent.noTitles
        ? _label(account)
        : null;
    final group = 'activity:${account.id}';
    final privacy = NotificationPrivacy(
      hiddenOnLockScreen: content == NotificationContent.hiddenOnLockScreen,
    );
    for (final (notification, text) in oneByOne) {
      final key = ActivityTray.activityKey(notification.id);
      await _gateway.showActivity(
        osId: notificationOsIdFor(account.id, key),
        title: text.title,
        body: text.body,
        payload: NotificationPayload(
          accountId: account.id,
          // A deleted task cannot be opened; the tap opens the inbox.
          taskId: notification.name == ActivityKind.taskDeleted.serverName
              ? 0
              : notification.taskId ?? 0,
          key: key,
        ).toJson(),
        subtitle: subtitle,
        group: group,
        privacy: privacy,
      );
      await dao.markHandled([notification.id]);
    }
    final more = described.length - oneByOne.length;
    if (more > 0) {
      final key = ActivityTray.moreKey(account.id);
      await _gateway.showActivity(
        osId: notificationOsIdFor(account.id, key),
        title: _l10n.activityNotificationMoreTitle,
        body: _l10n.activityNotificationMoreBody(more),
        payload: NotificationPayload(
          accountId: account.id,
          taskId: 0,
          key: key,
        ).toJson(),
        subtitle: subtitle,
        group: group,
        privacy: privacy,
      );
    }
    await dao.markHandled(fresh.map((n) => n.id));
    if (oneByOne.isNotEmpty) await _trim(account.id);
    _log.fine(
      'Showed ${oneByOne.length} of ${fresh.length} new notifications, '
      '$more folded',
    );
    return oneByOne.length;
  }

  /// The account's session ended: one notification per ended session.
  /// Nothing when the OS does not let the app notify; a later call tries
  /// again. A guest has no sign-in to do, and its username is made up.
  Future<void> sessionEnded(Account account) async {
    final key = sessionEndedKey(account.id);
    if (await _store.getString(key) != null) return;
    if (!await _permitted()) return;
    final payloadKey = ActivityTray.sessionKey(account.id);
    final host = _host(account.serverRoot);
    await _gateway.showActivity(
      osId: notificationOsIdFor(account.id, payloadKey),
      title: account.isLinkShare
          ? _l10n.guestAccessEndedNotificationTitle(accountTitle(account))
          : _l10n.sessionEndedNotificationTitle(host),
      body: account.isLinkShare
          ? _l10n.guestAccessEndedNotificationBody(host)
          : _l10n.sessionEndedNotificationBody(account.username),
      payload: NotificationPayload(
        accountId: account.id,
        taskId: 0,
        key: payloadKey,
      ).toJson(),
    );
    await _store.setString(key, 'true');
    _log.info('Asked to sign in again to account ${account.id}');
  }

  /// The account signed in again: its "Sign in again" notification goes
  /// from the tray, and the next ended session notifies again.
  Future<void> sessionRestored(String accountId) async {
    final key = sessionEndedKey(accountId);
    if (await _store.getString(key) == null) return;
    await _store.remove(key);
    await _tray.withdrawSession(accountId);
  }

  Future<void> _trim(String accountId) async {
    try {
      await _tray.trim(accountId, keep: keptPerAccount);
    } on Object catch (error) {
      _log.info('Could not look at the tray: ${error.runtimeType}');
    }
  }

  /// What the account switcher shows: `@username · host`.
  String _label(Account account) =>
      _l10n.accountSubtitle(account.username, _host(account.serverRoot));

  static String _host(Uri root) {
    final host = root.host.contains(':') ? '[${root.host}]' : root.host;
    return root.hasPort ? '$host:${root.port}' : host;
  }

  Future<bool> _mayShow(String accountId) async =>
      (await _preferences.read(accountId)).activity && await _permitted();

  Future<bool> _permitted() async =>
      (await _gateway.capabilities()).permission ==
      NotificationPermission.granted;
}
