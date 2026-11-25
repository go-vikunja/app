import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/activity/activity_item.dart';
import 'package:vikunja_mobile/core/activity/activity_tray.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/links/widget_link_key.dart';
import 'package:vikunja_mobile/core/notifications/notification_actions.dart';
import 'package:vikunja_mobile/core/notifications/session_reminders.dart';
import 'package:vikunja_mobile/core/repositories/activity_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/inbox/application/local_task_lookup.dart';
import 'package:vikunja_mobile/features/notifications/application/notification_providers.dart';
import 'package:vikunja_mobile/features/notifications/presentation/notifications_section.dart';
import 'package:vikunja_mobile/features/tasks/presentation/open/task_opener.dart';

final _log = Logger('NotificationTap');

/// Opens the task a tapped notification names, whether the tap arrives
/// while the app runs or launched it, through the [TaskOpener]: once the
/// shell shows, in the notification's account, with the detail sheet over
/// the Overview or over a page that covers the shell. The tap lets the
/// dialogs and sheets go as if the user went back, so one that asks on Back,
/// such as the New task sheet with typed text, asks first. An activity
/// notification is marked read first and opens the inbox when it names no
/// task, a team membership its team, and the one that stands for several the
/// inbox; a test notification and one about an ended session open the
/// Account tab, after the pages over the shell went as if the user went back
/// (the edit page asks first). The reminder to open the app before a session
/// ends only opens it. Signed out, the tap is dropped. All this only for a
/// payload with the install's widget-link key: on Android any app can make
/// one up, so a tap without it (or from a notification scheduled before the
/// key) never switches accounts silently and marks nothing read; its task
/// opens like a task link from outside, which asks first, and the rest opens
/// only in the active account.
class NotificationTapListener extends ConsumerStatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<NotificationTapListener> createState() =>
      _NotificationTapListenerState();
}

