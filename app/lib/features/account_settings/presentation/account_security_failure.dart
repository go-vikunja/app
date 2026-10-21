import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';

/// Why ending a session, or creating or deleting a token, failed.
String accountSecurityFailureText(AppLocalizations l10n, Object error) =>
    switch (error) {
      // The server may have done it before the answer was lost.
      NetworkFailure(problem: NetworkProblem.timeout) =>
        l10n.accountSecurityUnconfirmed,
      NetworkFailure() => l10n.accountSecurityNeedsConnection,
      SessionEnded() ||
      TokenRejected() ||
      RefreshRaceLost() => l10n.accountSecuritySignInAgain,
      NotFound(routeAbsent: true) => l10n.accountSecurityNotOffered,
      RateLimited() => l10n.accountSecurityRateLimited,
      VikunjaFailure(:final message) when message.trim().isNotEmpty =>
        l10n.accountSecurityRefused(message.trim()),
      _ => l10n.accountSecurityFailed,
    };
