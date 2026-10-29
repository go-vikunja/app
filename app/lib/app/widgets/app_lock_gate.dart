import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/theme/app_theme.dart';
import 'package:vikunja_mobile/app/theme/status_bar_style.dart';
import 'package:vikunja_mobile/core/platform/app_backgrounding.dart';
import 'package:vikunja_mobile/core/platform/system_back.dart';
import 'package:vikunja_mobile/core/security/app_lock_controller.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_header.dart';

/// The lock screen and the privacy cover over the app, which stays mounted
/// below (open sheets and unsaved edits survive) without pointers, focus,
/// semantics or tickers.
///
/// Back must not pop a route below the lock. A pop stops at this observer,
/// which moves the app to the background: it registers before the router's
/// back button dispatcher, which registers when the router below mounts.
/// From Android 14 on back can come as a predictive back gesture instead,
/// which each route's gesture detector would take and pop, so there the
/// gate reports to the platform while locked that the framework does not
/// handle back, and the activity's own back callback, switched on while
/// locked, moves the app to the back; without it Android would close the
/// activity whenever the task was not started from the launcher. Before 14
/// the framework keeps handling back while locked.
class AppLockGate extends ConsumerStatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  /// What the navigators below last reported, held back while locked.
  bool? _canHandlePop;
  late bool _locked;
  var _backArrivesAsPop = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locked = ref.read(appLockControllerProvider).locked;
    if (_locked) {
      _reportBack(canHandlePop: _backArrivesAsPop);
      _holdBackOnPlatform(locked: true);
    }
    unawaited(
      ref.read(systemBackArrivesAsPopProvider.future).then((asPop) {
        if (!mounted || asPop == _backArrivesAsPop) return;
        _backArrivesAsPop = asPop;
        if (_locked) _reportBack(canHandlePop: asPop);
      }),
    );
    ref
      ..listenManual(
        appLockControllerProvider.select((state) => state.locked),
        (_, locked) => _onLocked(locked),
      )
      ..listenManual(
        appLockControllerProvider.select((state) => state.notice),
        (_, notice) {
          if (notice != null) _showNotice(notice);
        },
      );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onLocked(bool locked) {
    if (locked == _locked) return;
    _locked = locked;
    _reportBack(
      canHandlePop: locked ? _backArrivesAsPop : (_canHandlePop ?? false),
    );
    _holdBackOnPlatform(locked: locked);
  }

  void _holdBackOnPlatform({required bool locked}) {
    unawaited(
      ref
          .read(appBackgroundingProvider)
          .setBackMovesToBack(enabled: locked)
          .catchError((Object _) {}),
    );
  }

  bool _onNavigation(NavigationNotification notification) {
    _canHandlePop = notification.canHandlePop;
    return _locked;
  }

  /// To `WidgetsApp`, which passes it on to the platform; like the
  /// navigator, never in the middle of a build.
  void _reportBack({required bool canHandlePop}) {
    void report() {
      if (!mounted) return;
      NavigationNotification(canHandlePop: canHandlePop).dispatch(context);
    }

    final scheduler = SchedulerBinding.instance;
    switch (scheduler.schedulerPhase) {
      case SchedulerPhase.idle || SchedulerPhase.postFrameCallbacks:
        report();
      case SchedulerPhase.transientCallbacks ||
          SchedulerPhase.midFrameMicrotasks ||
          SchedulerPhase.persistentCallbacks:
        scheduler.addPostFrameCallback((_) => report());
    }
  }

  @override
  Future<bool> didPopRoute() async {
    if (!_locked) return false;
    unawaited(ref.read(appBackgroundingProvider).moveToBack());
    return true;
  }

  void _showNotice(AppLockNotice notice) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final l10n = context.l10n;
      final text = switch (notice) {
        AppLockNotice.turnedOffWithoutScreenLock => l10n.appLockTurnedOff,
      };
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(text),
          persist: MediaQuery.accessibleNavigationOf(context),
        ),
      );
      ref.read(appLockControllerProvider.notifier).dismissNotice();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appLockControllerProvider);
    final locked = state.locked;
    final covered = !locked && state.covered;
    return NotificationListener<NavigationNotification>(
      onNotification: _onNavigation,
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            ignoring: locked || covered,
            child: ExcludeSemantics(
              excluding: locked || covered,
              child: ExcludeFocus(
                excluding: locked,
                child: TickerMode(enabled: !locked, child: widget.child),
              ),
            ),
          ),
          if (locked)
            _LockScreen(state: state)
          else if (covered)
            const _PrivacyCover(),
        ],
      ),
    );
  }
}

class _LockScreen extends ConsumerWidget {
  const new({required this.state});

  final AppLockState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final error = switch (state.error) {
      AppLockError.lockedOut => l10n.appLockLockedOut,
      AppLockError.promptStuck => l10n.appLockPromptStuck,
      AppLockError.unavailable => l10n.appLockUnavailable,
      null => null,
    };
    return _StatusBarFor(
      background: colors.surface,
      child: Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        child: Material(
          color: colors.surface,
          child: SafeArea(
            // The button stays in view at any text size; the texts scroll.
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: math.max(0, constraints.maxHeight - 48),
                        ),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  ConnectHeader.logoAsset,
                                  width: 72,
                                  height: 72,
                                  excludeFromSemantics: true,
                                ),
                                const SizedBox(height: 20),
                                Semantics(
                                  header: true,
                                  headingLevel: 1,
                                  namesRoute: true,
                                  child: Text(
                                    l10n.appLockTitle,
                                    style: theme.textTheme.headlineSmall,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  l10n.appLockBody,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                if (error != null) ...[
                                  const SizedBox(height: 16),
                                  Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      error,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(color: colors.error),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        autofocus: true,
                        onPressed: state.authenticating
                            ? null
                            : () => unawaited(
                                ref
                                    .read(appLockControllerProvider.notifier)
                                    .unlock(),
                              ),
                        icon: const Icon(Icons.lock_open),
                        label: Text(l10n.appLockUnlock),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// What the app switcher shows: the logo on the window background the
/// system itself draws for the app (`launch_background`).
class _PrivacyCover extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final background = AppTheme.brandScheme(Theme.of(context).brightness)
        .surface;
    return _StatusBarFor(
      background: background,
      child: ColoredBox(
        color: background,
        child: Center(
          child: Image.asset(
            ConnectHeader.logoAsset,
            width: 72,
            height: 72,
            excludeFromSemantics: true,
          ),
        ),
      ),
    );
  }
}

/// Status bar icons that read on [background]; without them the icons
/// follow the page below, whose app bar may be dark on a light lock screen.
class _StatusBarFor extends StatelessWidget {
  const new({required this.background, required this.child});

  final Color background;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: statusBarStyleOn(background),
    child: child,
  );
}
