import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/router/root_modal_routes.dart';

/// How long a page or sheet may take to go once its question was answered
/// by leaving it: Save writes first, online for a project, label or team.
const _leaveTimeout = Duration(seconds: 30);

/// How [popPagesOverShell] and [popPagesOutsideHome] ended.
enum LeaveOutcome {
  /// What was to go went: for [popPagesOverShell] a tab is on top, with no
  /// dialog or sheet over it, for [popPagesOutsideHome] a route under
  /// `/home`.
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
/// the page or sheet to go. A dialog or sheet that would not ask closes
/// without an exit animation, as an account switch closes them.
Future<LeaveOutcome> popPagesOverShell(GoRouter router) => _popPages(
  router,
  done: (location, modal) => modal == null && AppRoutes.isTab(location),
);

/// Like [popPagesOverShell], but only the pages outside `/home` that cover
/// the shell, such as About and Connection, with the dialogs and sheets
/// over them; the pages, dialogs and sheets under `/home` stay. A
/// Connection editor stays too, with what is over it: it would drop typed
/// values without asking.
Future<LeaveOutcome> popPagesOutsideHome(GoRouter router) => _popPages(
  router,
  done: (location, _) => location.startsWith(AppRoutes.home),
  stays: (top) => AppRoutes.connectionEditorIn(top.uri) != null,
);

Future<LeaveOutcome> _popPages(
  GoRouter router, {
  required bool Function(String location, Route<Object?>? modal) done,
  bool Function(GoRouterState top)? stays,
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
    if (stays?.call(top) ?? false) return LeaveOutcome.stayed;
    // A page pushed from a sheet covers it and goes first.
    final shown = modal != null && modal.isCurrent ? modal : null;
    if (shown != null && shown.popDisposition != RoutePopDisposition.doNotPop) {
      navigator.removeRoute(shown);
      continue;
    }
    final pages = delegate.currentConfiguration;
    // By the route, not the location: two pages may share one.
    bool gone() =>
        !identical(delegate.currentConfiguration, pages) ||
        (shown != null && !shown.isActive);
    await navigator.maybePop();
    await WidgetsBinding.instance.endOfFrame;
    if (gone()) continue;
    final question = modals?.lastOn(navigator);
    if (question == null || question == modal) return LeaveOutcome.stayed;
    final answer = await question.popped;
    if (answer == null || answer == false) return LeaveOutcome.stayed;
    if (!await _goes(delegate, shown, gone)) return LeaveOutcome.slow;
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
