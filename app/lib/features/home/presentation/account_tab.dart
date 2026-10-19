import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/features/accounts/presentation/account_actions.dart';
import 'package:vikunja_mobile/features/accounts/presentation/accounts_section.dart';
import 'package:vikunja_mobile/features/home/presentation/account_header.dart';
import 'package:vikunja_mobile/features/home/presentation/appearance_section.dart';
import 'package:vikunja_mobile/features/home/presentation/pending_changes_line.dart';
import 'package:vikunja_mobile/features/home/presentation/reauth_banner.dart';
import 'package:vikunja_mobile/features/home/presentation/sync_problems_section.dart';
import 'package:vikunja_mobile/features/home/presentation/sync_status_section.dart';
import 'package:vikunja_mobile/features/notifications/presentation/notifications_section.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connection_error_card.dart';
import 'package:vikunja_mobile/features/session/application/sign_in_controller.dart';
import 'package:vikunja_mobile/features/session/application/sign_out_controller.dart';
import 'package:vikunja_mobile/features/session/presentation/sign_in_failure_message.dart';
import 'package:vikunja_mobile/features/sync/application/outbox_providers.dart';
import 'package:vikunja_mobile/features/sync/presentation/sync_progress_bar.dart';

/// Who is signed in, a session that needs a new sign-in, the other
/// accounts, the sync state, the notifications, the colours, the changes
/// still waiting for the server, and sign-out.
class AccountTab extends ConsumerWidget {
  const new({super.key});

  Future<void> _signOut(
    BuildContext context,
    WidgetRef ref,
    RegisteredAccount entry,
  ) => removeAccount(
    context,
    ref,
    entry,
    pendingChanges:
        ref.read(pendingChangesProvider).unwrapPrevious().value ?? 0,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider).value;
    final entry = accounts?.activeAccount;
    // Briefly null while the shell animates out after signing out.
    if (accounts == null || entry == null) return const Scaffold();

    final l10n = context.l10n;
    final theme = Theme.of(context);
    final signIn = ref.watch(signInControllerProvider);
    final isSigningIn = signIn is SignInInProgress;
    final signingOut = ref.watch(signOutControllerProvider);
    final signOutLabel = switch ((signingOut, accounts.accounts.length > 1)) {
      (true, _) => l10n.homeSigningOut,
      (false, true) => l10n.homeSignOutOfThisAccount,
      (false, false) => l10n.homeSignOut,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabAccount),
        bottom: const SyncProgressBar(),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // During sign-out the logout's refresh can end the session,
            // which must not offer a sign-in racing the wipe.
            if (entry.account.needsReauth && !signingOut) ...[
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
            if (signIn case SignInFailed(:final error, :final serverRoot)) ...[
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
            const SizedBox(height: 24),
            AccountsSection(busy: signingOut || isSigningIn),
            const SizedBox(height: 24),
            SyncStatusSection(entry: entry, signingOut: signingOut),
            const SizedBox(height: 24),
            NotificationsSection(entry: entry),
            const AppearanceSection(),
            PendingChangesLine(
              entry: entry,
              canSend: !signingOut && !entry.account.needsReauth,
            ),
            SyncProblemsSection(entry: entry),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: signingOut || isSigningIn
                  ? null
                  : () => unawaited(_signOut(context, ref, entry)),
              icon: signingOut
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    )
                  : const Icon(Icons.logout),
              label: Text(signOutLabel),
            ),
          ],
        ),
      ),
    );
  }
}
