import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/session_diagnostics.dart';
import 'package:vikunja_mobile/core/time/clock_tick_provider.dart';
import 'package:vikunja_mobile/features/home/application/background_sync_status.dart';
import 'package:vikunja_mobile/features/home/presentation/session_end_text.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/server_address_display.dart';
import 'package:vikunja_mobile/features/session/presentation/sign_in_button.dart';
import 'package:vikunja_mobile/features/tasks/presentation/relative_time.dart';

/// [ReauthBanner] for a user's account, telling when and why its session
/// ended from the record of that end, when the app noted one (D59).
class AccountReauthBanner extends ConsumerWidget {
  const new({
    required this.entry,
    required this.isSigningIn,
    required this.onSignInAgain,
    super.key,
  });

  final RegisteredAccount entry;
  final bool isSigningIn;
  final VoidCallback onSignInAgain;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = watchOpenSessionEnd(ref, entry);
    if (open == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final ended = open.end;
    final now = ref.watch(clockTickProvider);
    return ReauthBanner(
      serverRoot: entry.connection.rootUri,
      isSigningIn: isSigningIn,
      endedOnDevice: ended != null && ended.cause.onDevice,
      reason: ended == null
          ? null
          : [
              if (isJustNow(ended.at, now: now))
                l10n.reauthEndedJustNow
              else
                l10n.reauthEndedAt(
                  formatRelativeTime(l10n, ended.at, now: now),
                ),
              describeSessionEndCause(l10n, ended, now: now),
            ].join(' '),
      onSignInAgain: onSignInAgain,
    );
  }
}

/// The account's end a reauth banner tells of, from the record read once
/// the account was marked; null until then, so that the banner's live
/// region is built with its final words and announced once (D59). A read
/// that failed tells of no end, which words it as the server's, and so
/// does a banner for a failed sync whose mark has not arrived. A resolved
/// record belongs to an earlier end.
({SessionEndDiagnosis? end})? watchOpenSessionEnd(
  WidgetRef ref,
  RegisteredAccount entry,
) {
  if (!entry.account.needsReauth) return (end: null);
  final read = ref.watch(markedSessionEndProvider(entry.id));
  if (read.value case (needsReauth: true, :final end)) {
    return (end: end != null && end.resolution == null ? end : null);
  }
  return read.hasError ? (end: null) : null;
}

/// The session ended, on the server or [endedOnDevice]: sign in again, or
/// for a link-share [guest] open the shared link again.
class ReauthBanner extends StatelessWidget {
  const new({
    required this.serverRoot,
    required this.isSigningIn,
    required this.onSignInAgain,
    this.guest = false,
    this.endedOnDevice = false,
    this.reason,
    super.key,
  });

  final Uri serverRoot;
  final bool isSigningIn;
  final VoidCallback onSignInAgain;
  final bool guest;

  /// This device's storage ended the session, not the server (D59).
  final bool endedOnDevice;

  /// When and why the session ended, when the app noted it (D59).
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final foreground = colors.onTertiaryContainer;
    final host = displayHost(serverRoot);
    return Card.filled(
      color: colors.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              container: true,
              liveRegion: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    guest ? Icons.link_off : Icons.lock_clock_outlined,
                    color: foreground,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          switch ((guest, endedOnDevice)) {
                            (true, true) => l10n.guestReauthTitleOnDevice,
                            (true, false) => l10n.guestReauthTitle,
                            (false, true) => l10n.reauthTitleOnDevice,
                            (false, false) => l10n.reauthTitle,
                          },
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: foreground,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          switch ((guest, endedOnDevice)) {
                            (true, true) => l10n.guestReauthBodyOnDevice(host),
                            (true, false) => l10n.guestReauthBody(host),
                            (false, true) => l10n.reauthBodyOnDevice(host),
                            (false, false) => l10n.reauthBody(host),
                          },
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: foreground,
                          ),
                        ),
                        if (reason case final reason?) ...[
                          const SizedBox(height: 4),
                          // A node of its own, out of the live region's
                          // label: its times tick every minute, and every
                          // change of that label is announced again.
                          Semantics(
                            container: true,
                            child: Text(
                              reason,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: foreground,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SignInButton(
              label: guest ? l10n.guestOpenLinkAgain : l10n.reauthAction,
              isSigningIn: isSigningIn,
              onPressed: onSignInAgain,
            ),
          ],
        ),
      ),
    );
  }
}
