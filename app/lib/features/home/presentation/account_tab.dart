import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/repositories/account_settings_repository_providers.dart';
import 'package:vikunja_mobile/features/account_settings/application/web_settings_pages.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_deletion.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/web_settings_page_opener.dart';
import 'package:vikunja_mobile/features/accounts/presentation/account_actions.dart';
import 'package:vikunja_mobile/features/accounts/presentation/accounts_section.dart';
import 'package:vikunja_mobile/features/common/presentation/settings_section.dart';
import 'package:vikunja_mobile/features/home/application/app_version.dart';
import 'package:vikunja_mobile/features/home/presentation/account_header.dart';
import 'package:vikunja_mobile/features/home/presentation/appearance_section.dart';
import 'package:vikunja_mobile/features/home/presentation/guest_note.dart';
import 'package:vikunja_mobile/features/home/presentation/guest_reauth_banner.dart';
import 'package:vikunja_mobile/features/home/presentation/organise_section.dart';
import 'package:vikunja_mobile/features/home/presentation/pending_changes_line.dart';
import 'package:vikunja_mobile/features/home/presentation/reauth_banner.dart';
import 'package:vikunja_mobile/features/home/presentation/server_notices.dart';
import 'package:vikunja_mobile/features/home/presentation/sync_problems_section.dart';
import 'package:vikunja_mobile/features/home/presentation/sync_status_section.dart';
import 'package:vikunja_mobile/features/notifications/presentation/notifications_section.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connection_error_card.dart';
import 'package:vikunja_mobile/features/privacy/presentation/privacy_section.dart';
import 'package:vikunja_mobile/features/session/application/sign_in_controller.dart';
import 'package:vikunja_mobile/features/session/application/sign_out_controller.dart';
import 'package:vikunja_mobile/features/session/presentation/sign_in_failure_message.dart';
import 'package:vikunja_mobile/features/sync/application/outbox_providers.dart';
import 'package:vikunja_mobile/features/sync/presentation/sync_progress_bar.dart';
import 'package:vikunja_mobile/features/widgets/presentation/widgets_section.dart';

/// Who is signed in with the way to the account's settings on the server,
/// a session that needs a new sign-in, the account's labels and teams, the
/// other accounts, the server with the sync state and the changes still
/// waiting for it, what is set on this device only (the home-screen
/// widgets, notifications, privacy, colours), sign-out and the app's
/// version. A link-share guest gets a note on what it may do instead of
/// the settings and the labels and teams.
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
    final guest = entry.account.isLinkShare;
    // A guest has no profile on the server, so nothing to delete either.
    final deletionScheduledAt = guest
        ? null
        : ref.watch(
            accountSettingsProvider.select(
              (state) => state.value?.profile?.deletionScheduledAt,
            ),
          );
    final connection = entry.connection;
    final serverVersion =
        connection.info.version?.display ?? connection.info.rawVersion;
    final signOutLabel = switch ((signingOut, accounts.accounts.length > 1)) {
      (true, _) => l10n.homeSigningOut,
      _ when guest => l10n.guestRemove,
      (false, true) => l10n.homeSignOutOfThisAccount,
      (false, false) => l10n.homeSignOut,
    };
    const bannerPadding = EdgeInsets.fromLTRB(16, 8, 16, 8);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabAccount),
        bottom: const SyncProgressBar(),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            // During sign-out the logout's refresh can end the session,
            // which must not offer a sign-in racing the wipe.
            if (entry.account.needsReauth && !signingOut)
              Padding(
                padding: bannerPadding,
                child: guest
                    ? GuestReauthBanner(entry: entry)
                    : ReauthBanner(
                        serverRoot: connection.rootUri,
                        isSigningIn: isSigningIn,
                        onSignInAgain: () => unawaited(
                          ref
                              .read(signInControllerProvider.notifier)
                              .signInAgain(entry),
                        ),
                      ),
              ),
            if (signIn case SignInFailed(:final error, :final serverRoot))
              Padding(
                padding: bannerPadding,
                child: ConnectionErrorCard(
                  message: describeSignInFailure(
                    l10n,
                    error,
                    serverRoot: serverRoot,
                    platform: theme.platform,
                  ),
                ),
              ),
            // The account being signed out must not be changed or read
            // again on the server.
            AccountHeader(
              entry: entry,
              onOpenSettings: busy || guest
                  ? null
                  : () => _openSettings(context),
            ),
            if (entry.account.projectId case final projectId? when guest)
              GuestNote(projectId: projectId),
            if (deletionScheduledAt != null)
              DeletionScheduledNote(
                scheduledAt: deletionScheduledAt,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                // Cancelling needs the password, so the web's page does it
                // (D14).
                onCancel: () => unawaited(
                  openWebSettingsPage(
                    context,
                    ref,
                    entry,
                    WebSettingsPage.deletion,
                  ),
                ),
              ),
            if (!guest)
              ListTile(
                leading: const Icon(Icons.manage_accounts_outlined),
                title: Text(l10n.accountSettingsEntry),
                subtitle: Text(l10n.accountSettingsEntrySubtitle),
                trailing: const Icon(Icons.chevron_right),
                enabled: !busy,
                onTap: () => _openSettings(context),
              ),
            const SizedBox(height: 8),
            if (!guest) OrganiseSection(busy: busy),
            AccountsSection(busy: busy),
            SettingsSection(
              title: l10n.accountServerHeading,
              children: [
                if (serverVersion.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.dns_outlined),
                    title: Text(l10n.overviewVikunjaVersion(serverVersion)),
                  ),
                ServerNotices(info: connection.info),
                SyncStatusSection(entry: entry, signingOut: signingOut),
                PendingChangesLine(
                  entry: entry,
                  canSend: !signingOut && !entry.account.needsReauth,
                ),
                SyncProblemsSection(entry: entry),
              ],
            ),
            const WidgetsSection(),
            NotificationsSection(entry: entry),
            const PrivacySection(),
            const AppearanceSection(),
            const SizedBox(height: 16),
            Center(
              child: OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => unawaited(_signOut(context, ref, entry)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
                icon: signingOut
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator.adaptive(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.logout),
                label: Text(signOutLabel),
              ),
            ),
            const _AppVersionLine(),
          ],
        ),
      ),
    );
  }
}

class _AppVersionLine extends ConsumerWidget {
  const new();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final (:version, :build) = ref.watch(appVersionProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Text(
        build.isEmpty
            ? l10n.accountAppVersionWithoutBuild(version)
            : l10n.accountAppVersion(version, build),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
