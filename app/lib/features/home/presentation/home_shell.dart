import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/widgets/adaptive_navigation_bar.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/notifications/notification_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/session/application/session_check.dart';
import 'package:vikunja_mobile/features/session/application/sign_in_controller.dart';
import 'package:vikunja_mobile/features/session/application/sign_out_controller.dart';
import 'package:vikunja_mobile/features/sync/application/foreground_sync_scheduler_providers.dart';
import 'package:vikunja_mobile/features/sync/application/inactive_outboxes.dart';
import 'package:vikunja_mobile/features/sync/application/offline_state.dart';
import 'package:vikunja_mobile/features/sync/application/realtime_connection_providers.dart';
import 'package:vikunja_mobile/features/sync/application/startup_sync.dart';
import 'package:vikunja_mobile/features/sync/presentation/offline_banner.dart';

/// The signed-in app: the tab bar (or, in a wide window, the rail) around
/// the Overview, Upcoming, Projects and Account branches, the offline
/// banner, the session check when the app opens or resumes,
/// the quiet sync when it opens, the scheduler that keeps syncing while it
/// is in front, the socket that brings the server's notifications at once,
/// the other accounts' outboxes, the notification schedulers
/// of every signed-in account, and the switch from one account to another.
class HomeShell extends ConsumerStatefulWidget {
  const new({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  late final AppLifecycleListener _lifecycle;

  /// For the one frame after an account switch in which the tabs are left
  /// out.
  var _resettingTabs = false;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _checkSession);
    // A provider nobody listens to is paused; these run while the shell is
    // up. Not in build: every rebuild, a tab switch among them, closes the
    // last build's listeners before it adds its own, which would pause and
    // restart each of them (a new socket, a reset sync timer).
    ref
      ..listenManual(foregroundSyncSchedulerProvider, (_, _) {})
      ..listenManual(realtimeConnectionProvider, (_, _) {})
      ..listenManual(inactiveOutboxesProvider, (_, _) {})
      ..listenManual(accountNotificationSchedulersProvider, (_, _) {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSession();
      _syncQuietly();
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _checkSession() {
    if (!mounted || ref.read(signOutControllerProvider)) return;
    if (ref.read(signInControllerProvider) is SignInInProgress) return;
    final entry = ref.read(accountsProvider).value?.activeAccount;
    if (entry == null) return;
    unawaited(ref.read(sessionCheckProvider).check(entry));
  }

  void _syncQuietly() {
    if (!mounted || ref.read(signOutControllerProvider)) return;
    final entry = ref.read(accountsProvider).value?.activeAccount;
    // A session that ended cannot sync; the Account tab asks to sign in.
    if (entry == null || entry.account.needsReauth) return;
    unawaited(
      ref.read(startupSyncProvider).run(ref.read(syncEngineProvider(entry.id))),
    );
  }

  void _onSignInChanged(SignInState? previous, SignInState next) {
    if (next is SignInFailed) unawaited(HapticFeedback.heavyImpact());
  }

  void _onActiveAccountChanged(String? previous, String? next) {
    // A failure card belongs to the account it happened for.
    ref.read(signInControllerProvider.notifier).reset();
    if (previous != null && next != null) _closePreviousAccount();
    _checkSession();
    _syncQuietly();
  }

  /// Runs before the next frame, so no screen of the previous account is
  /// built with the new account's data: dialogs and sheets close without
  /// an exit animation, pages over the shell go (blank while they animate
  /// out), and every tab starts at its root. A tab's navigator keeps its
  /// stack and the shell each tab's last location; leaving them out of
  /// one frame disposes both.
  void _closePreviousAccount() {
    ref.read(rootModalRoutesProvider).closeAll();
    GoRouter.of(context).go(AppRoutes.overview);
    setState(() => _resettingTabs = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _resettingTabs = false);
    });
  }

  void _onSignOutChanged(bool? previous, bool next) {
    // Another account may have become active meanwhile.
    if (previous == true && !next) {
      _checkSession();
      _syncQuietly();
    }
  }

  void _selectTab(int index) => widget.navigationShell.goBranch(
    index,
    // Re-selecting the current tab returns to its first screen.
    initialLocation: index == widget.navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context) {
    ref
      ..listen(signInControllerProvider, _onSignInChanged)
      ..listen<String?>(
        accountsProvider.select((accounts) => accounts.value?.activeAccountId),
        _onActiveAccountChanged,
      )
      ..listen(signOutControllerProvider, _onSignOutChanged);
    final signedIn = ref.watch(
      accountsProvider.select(
        (accounts) => accounts.value?.activeAccount != null,
      ),
    );
    // Briefly false while this route animates out after signing out.
    if (!signedIn) return const Scaffold();

    final l10n = context.l10n;
    final signingOut = ref.watch(signOutControllerProvider);
    final signingIn = ref.watch(signInControllerProvider) is SignInInProgress;
    final onFirstTab = widget.navigationShell.currentIndex == 0;

    final destinations = [
      AdaptiveDestination(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        label: l10n.tabOverview,
      ),
      AdaptiveDestination(
        icon: Icons.event_outlined,
        selectedIcon: Icons.event,
        label: l10n.tabUpcoming,
      ),
      AdaptiveDestination(
        icon: Icons.folder_outlined,
        selectedIcon: Icons.folder,
        label: l10n.tabProjects,
      ),
      AdaptiveDestination(
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        label: l10n.tabAccount,
      ),
    ];
    final rail = usesNavigationRail(context);
    final offline = ref.watch(offlineProvider.select((state) => state != null));
    final content = Builder(
      // Below the scaffold, whose bar takes the bottom inset.
      builder: (context) {
        // The rail takes the inset on its side, the banner the one below.
        final ltr = Directionality.of(context) == TextDirection.ltr;
        final padding = MediaQuery.of(context)
            .removePadding(removeLeft: rail && ltr, removeRight: rail && !ltr);
        return Column(
          children: [
            Expanded(
              child: MediaQuery(
                data: padding.removePadding(removeBottom: offline),
                child: OfflineBannerArea(
                  child: _resettingTabs
                      ? const SizedBox.expand()
                      : widget.navigationShell,
                ),
              ),
            ),
            MediaQuery(data: padding, child: const OfflineBanner()),
          ],
        );
      },
    );

    // On Android before 12, back on the root route finishes the activity and
    // with it the isolate, which would cut off a token exchange or sign-out.
    // Back on another tab's root returns to the first tab instead, as Android
    // expects; a tab's own stack is popped before a pop reaches the shell.
    return PopScope(
      canPop: !signingIn && !signingOut && onFirstTab,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !signingIn && !signingOut && !onFirstTab) {
          widget.navigationShell.goBranch(0);
        }
      },
      // The same structure with the rail as with the bar, so a rotation
      // keeps the content, the banner among it, which screen readers would
      // otherwise announce again. The rail is outside the scaffold, whose
      // snackbars then stay beside it rather than across it.
      child: Row(
        children: [
          if (rail)
            AdaptiveNavigationRail(
              selectedIndex: widget.navigationShell.currentIndex,
              onDestinationSelected: _selectTab,
              destinations: destinations,
            ),
          Expanded(
            child: Scaffold(
              body: content,
              bottomNavigationBar: rail
                  ? null
                  : AdaptiveNavigationBar(
                      selectedIndex: widget.navigationShell.currentIndex,
                      onDestinationSelected: _selectTab,
                      destinations: destinations,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
