import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/accounts/presentation/account_actions.dart';
import 'package:vikunja_mobile/features/common/presentation/data_failure_card.dart';
import 'package:vikunja_mobile/features/connection/presentation/browser_leg_hint.dart';
import 'package:vikunja_mobile/features/connection/presentation/connection_settings_action.dart';
import 'package:vikunja_mobile/features/home/presentation/guest_reauth_banner.dart';
import 'package:vikunja_mobile/features/home/presentation/reauth_banner.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_header.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connection_error_card.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/server_address_display.dart';
import 'package:vikunja_mobile/features/session/application/sign_in_controller.dart';
import 'package:vikunja_mobile/features/session/application/sign_out_controller.dart';
import 'package:vikunja_mobile/features/session/presentation/sign_in_failure_message.dart';
import 'package:vikunja_mobile/features/sync/presentation/sync_phase_label.dart';

/// The full pull after sign-in. Routing keeps the shell away until the
/// account's engine reports a completed first sync.
class FirstSyncScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<FirstSyncScreen> createState() => _FirstSyncScreenState();
}

class _FirstSyncScreenState extends ConsumerState<FirstSyncScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  /// Also the retry: the engine resumes from its checkpoint. The status
  /// stream reports the outcome. A session that ended cannot sync; the
  /// banner asks for a new sign-in first.
  void _start() {
    if (!mounted) return;
    final entry = ref.read(accountsProvider).value?.activeAccount;
    if (entry == null || entry.account.needsReauth) return;
    unawaited(
      ref
          .read(syncEngineProvider(entry.id))
          .ensureInitialSync()
          .then<void>((_) {}, onError: (Object _) {}),
    );
  }

  void _onSignInChanged(SignInState? previous, SignInState next) {
    if (next is SignInSucceeded) _start();
  }

  /// Another account, if any, becomes active again and opens its shell.
  Future<void> _cancel(RegisteredAccount entry) =>
      removeAccount(context, ref, entry, pendingChanges: 0);

  @override
  Widget build(BuildContext context) {
    ref.listen(signInControllerProvider, _onSignInChanged);
    final entry = ref.watch(accountsProvider).value?.activeAccount;
    // Briefly null while this route animates out after signing out.
    if (entry == null) return const Scaffold();

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final status = ref.watch(syncStatusProvider).value;
    final signIn = ref.watch(signInControllerProvider);
    final signingOut = ref.watch(signOutControllerProvider);
    final sessionEnded =
        entry.account.needsReauth ||
        status is SyncFailed && _isSessionFailure(status.failure);

    // Like the shell: back must not end the isolate in the middle of a
    // sign-out.
    return PopScope(
      canPop: !signingOut,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      child: Text(
                        l10n.firstSyncTitle,
                        style: theme.textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.firstSyncBody(displayHost(entry.connection.rootUri)),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    // The Account tab's flow, because there is no Account
                    // tab before the first sync.
                    if (sessionEnded && entry.account.isLinkShare)
                      GuestReauthBanner(entry: entry)
                    else if (sessionEnded) ...[
                      ReauthBanner(
                        serverRoot: entry.connection.rootUri,
                        isSigningIn: signIn is SignInInProgress,
                        onSignInAgain: () => unawaited(
                          signInAgainAfterHint(context, ref, entry),
                        ),
                      ),
                      if (signIn case SignInFailed(
                        :final error,
                        :final serverRoot,
                      )) ...[
                        const SizedBox(height: 16),
                        ConnectionErrorCard(
                          message: describeSignInFailure(
                            l10n,
                            error,
                            serverRoot: serverRoot,
                            platform: theme.platform,
                          ),
                          action: ConnectionSettingsAction.appliesTo(error)
                              ? ConnectionSettingsAction(
                                  error: error,
                                  serverRoot: serverRoot,
                                  foreground:
                                      theme.colorScheme.onErrorContainer,
                                )
                              : null,
                        ),
                      ],
                    ] else
                      switch (status) {
                        SyncFailed(:final failure) => DataFailureCard(
                          error: failure,
                          stale: false,
                          onRetry: _start,
                        ),
                        SyncRunning(:final phase, :final done, :final total) =>
                          _Progress(
                            label: syncPhaseLabel(l10n, phase),
                            done: done,
                            total: total,
                          ),
                        _ => _Progress(label: l10n.firstSyncPreparing),
                      },
                    const SizedBox(height: 32),
                    TextButton(
                      onPressed: signingOut
                          ? null
                          : () => unawaited(_cancel(entry)),
                      child: Text(
                        signingOut ? l10n.homeSigningOut : l10n.firstSyncCancel,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

bool _isSessionFailure(VikunjaFailure failure) => switch (failure) {
  SessionEnded() || TokenRejected() || RefreshRaceLost() => true,
  _ => false,
};

class _Progress extends StatelessWidget {
  const new({required this.label, this.done = 0, this.total});

  final String label;
  final int done;
  final int? total;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final total = this.total;
    final counts = switch (total) {
      final total? => l10n.syncProgressOfTotal(done, total),
      null when done > 0 => l10n.syncProgressCount(done),
      null => null,
    };
    final fraction = total == null || total == 0
        ? null
        : (done / total).clamp(0.0, 1.0);
    // One node for screen readers: the phase, announced when it changes,
    // with the counts as its value, which changes with every page and is
    // only read on focus. The bar and the counts text would repeat them.
    return Column(
      children: [
        ExcludeSemantics(
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(height: 12),
        Semantics(
          container: true,
          liveRegion: true,
          value: counts,
          child: Text(
            label,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
        ),
        if (counts != null) ...[
          const SizedBox(height: 4),
          ExcludeSemantics(
            child: Text(
              counts,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ],
    );
  }
}
