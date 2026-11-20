import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/auth/session_manager.dart';
import 'package:vikunja_mobile/core/auth/token_store.dart';

/// Our own text for failures any action can meet, whose server detail is
/// English or empty; null for the rest, which each action words itself.
String? actionFailureText(AppLocalizations l10n, Object error) =>
    switch (error) {
      // A subtype of SessionEnded, so it must come first.
      LinkShareGone() => l10n.actionFailureGuestAccessEnded,
      SessionEnded() ||
      TokenRejected() ||
      RefreshRaceLost() => l10n.actionFailureSessionEnded,
      RateLimited() => l10n.actionFailureRateLimited,
      ServerFailure() => l10n.actionFailureServerError,
      _ => null,
    };

/// Our text for a request that got no token and so was never sent (D59):
/// no connection was missing, and the server changed nothing. Null for any
/// other failure. An action words it before its own network failures.
String? notSentFailureText(AppLocalizations l10n, Object? error) =>
    switch (error) {
      NetworkFailure(cause: SecureStorageUnreadable()) =>
        '${l10n.actionFailureSignInUnreadable} '
            '${l10n.failureSignInUnreadableSuggestion}',
      NetworkFailure(cause: RefreshDeferred()) =>
        '${l10n.actionFailureRenewalDeferred} '
            '${l10n.failureRenewalDeferredSuggestion}',
      _ => null,
    };
