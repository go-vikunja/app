import 'package:flutter/foundation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/db/open_account_database.dart';
import 'package:vikunja_mobile/core/text/server_address_display.dart';
import 'package:vikunja_mobile/features/onboarding/application/guest_sign_in.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/failure_message.dart';
import 'package:vikunja_mobile/features/session/presentation/sign_in_failure_message.dart';

const _inviteInvalid = 2005;

/// Why a shared link or an invite could not be opened on [serverRoot]:
/// [error] is a `VikunjaFailure`, a [GuestLinkGone], a
/// [GuestServerUnsupported], a [SignOutStillFinishing] or anything
/// unexpected.
FailureMessage describeLinkFailure(
  AppLocalizations l10n,
  Object error, {
  required Uri serverRoot,
  required TargetPlatform platform,
}) => switch (error) {
  NotFound(code: _inviteInvalid) => FailureMessage(
    title: l10n.inviteInvalidTitle,
    explanation: l10n.inviteInvalidExplanation,
    suggestion: l10n.inviteInvalidSuggestion,
  ),
  GuestLinkGone(sharingOff: true) => FailureMessage(
    title: l10n.guestLinkGoneTitle,
    explanation: l10n.guestSharingOffExplanation(displayHost(serverRoot)),
    suggestion: l10n.guestSharingOffSuggestion,
  ),
  LinkShareGone() || GuestLinkGone() => FailureMessage(
    title: l10n.guestLinkGoneTitle,
    explanation: l10n.guestLinkGoneExplanation(displayHost(serverRoot)),
    suggestion: l10n.guestLinkGoneSuggestion,
  ),
  // Only the guest's own removal holds its link up.
  SignOutStillFinishing() => FailureMessage(
    title: l10n.guestRemoveStillFinishingTitle,
    explanation: l10n.guestRemoveStillFinishingExplanation,
    suggestion: l10n.signOutStillFinishingSuggestion,
  ),
  GuestServerUnsupported(:final version?) => FailureMessage(
    title: l10n.unsupportedTitle,
    explanation: l10n.unsupportedBody(
      ServerCapabilities.minimumSupportedVersion.display,
      version.display,
    ),
    suggestion: l10n.unsupportedSuggestion,
  ),
  GuestServerUnsupported() => FailureMessage(
    title: l10n.unsupportedUnknownVersionTitle,
    explanation: l10n.unsupportedUnknownVersionBody(
      ServerCapabilities.minimumSupportedVersion.display,
    ),
    suggestion: l10n.unsupportedUnknownVersionSuggestion,
  ),
  _ => describeSignInFailure(
    l10n,
    error,
    serverRoot: serverRoot,
    platform: platform,
  ),
};
