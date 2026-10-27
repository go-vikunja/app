import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/features/connection/presentation/connection_settings_action.dart';
import 'package:vikunja_mobile/features/home/presentation/reauth_banner.dart';
import 'package:vikunja_mobile/features/onboarding/application/connect_server_state.dart';
import 'package:vikunja_mobile/features/onboarding/application/guest_sign_in.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connection_error_card.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/link_failure_message.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/guest/share_password_sheet.dart';

/// [ReauthBanner] for a link-share guest the server no longer accepts: its
/// action opens the stored link again, asks for the share's password when
/// it has one, and says below why that failed. Success replaces the guest's
/// entry, which ends the banner.
class GuestReauthBanner extends ConsumerStatefulWidget {
  const new({required this.entry, super.key});

  final RegisteredAccount entry;

  @override
  ConsumerState<GuestReauthBanner> createState() => _GuestReauthBannerState();
}

class _GuestReauthBannerState extends ConsumerState<GuestReauthBanner> {
  var _opening = false;
  Object? _failure;

  Future<void> _openAgain() async {
    setState(() {
      _opening = true;
      _failure = null;
    });
    final signIn = ref.read(guestSignInProvider);
    final accountId = widget.entry.id;
    Object? error;
    Future<GuestSignInResult?> attempt({String? password}) async {
      error = null;
      try {
        return await signIn.reopen(accountId, password: password);
      } on Object catch (failure) {
        error = failure;
        return null;
      }
    }

    var result = await attempt();
    if (result is GuestPasswordRequired && mounted) {
      final outcome = await askForSharePassword(
        context,
        submit: (password) async {
          result = await attempt(password: password);
          return switch (result) {
            GuestSignedIn() => SharePasswordOutcome.accepted,
            GuestPasswordRequired() => SharePasswordOutcome.wrong,
            _ => SharePasswordOutcome.failed,
          };
        },
      );
      // Closed by the user, which needs no explanation.
      if (outcome == null) {
        error = null;
        result = null;
      }
    }
    if (!mounted) return;
    setState(() {
      _opening = false;
      _failure = switch (result) {
        final GuestLinkGone gone => gone,
        GuestSignInFailed(:final failure) => failure,
        _ => error,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final failure = _failure;
    final serverRoot = widget.entry.connection.rootUri;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 16,
      children: [
        ReauthBanner(
          serverRoot: serverRoot,
          isSigningIn: _opening,
          guest: true,
          onSignInAgain: () => unawaited(_openAgain()),
        ),
        if (failure != null)
          ConnectionErrorCard(
            message: describeLinkFailure(
              context.l10n,
              failure,
              serverRoot: serverRoot,
              platform: Theme.of(context).platform,
            ),
            action: ConnectionSettingsAction.appliesTo(failure)
                ? ConnectionSettingsAction(
                    error: failure,
                    serverRoot: serverRoot,
                    foreground: Theme.of(context).colorScheme.onErrorContainer,
                  )
                : null,
          ),
      ],
    );
  }
}
