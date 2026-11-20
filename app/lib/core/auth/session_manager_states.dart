import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/session_diagnostics.dart';
import 'package:vikunja_mobile/core/platform/app_part.dart';

/// Why a `SessionManager` hands out nothing; none while it is live.
sealed class SessionStop {
  const new();
}

/// Every call throws [failure] until storage holds tokens that no refresh
/// of this manager has spent.
final class EndedStop extends SessionStop {
  const new(this.failure);

  final SessionEnded failure;
}

/// Signed out or replaced by a new sign-in, for good.
final class RetiredStop extends SessionStop {
  const new();
}

sealed class StopEvent {
  const new();
}

final class EndEvent extends StopEvent {
  const new(this.failure);

  final SessionEnded failure;
}

/// Storage holds tokens no refresh of this manager has spent.
final class ReviveEvent extends StopEvent {
  const new();
}

final class RetireEvent extends StopEvent {
  const new();
}

SessionStop? stopAfter(SessionStop? stop, StopEvent event) =>
    switch ((stop, event)) {
      (RetiredStop(), _) || (_, RetireEvent()) => const RetiredStop(),
      (_, EndEvent(:final failure)) => EndedStop(failure),
      (EndedStop(), ReviveEvent()) => null,
      (null, ReviveEvent()) => null,
    };

/// What the diagnostics hold about the refresh token being sent, kept for
/// this send's verdict (D59).
sealed class SendNote {
  const new();

  /// Before a send of [token]: a marker the diagnostics already hold for it
  /// is kept, as the earliest send whose answer was never stored is the one
  /// the server may have rotated, and a refused token rotates no more.
  /// Otherwise this send notes itself.
  factory forSend(
    RefreshMarker? stored, {
    required String token,
    required DateTime at,
    required AppPart part,
  }) => stored != null && stored.token == token
      ? NotedEarlier(stored)
      : NotedHere((token: token, sentAt: at, sentBy: part, refusedAt: null));

  /// The marker an earlier send left, or the one this send wrote once a
  /// server error kept it.
  RefreshMarker? get earlier => switch (this) {
    NotedEarlier(:final marker) => marker,
    Unnoted() || NotedHere() => null,
  };

  /// Whether this send wrote the marker the diagnostics hold, which a
  /// failure proving the send never reached the server takes back.
  bool get wroteMarker => this is NotedHere;

  /// The server may have rotated before failing, so the send stays noted
  /// whatever becomes of the retry.
  SendNote get afterServerError => switch (this) {
    NotedHere(:final written) => NotedEarlier(written),
    final note => note,
  };

  /// A send that never reached the server cannot have rotated the token;
  /// the caller takes back the marker it wrote ([wroteMarker]).
  SendNote get afterUnreached => switch (this) {
    NotedHere() => const Unnoted(),
    final note => note,
  };

  /// The refusal replaces the marker this send wrote.
  SendNote get afterRefused => afterUnreached;

  /// [earlier] when it is about [token], a fingerprint.
  RefreshMarker? earlierSendOf(String? token) {
    final marker = earlier;
    return marker != null && marker.token == token ? marker : null;
  }

  /// Whether the server refused [token] more than [window] before [now].
  bool refusedBefore(
    String token, {
    required DateTime now,
    required Duration window,
  }) {
    final refusedAt = earlierSendOf(token)?.refusedAt;
    return refusedAt != null && now.difference(refusedAt) > window;
  }
}

final class Unnoted extends SendNote {
  const new();
}

/// This send wrote [written]; a failure proving it never reached the server
/// takes it back.
final class NotedHere extends SendNote {
  const new(this.written);

  final RefreshMarker written;
}

final class NotedEarlier extends SendNote {
  const new(this.marker);

  final RefreshMarker marker;
}

/// 16004 says a sibling won the race; 16002 can mean the same when the
/// sibling finished first.
bool isLostRotation(VikunjaFailure failure) =>
    failure is RefreshRaceLost ||
    (failure is SessionEnded &&
        failure.reason == SessionEndReason.invalidRefreshToken);

/// Answers the server or something in front of it gave without rotating
/// the token, and requests that never left the device.
bool isNeverProcessed(VikunjaFailure failure) => switch (failure) {
  RateLimited() || OAuthFailure() => true,
  UnexpectedResponse(:final statusCode?) =>
    statusCode >= 400 && statusCode < 500,
  final NetworkFailure network => neverReachedServer(network),
  _ => false,
};

/// Failures after which a token that has not expired yet is still handed
/// out.
bool isTransientFailure(VikunjaFailure failure) =>
    failure is NetworkFailure ||
    failure is ServerFailure ||
    failure is RateLimited ||
    failure is UnexpectedResponse;

enum LostRotationVerdict { defer, end }

/// When the re-reads after a lost rotation found no newer tokens: after a
/// race the winner holds a live session, so the refresh is put off; a
/// refusal without any sign of a race ends the session, and so does a race
/// refused once more after the window has passed, as then no winner ever
/// stored anything. [token] is the fingerprint of the last token sent.
LostRotationVerdict lostRotationVerdict(
  SendNote note, {
  required bool raced,
  required String token,
  required DateTime now,
  required Duration window,
}) => raced && !note.refusedBefore(token, now: now, window: window)
    ? LostRotationVerdict.defer
    : LostRotationVerdict.end;

enum RestoreStep {
  /// A sign-in resolved the end.
  none,

  /// Another isolate restored the session.
  unmarkOnly,

  /// Whether the stored tokens may be tried depends on them
  /// ([restoreRetries]).
  readStorage,
}

RestoreStep restoreStep(SessionEndDiagnosis ended) =>
    switch (ended.resolution) {
      null => RestoreStep.readStorage,
      SessionEndResolution.restored => RestoreStep.unmarkOnly,
      _ => RestoreStep.none,
    };

/// Whether storage holding [storedToken], a fingerprint, may work again
/// after [ended]: never with the token a refresh had rotated away when it
/// ended, only after a refusal of another token, or after storage that
/// could not be read.
bool restoreRetries(SessionEndDiagnosis ended, String storedToken) {
  if (storedToken == ended.rotatedAwayToken) return false;
  return switch (ended.cause) {
    SessionEndCause.storageUnreadable => true,
    SessionEndCause.refreshRejected =>
      ended.failedToken != null && ended.failedToken != storedToken,
    _ => false,
  };
}
