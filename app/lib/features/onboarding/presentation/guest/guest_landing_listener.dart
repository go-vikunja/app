import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/onboarding/application/guest_landing.dart';

final _log = Logger('GuestLanding');

/// Shows the shared project of a link the guest entry just opened, in the
/// view the link named, once the router has reached the shell for that
/// guest: after its first sync and the notification setup. A link opened
/// again from the reauth banner remembers no landing (`GuestSignIn.reopen`).
class GuestLandingListener extends ConsumerStatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<GuestLandingListener> createState() =>
      _GuestLandingListenerState();
}

class _GuestLandingListenerState extends ConsumerState<GuestLandingListener> {
  late final GoRouter _router;
  var _landing = false;

  @override
  void initState() {
    super.initState();
    _router = ref.read(appRouterProvider)
      ..routerDelegate.addListener(_landWhenReady);
  }

  @override
  void dispose() {
    _router.routerDelegate.removeListener(_landWhenReady);
    super.dispose();
  }

  void _landWhenReady() {
    if (_landing || !mounted) return;
    final delegate = _router.routerDelegate;
    if (delegate.currentConfiguration.isEmpty) return;
    if (!AppRoutes.isTab(delegate.state.matchedLocation)) return;
    final accountId = ref.read(activeAccountIdProvider);
    if (accountId == null) return;
    final landing = ref.read(guestLandingsProvider).take(accountId);
    if (landing == null) return;
    _landing = true;
    unawaited(_land(accountId, landing).whenComplete(() => _landing = false));
  }

  Future<void> _land(String accountId, GuestLanding landing) async {
    // The project screen opens the view it showed last, when it still has
    // it.
    if (landing.viewId case final viewId?) {
      try {
        await ref
            .read(listPreferencesProvider)
            ?.rememberView(landing.projectId, viewId);
      } on Object catch (error) {
        _log.info("Could not keep the link's view: ${error.runtimeType}");
      }
    }
    // A guest added beside another account is a switch, whose reset of the
    // tabs leaves them out for one frame and puts them back in the next;
    // the project goes on top of that.
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || ref.read(activeAccountIdProvider) != accountId) return;
    _router.go(AppRoutes.project(landing.projectId));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
