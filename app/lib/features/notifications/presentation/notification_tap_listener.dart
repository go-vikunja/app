import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/notifications/notification_actions.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/accounts/application/account_switcher.dart';
import 'package:vikunja_mobile/features/notifications/application/notification_providers.dart';
import 'package:vikunja_mobile/features/notifications/presentation/notifications_section.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

final _log = Logger('NotificationTap');

/// Opens the task a tapped notification names, whether the tap arrives
/// while the app runs or launched it: waits for the shell, switches to the
/// notification's account when another one is active, then shows the
/// detail sheet over the Overview, or over a page that covers the shell
/// (the edit page keeps its unsaved changes). A test notification opens
/// the Account tab. Signed out, the tap is dropped.
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
    if (payload.taskId == testNotificationTaskId) {
      await _openAccountTab();
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
      found = await _firstTask(repository.read().watchTask(payload.taskId));
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
            SnackBar(content: Text(context.l10n.notificationTaskGone)),
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

  /// The test notification's tap: a visible result on the Account tab too,
  /// where the button that sent it lives.
  Future<void> _openAccountTab() {
    ref.read(rootModalRoutesProvider).closeAll();
    if (_router.routerDelegate.state.matchedLocation != AppRoutes.account) {
      _router.go(AppRoutes.account);
      return Future.value();
    }
    return _showAfterFrame(
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

/// `Stream.first` waits for the cancel; this does not, so a source whose
/// cancel never completes cannot hold the tap.
Future<Task?> _firstTask(Stream<Task?> stream) {
  final completer = Completer<Task?>();
  late final StreamSubscription<Task?> subscription;
  subscription = stream.listen(
    (value) {
      if (!completer.isCompleted) completer.complete(value);
      unawaited(subscription.cancel());
    },
    onError: (Object error, StackTrace stack) {
      if (!completer.isCompleted) completer.completeError(error, stack);
      unawaited(subscription.cancel());
    },
    onDone: () {
      if (!completer.isCompleted) completer.complete(null);
    },
  );
  return completer.future;
}
