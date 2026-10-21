import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
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

/// Who is signed in with the way to the account's settings on the server,
/// a session that needs a new sign-in, the other accounts, the sync state
/// with the changes still waiting for the server, what is set on this
/// device only (notifications, colours), and sign-out.
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

  void _openSettings(BuildContext context) =>
      unawaited(GoRouter.of(context).push(AppRoutes.accountSettings));

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
    final busy = signingOut || isSigningIn;
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
            // The account being signed out must not be changed or read
            // again on the server.
            AccountHeader(
              entry: entry,
              onOpenSettings: busy ? null : () => _openSettings(context),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.manage_accounts_outlined),
              title: Text(l10n.accountSettingsEntry),
              subtitle: Text(l10n.accountSettingsEntrySubtitle),
              trailing: const Icon(Icons.chevron_right),
              enabled: !busy,
              onTap: () => _openSettings(context),
            ),
            const SizedBox(height: 24),
            AccountsSection(busy: busy),
            const SizedBox(height: 24),
            SyncStatusSection(entry: entry, signingOut: signingOut),
            PendingChangesLine(
              entry: entry,
              canSend: !signingOut && !entry.account.needsReauth,
            ),
            SyncProblemsSection(entry: entry),
            const SizedBox(height: 24),
            const _OnThisDeviceHeading(),
            const SizedBox(height: 16),
            NotificationsSection(entry: entry),
            const AppearanceSection(),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: busy
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

/// Above the sections that stay on this phone, apart from the account's
/// settings, which follow it to every device.
class _OnThisDeviceHeading extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.onThisDeviceHeading,
            style: theme.textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.onThisDeviceSubtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