class _NotificationTapListenerState
    extends ConsumerState<NotificationTapListener> {
  late final TaskOpener _opener;
  late final Future<String?> _linkKey;
  StreamSubscription<String>? _taps;

  @override
  void initState() {
    super.initState();
    _opener = ref.read(taskOpenerProvider);
    _linkKey = readWidgetLinkKey(ref.read(preferencesStoreProvider));
    final source = ref.read(notificationTapSourceProvider);
    _taps = source.taps.listen(_onPayload);
    unawaited(
      source.launchPayload().then(
        (payload) {
          if (payload != null) _onPayload(payload);
        },
        onError: (Object error) => _log.fine(
          'Could not read the launch notification: ${error.runtimeType}',
        ),
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_taps?.cancel());
    super.dispose();
  }

  void _onPayload(String json) {
    if (!mounted) return;
    final NotificationPayload payload;
    try {
      payload = NotificationPayload.fromJson(json);
    } on FormatException {
      _log.fine('Ignoring a notification without a readable payload');
      return;
    }
    // Opening the app is all it asks for: in front, the app syncs every
    // account's activity, which keeps the sessions alive.
    if (SessionReminders.isKey(payload.key)) return;
    unawaited(
      _linkKey.then((key) {
        if (!mounted) return;
        final open = widgetLinkKeyMatches(payload.linkKey, key)
            ? _open
            : _openForeign;
        // A tap during an opening waits for it: the last one wins.
        _opener.request(
          () => open(payload).catchError((Object error) {
            _log.warning(
              'Could not open the tapped notification: ${error.runtimeType}',
            );
          }),
        );
      }),
    );
  }

  Future<void> _openForeign(NotificationPayload payload) async {
    _log.fine('A notification tap without the link key: no account switch');
    // 0 names no task: a test notification or a task-less activity.
    final namesTask =
        payload.taskId != 0 &&
        !ActivityTray.isSessionKey(payload.key) &&
        !ActivityTray.isMoreKey(payload.key);
    if (namesTask) {
      await _opener.openLink(
        TaskDeepLink(TaskById(payload.taskId), account: payload.accountId),
      );
      return;
    }
    if (!mounted || !_opener.isActive(payload.accountId)) return;
    if (ActivityTray.isSessionKey(payload.key)) {
      await _openAccountTab(confirmTest: false);
    } else if (ActivityTray.isMoreKey(payload.key) ||
        ActivityTray.activityIdOf(payload.key) != null) {
      await _openInbox();
    } else if (payload.taskId == testNotificationTaskId) {
      await _openAccountTab(confirmTest: true);
    }
  }

  /// The active account's repositories are read only once the payload's
  /// account is active, and again after the await: a switch may have been
  /// overtaken by another one.
  Future<void> _open(NotificationPayload payload) async {
    if (!mounted || !await _opener.activate(payload.accountId) || !mounted) {
      return;
    }
    if (ActivityTray.isSessionKey(payload.key)) {
      await _openAccountTab(confirmTest: false);
      return;
    }
    if (ActivityTray.isMoreKey(payload.key)) {
      await _openInbox();
      return;
    }
    final activityId = ActivityTray.activityIdOf(payload.key);
    int? commentId;
    if (activityId != null) {
      final stored = await _storedActivity(payload.accountId, activityId);
      commentId = stored == null ? null : commentIdOf(stored);
      await _markActivityRead(payload.accountId, activityId);
      if (!mounted || !_opener.isActive(payload.accountId)) return;
      if (payload.taskId == 0) {
        switch (_teamOf(stored)) {
          case final teamId?:
            await _openTeam(teamId);
          case null:
            await _openInbox();
        }
        return;
      }
    }
    if (payload.taskId == testNotificationTaskId) {
      await _openAccountTab(confirmTest: true);
      return;
    }
    final found = await _opener.withAccount(
      accountTaskRepositoryProvider(payload.accountId),
      (tasks) => findLocalTask(tasks, payload.taskId),
    );
    if (!mounted || !_opener.isActive(payload.accountId)) return;
    if (found == null) {
      await _opener.showMessage(
        (l10n) => activityId == null
            ? l10n.notificationTaskGone
            : l10n.inboxTaskNotLocal,
      );
      return;
    }
    await _opener.showTask(found, commentId: commentId);
  }

  /// The stored notification, for the comment or team it names, which the
  /// payload does not carry; null when it cannot be read.
  Future<ServerNotification?> _storedActivity(
    String accountId,
    int activityId,
  ) async {
    try {
      return await _opener.withAccount(
        accountActivityRepositoryProvider(accountId),
        (activity) => activity.find(activityId),
      );
    } on Object catch (error) {
      _log.fine('Could not read the tapped notification: ${error.runtimeType}');
      return null;
    }
  }

  static int? _teamOf(ServerNotification? stored) {
    if (stored == null) return null;
    final item = ActivityItem.fromNotification(stored);
    return item.kind == ActivityKind.teamMemberAdded ? item.teamId : null;
  }

  /// Read on the notification's account, which need not be active yet; a
  /// failure leaves it unread.
  Future<void> _markActivityRead(String accountId, int activityId) async {
    try {
      await _opener.withAccount(
        accountActivityRepositoryProvider(accountId),
        (activity) => activity.markRead(activityId),
      );
    } on Object catch (error) {
      _log.warning(
        'Could not mark the tapped notification read: ${error.runtimeType}',
      );
    }
  }

  Future<void> _openInbox() => _push(AppRoutes.inbox);

  Future<void> _openTeam(int teamId) => _push(AppRoutes.team(teamId));

  Future<void> _push(String location) async {
    if (!await _opener.leaveDialogsAndSheets() || !mounted) return;
    final router = _opener.router;
    if (router.routerDelegate.state.matchedLocation != location) {
      unawaited(router.push(location));
    }
  }

  /// The Account tab shows the banner of an ended session. The test
  /// notification's tap with [confirmTest] has a visible result there too,
  /// where the button that sent it lives.
  Future<void> _openAccountTab({required bool confirmTest}) async {
    final router = _opener.router;
    if (router.routerDelegate.state.matchedLocation != AppRoutes.account) {
      if (await _opener.leavePagesOverShell() && mounted) {
        router.go(AppRoutes.account);
      }
      return;
    }
    if (!await _opener.leaveDialogsAndSheets() || !confirmTest) return;
    await _opener.showMessage((l10n) => l10n.notificationTestReceived);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
