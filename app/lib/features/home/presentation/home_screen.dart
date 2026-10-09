import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/features/home/presentation/account_header.dart';
import 'package:vikunja_mobile/features/home/presentation/reauth_banner.dart';
import 'package:vikunja_mobile/features/home/presentation/sign_out_dialog.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connection_error_card.dart';
import 'package:vikunja_mobile/features/session/application/session_check.dart';
import 'package:vikunja_mobile/features/session/application/sign_in_controller.dart';
import 'package:vikunja_mobile/features/session/presentation/sign_in_failure_message.dart';

/// Placeholder for the signed-in app until the task screens exist.
class HomeScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _signingOut = false;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _checkSession);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSession());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _checkSession() {
    if (!mounted || _signingOut) return;
    if (ref.read(signInControllerProvider) is SignInInProgress) return;
    final entry = ref.read(accountsProvider).value?.activeAccount;
    if (entry == null) return;
    unawaited(ref.read(sessionCheckProvider).check(entry));
  }

  Future<void> _signOut(RegisteredAccount entry) async {
    final confirmed = await confirmSignOut(
      context,
      serverRoot: entry.connection.rootUri,
    );
    if (!confirmed || !mounted) return;
    setState(() => _signingOut = true);
    try {
      // Navigation away follows from the account registry.
      await ref.read(signOutProvider).call(entry.id);
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
    // Another account may have become active meanwhile.
    _checkSession();
  }

  void _onSignInChanged(SignInState? previous, SignInState next) {
    if (next is SignInFailed) unawaited(HapticFeedback.heavyImpact());
  }

  void _onActiveAccountChanged(String? previous, String? next) {
    // A failure card belongs to the account it happened for.
    ref.read(signInControllerProvider.notifier).reset();
    _checkSession();
  }

  @override
  Widget build(BuildContext context) {
    ref
      ..listen(signInControllerProvider, _onSignInChanged)
      ..listen<String?>(
        accountsProvider.select((accounts) => accounts.value?.activeAccountId),
        _onActiveAccountChanged,
      );
    final entry = ref.watch(accountsProvider).value?.activeAccount;
    // Briefly null while this route animates out after signing out.
    if (entry == null) return const Scaffold();

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final signIn = ref.watch(signInControllerProvider);
    final isSigningIn = signIn is SignInInProgress;

    // On Android before 12, back on the root route finishes the activity and
    // with it the isolate, which would cut off a token exchange or sign-out.
    return PopScope(
      canPop: !isSigningIn && !_signingOut,
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.homeTitle)),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              // During sign-out the logout's refresh can end the session,
              // which must not offer a sign-in racing the wipe.
              if (entry.account.needsReauth && !_signingOut) ...[
                ReauthBanner(
                  serverRoot: entry.connection.rootUri,
                  isSigningIn: isSigningIn,
                  onSignInAgain: () => unawaited(
                    ref
                        .read(signInControllerProvider.notifier)
                        .signInAgain(entry),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (signIn case SignInFailed(
                :final error,
                :final serverRoot,
              )) ...[
                ConnectionErrorCard(
                  message: describeSignInFailure(
                    l10n,
                    error,
                    serverRoot: serverRoot,
                    platform: theme.platform,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              AccountHeader(entry: entry),
              const SizedBox(height: 32),
              Text(
                l10n.homePlaceholder,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: _signingOut || isSigningIn
                    ? null
                    : () => unawaited(_signOut(entry)),
                icon: _signingOut
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator.adaptive(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.logout),
                label: Text(
                  _signingOut ? l10n.homeSigningOut : l10n.homeSignOut,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
