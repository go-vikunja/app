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
import 'package:vikunja_mobile/features/sync/application/startup_sync.dart';

/// The signed-in app: the tab bar around the Overview, Upcoming, Projects
/// and Account branches, the session check when the app opens or resumes,
/// the quiet sync when it opens, the scheduler that keeps syncing while it
/// is in front, the other accounts' outboxes, the notification schedulers
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
      ..listen(signOutControllerProvider, _onSignOutChanged)
      // A provider nobody listens to is paused; these run while the shell
      // is up.
      ..listen(foregroundSyncSchedulerProvider, (_, _) {})
      ..listen(inactiveOutboxesProvider, (_, _) {})
      ..listen(accountNotificationSchedulersProvider, (_, _) {});
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
      child: Scaffold(
        body: _resettingTabs ? const SizedBox.expand() : widget.navigationShell,
        bottomNavigationBar: AdaptiveNavigationBar(
          selectedIndex: widget.navigationShell.currentIndex,
          onDestinationSelected: _selectTab,
          destinations: [
            AdaptiveDestination(
              icon: Icons.task_alt_outlined,
              selectedIcon: Icons.task_alt,
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
          ],
        ),
      ),
    );
  }
}
