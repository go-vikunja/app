import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';

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
