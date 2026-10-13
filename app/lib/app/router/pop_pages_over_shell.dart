import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';

/// Pops the pages that cover the shell, one by one through their
/// `PopScope`, so the edit page asks before its unsaved changes go; `go`
/// would drop them without asking. True once a tab is on top, false when a
/// page stays: its dialog decides, and the caller navigates nowhere.
Future<bool> popPagesOverShell(GoRouter router) async {
  final delegate = router.routerDelegate;
  while (true) {
    final location = delegate.state.matchedLocation;
    if (AppRoutes.isTab(location)) return true;
    final navigator = delegate.navigatorKey.currentState;
    if (navigator == null || !navigator.canPop()) return true;
    await navigator.maybePop();
    await WidgetsBinding.instance.endOfFrame;
    if (delegate.state.matchedLocation == location) return false;
  }
}
