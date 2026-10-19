import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/router/pop_pages_over_shell.dart';
import 'package:vikunja_mobile/core/activity/activity_tray.dart';
import 'package:vikunja_mobile/core/notifications/notification_actions.dart';
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
/// the Overview or over a page that covers the shell. An activity
/// notification is marked read first and opens the inbox when it names no
/// task, and so does the one that stands for several; a test notification
/// and one about an ended session open the Account tab, after the pages
/// over the shell went as if the user went back (the edit page asks
/// first). Signed out, the tap is dropped.
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
  StreamSubscription<String>? _taps;

  @override
  void initState() {
    super.initState();
    _opener = ref.read(taskOpenerProvider);
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
    // A tap during an opening waits for it: the last one wins.
    _opener.request(
      () => _open(payload).catchError((Object error) {
        _log.warning(
          'Could not open the tapped notification: ${error.runtimeType}',
        );
      }),
    );
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
      _openInbox();
      return;
    }
    final activityId = ActivityTray.activityIdOf(payload.key);
    if (activityId != null) {
      await _markActivityRead(payload.accountId, activityId);
      if (!mounted || !_opener.isActive(payload.accountId)) return;
      if (payload.taskId == 0) {
        _openInbox();
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
    await _opener.showTask(found);
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

  void _openInbox() {
    ref.read(rootModalRoutesProvider).closeAll();
    final router = _opener.router;
    if (router.routerDelegate.state.matchedLocation != AppRoutes.inbox) {
      unawaited(router.push(AppRoutes.inbox));
    }
  }

  /// The Account tab shows the banner of an ended session. The test
  /// notification's tap with [confirmTest] has a visible result there too,
  /// where the button that sent it lives.
  Future<void> _openAccountTab({required bool confirmTest}) async {
    ref.read(rootModalRoutesProvider).closeAll();
    final router = _opener.router;
    if (router.routerDelegate.state.matchedLocation != AppRoutes.account) {
      if (await popPagesOverShell(router) && mounted) {
        router.go(AppRoutes.account);
      }
      return;
    }
    if (!confirmTest) return;
    await _opener.showMessage((l10n) => l10n.notificationTestReceived);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
