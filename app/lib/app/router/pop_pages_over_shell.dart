import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/router/root_modal_routes.dart';

/// How long a page or sheet may take to go once its question was answered
/// by leaving it: Save writes first, online for a project, label or team.
const _leaveTimeout = Duration(seconds: 30);

/// How [popPagesOverShell], [popPagesOutsideHome] and [popDialogsAndSheets]
/// ended.
enum LeaveOutcome {
  /// What was to go went: for [popPagesOverShell] a tab is on top, with no
  /// dialog or sheet over it, for [popPagesOutsideHome] a route under
  /// `/home`, for [popDialogsAndSheets] no dialog or sheet over the page on
  /// top.
  left,

  /// The user kept editing, or a page, dialog or sheet would not go.
  stayed,

  /// A question was answered by leaving, but its page or sheet did not go
  /// in time.
  slow,
}

/// Pops the dialogs, sheets and pages that cover the shell, one by one
/// through their `PopScope`, as if the user went back, so that an edit page
/// or a sheet asks before its unsaved changes go; `go` or closing them would
/// drop those without asking. A question one shows is waited for: null or
/// false (Keep editing, a tap beside it) stays, any other answer waits for
/// the page or sheet to go, and a sheet or dialog also for the end of its
/// exit animation. A dialog or sheet that would not ask closes without an
/// exit animation, as an account switch closes them.
Future<LeaveOutcome> popPagesOverShell(GoRouter router) => _popPages(
  router,
  done: (location, modal) => modal == null && AppRoutes.isTab(location),
);

/// Like [popPagesOverShell], but only the pages outside `/home` that cover
/// the shell, such as About, Connection and its editors, with the dialogs
/// and sheets over them; the pages, dialogs and sheets under `/home` stay.
Future<LeaveOutcome> popPagesOutsideHome(GoRouter router) => _popPages(
  router,
  done: (location, _) => location.startsWith(AppRoutes.home),
);

/// Lets the dialogs and sheets go as if the user went back, the newest
/// first, and keeps the pages: one Back would close goes at once without an
/// exit animation, one that asks (the New task sheet with a title typed)
/// asks through its `PopScope` and is waited for. Keep editing, a tap
/// beside the question or a busy sheet stays; one under a page stays with
/// that page.
Future<LeaveOutcome> popDialogsAndSheets(GoRouter router) async {
  final modals = router.observers?.whereType<RootModalRoutes>().firstOrNull;
  while (true) {
    final guarded = modals?.closeDownToGuarded();
    if (guarded == null || !guarded.isCurrent) return LeaveOutcome.left;
    final navigator = guarded.navigator!;
    await navigator.maybePop();
    await WidgetsBinding.instance.endOfFrame;
    bool gone() => !guarded.isActive;
    if (gone()) continue;
    final question = modals!.lastOn(navigator);
    if (question == null || question == guarded) return LeaveOutcome.stayed;
    final answer = await question.popped;
    if (answer == null || answer == false) return LeaveOutcome.stayed;
    if (!await _goes(router.routerDelegate, guarded, gone)) {
      return LeaveOutcome.slow;
    }
  }
}

Future<LeaveOutcome> _popPages(
  GoRouter router, {
  required bool Function(String location, Route<Object?>? modal) done,
}) async {
  final delegate = router.routerDelegate;
  final modals = router.observers?.whereType<RootModalRoutes>().firstOrNull;
  while (true) {
    final navigator = delegate.navigatorKey.currentState;
    if (navigator == null) return LeaveOutcome.left;
    final modal = modals?.lastOn(navigator);
    final top = delegate.state;
    if (done(top.matchedLocation, modal) ||
        (modal == null && !navigator.canPop())) {
      return LeaveOutcome.left;
    }
    // A page pushed from a sheet covers it and goes first.
    final shown = modal != null && modal.isCurrent ? modal : null;
    if (shown != null && shown.popDisposition != RoutePopDisposition.doNotPop) {
      navigator.removeRoute(shown);
      continue;
    }
    // By the page's key, not its location (two pages may share one) nor the
    // route list, which a router refresh decodes anew with the same keys.
    final page = top.pageKey;
    bool gone() =>
        !_holdsPage(delegate.currentConfiguration.matches, page) ||
        (shown != null && !shown.isActive);
    await navigator.maybePop();
    await WidgetsBinding.instance.endOfFrame;
    if (gone()) continue;
    final question = modals?.lastOn(navigator);
    if (question == null || question == modal) return LeaveOutcome.stayed;
    final answer = await question.popped;
    if (answer == null || answer == false) return LeaveOutcome.stayed;
    if (!await _goes(delegate, shown, gone)) return LeaveOutcome.slow;
    // Sliding out during a switch, a sheet would show the next account's
    // data.
    if (shown is TransitionRoute<Object?>) {
      await shown.completed.timeout(_leaveTimeout, onTimeout: () => null);
    }
  }
}

/// A page's pop reaches [delegate]'s listeners, a dialog's or sheet's its
/// `popped`.
Future<bool> _goes(
  GoRouterDelegate delegate,
  Route<Object?>? modal,
  bool Function() gone,
) async {
  if (gone()) return true;
  final went = Completer<bool>();
  void check() {
    if (!went.isCompleted && gone()) went.complete(true);
  }

  delegate.addListener(check);
  unawaited(modal?.popped.then((_) => check()));
  try {
    return await went.future.timeout(_leaveTimeout, onTimeout: () => false);
  } finally {
    delegate.removeListener(check);
  }
}

bool _holdsPage(List<RouteMatchBase> matches, ValueKey<String> page) =>
    matches.any(
      (match) =>
          match.pageKey == page ||
          (match is ShellRouteMatch && _holdsPage(match.matches, page)),
    );
