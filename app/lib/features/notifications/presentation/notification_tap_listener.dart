import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/router/pop_pages_over_shell.dart';
import 'package:vikunja_mobile/core/activity/activity_tray.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/notifications/notification_actions.dart';
import 'package:vikunja_mobile/core/repositories/activity_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/accounts/application/account_switcher.dart';
import 'package:vikunja_mobile/features/inbox/application/local_task_lookup.dart';
import 'package:vikunja_mobile/features/notifications/application/notification_providers.dart';
import 'package:vikunja_mobile/features/notifications/presentation/notifications_section.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

final _log = Logger('NotificationTap');

/// Opens the task a tapped notification names, whether the tap arrives
/// while the app runs or launched it: waits for the shell, switches to the
/// notification's account when another one is active, then shows the
/// detail sheet over the Overview, or over a page that covers the shell
/// (the edit page keeps its unsaved changes). An activity notification is
/// marked read first and opens the inbox when it names no task, and so
/// does the one that stands for several; a test notification and one about
/// an ended session open the Account tab, after the pages over the shell
/// went as if the user went back (the edit page asks first). Signed out,
/// the tap is dropped.
class NotificationTapListener extends ConsumerStatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<NotificationTapListener> createState() =>
      _NotificationTapListenerState();
}

class _NotificationTapListenerState
    extends ConsumerState<NotificationTapListener> {
  late final GoRouter _router;
  StreamSubscription<String>? _taps;
  NotificationPayload? _pending;
  var _opening = false;

  /// How long a switch's registry change may take to reach the providers.
  static const _switchTimeout = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    _router = ref.read(appRouterProvider)
      ..routerDelegate.addListener(_onRouteChanged);
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
    _router.routerDelegate.removeListener(_onRouteChanged);
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
    _pending = payload;
    _openWhenReady();
  }

  void _onRouteChanged() {
    if (_pending != null) _openWhenReady();
  }

  void _openWhenReady() {
    final delegate = _router.routerDelegate;
    if (delegate.currentConfiguration.isEmpty) return;
    final location = delegate.state.matchedLocation;
    if (location == AppRoutes.splash ||
        location == AppRoutes.firstSync ||
        location == AppRoutes.notificationsSetup) {
      return;
    }
    // A tap during an opening waits for it: the last one wins.
    if (_opening) return;
    final payload = _pending;
    _pending = null;
    if (payload == null) return;
    if (!location.startsWith(AppRoutes.home)) return;
    _opening = true;
    unawaited(
      _open(payload)
          .catchError((Object error) {
            _log.warning(
              'Could not open the tapped notification: ${error.runtimeType}',
            );
          })
          .whenComplete(() {
            _opening = false;
            if (mounted) _openWhenReady();
          }),
    );
  }

  /// The active account's repositories are read only once the payload's
  /// account is active, and again after the await: a switch may have been
  /// overtaken by another one.
  Future<void> _open(NotificationPayload payload) async {
    final accounts = ref.read(accountsProvider).value;
    if (accounts?.find(payload.accountId) == null) return;
    if (accounts?.activeAccountId != payload.accountId) {
      final switched = await ref
          .read(accountSwitcherProvider)
          .switchTo(payload.accountId);
      if (!switched || !mounted) return;
      // The shell closes the previous account's modals and resets the tabs
      // when the registry change reaches the providers; a sheet shown
      // before that would go with them.
      if (!await _awaitActiveAccount(payload.accountId) || !mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    if (ref.read(activeAccountIdProvider) != payload.accountId) return;
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
      if (!mounted) return;
      if (ref.read(activeAccountIdProvider) != payload.accountId) return;
      if (payload.taskId == 0) {
        _openInbox();
        return;
      }
    }
    if (payload.taskId == testNotificationTaskId) {
      await _openAccountTab(confirmTest: true);
      return;
    }
    // By account, not the active account's provider, which may not have
    // followed the switch yet; listened to, so it is not disposed meanwhile.
    final repository = ref.listenManual(
      accountTaskRepositoryProvider(payload.accountId),
      (_, _) {},
    );
    final Task? found;
    try {
      found = await findLocalTask(repository.read(), payload.taskId);
    } finally {
      repository.close();
    }
    if (!mounted) return;
    if (ref.read(activeAccountIdProvider) != payload.accountId) return;
    if (found == null) {
      await _showAfterFrame(
        (context) => ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                activityId == null
                    ? context.l10n.notificationTaskGone
                    : context.l10n.inboxTaskNotLocal,
              ),
            ),
          ),
      );
      return;
    }
    final task = found;
    final project = ref
        .read(accountProjectRepositoryProvider(payload.accountId))
        .find(task.projectId);
    ref.read(rootModalRoutesProvider).closeAll();
    // A page over the shell (the edit page, add account) stays; the sheet
    // opens over it. Only a tab is brought back to the Overview.
    final location = _router.routerDelegate.state.matchedLocation;
    if (AppRoutes.isTab(location) && location != AppRoutes.overview) {
      _router.go(AppRoutes.overview);
    }
    await _showAfterFrame(
      (context) =>
          unawaited(showTaskDetail(context, task: task, project: project)),
    );
  }

  /// True once the switch's registry change has reached the providers,
  /// false when it has not within [_switchTimeout].
  Future<bool> _awaitActiveAccount(String accountId) {
    if (ref.read(activeAccountIdProvider) == accountId) {
      return Future.value(true);
    }
    final completer = Completer<bool>();
    final subscription = ref.listenManual(activeAccountIdProvider, (_, next) {
      if (next == accountId && !completer.isCompleted) completer.complete(true);
    });
    return completer.future
        .timeout(_switchTimeout, onTimeout: () => false)
        .whenComplete(subscription.close);
  }

  /// Read on the notification's account, which need not be active yet; a
  /// failure leaves it unread.
  Future<void> _markActivityRead(String accountId, int activityId) async {
    final repository = ref.listenManual(
      accountActivityRepositoryProvider(accountId),
      (_, _) {},
    );
    try {
      await repository.read().markRead(activityId);
    } on Object catch (error) {
      _log.warning(
        'Could not mark the tapped notification read: ${error.runtimeType}',
      );
    } finally {
      repository.close();
    }
  }

  void _openInbox() {
    ref.read(rootModalRoutesProvider).closeAll();
    if (_router.routerDelegate.state.matchedLocation != AppRoutes.inbox) {
      unawaited(_router.push(AppRoutes.inbox));
    }
  }

  /// The Account tab shows the banner of an ended session. The test
  /// notification's tap with [confirmTest] has a visible result there too,
  /// where the button that sent it lives.
  Future<void> _openAccountTab({required bool confirmTest}) async {
    ref.read(rootModalRoutesProvider).closeAll();
    if (_router.routerDelegate.state.matchedLocation != AppRoutes.account) {
      if (await popPagesOverShell(_router) && mounted) {
        _router.go(AppRoutes.account);
      }
      return;
    }
    if (!confirmTest) return;
    await _showAfterFrame(
      (context) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.l10n.notificationTestReceived)),
        ),
    );
  }

  /// With the root navigator's context, which may not be built yet in the
  /// app's first frames. Completes once [show] ran, so the next tap's
  /// `closeAll` sees what this one opened.
  Future<void> _showAfterFrame(
    void Function(BuildContext context) show, {
    int attemptsLeft = 10,
  }) {
    final shown = Completer<void>();
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        final navigatorContext =
            _router.routerDelegate.navigatorKey.currentContext;
        if (!mounted || (navigatorContext == null && attemptsLeft == 0)) {
          shown.complete();
        } else if (navigatorContext == null) {
          shown.complete(_showAfterFrame(show, attemptsLeft: attemptsLeft - 1));
        } else {
          show(navigatorContext);
          shown.complete();
        }
      })
      ..ensureVisualUpdate();
    return shown.future;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
