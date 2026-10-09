import 'package:meta/meta.dart';

/// Why an API call failed, normalized across the v1 `{code, message}`, v2
/// problem+json and plain Echo error shapes. `code` is Vikunja's numeric
/// error code when the server sent one.
@immutable
sealed class VikunjaFailure implements Exception {
  const new({this.code, this.message = ''});

  final int? code;

  /// Server-provided detail, untranslated. Never shown verbatim when a
  /// localized text exists for [code].
  final String message;
}

enum NetworkProblem { unreachable, timeout, tls }

final class NetworkFailure extends VikunjaFailure {
  const new(this.problem, {this.cause}) : super();

  final NetworkProblem problem;
  final Object? cause;

  @override
  String toString() => 'NetworkFailure($problem)';
}

/// 401 with code 11: the access token is missing, malformed or expired. For a
/// user JWT one refresh may help; anything else means re-authentication.
final class TokenRejected extends VikunjaFailure {
  const new({super.message}) : super(code: 11);

  @override
  String toString() => 'TokenRejected';
}

enum SessionEndReason {
  /// 16002: the refresh token is unknown or was already rotated.
  invalidRefreshToken,

  /// 16003: the session was idle longer than the server allows.
  expired,

  /// 1020: the account is disabled.
  accountDisabled,

  /// 1040: the account is locked.
  accountLocked,
}

/// The server-side session is gone; only a new sign-in helps. Local data is
/// kept.
final class SessionEnded extends VikunjaFailure {
  const new(this.reason, {super.code, super.message});

  final SessionEndReason reason;

  @override
  String toString() => 'SessionEnded($reason)';
}

/// 16004: another refresh with the same token won the rotation race. The
/// winner's tokens are usually already in storage.
final class RefreshRaceLost extends VikunjaFailure {
  const new({super.message}) : super(code: 16004);

  @override
  String toString() => 'RefreshRaceLost';
}

enum OAuthProblem {
  clientMismatch,
  invalidRedirectUri,
  pkceMissing,
  codeInvalid,
  codeExpired,
  pkceMismatch,
  unsupportedGrant,
}

/// 17001–17007 from the OAuth endpoints.
final class OAuthFailure extends VikunjaFailure {
  const new(this.problem, {super.code, super.message});

  final OAuthProblem problem;

  @override
  String toString() => 'OAuthFailure($problem, code: $code)';
}

final class Forbidden extends VikunjaFailure {
  const new({super.code, super.message});

  @override
  String toString() => 'Forbidden(code: $code)';
}

/// A 404. Without a Vikunja [code] the route itself is absent (older server,
/// disabled feature or licence gate) rather than a missing entity.
final class NotFound extends VikunjaFailure {
  const new({super.code, super.message});

  bool get routeAbsent => code == null;

  @override
  String toString() => 'NotFound(code: $code)';
}

/// v1 412 with `invalid_fields`, v2 422 with `errors[]`.
final class ValidationFailed extends VikunjaFailure {
  const new({this.fieldErrors = const {}, super.code, super.message});

  /// Field name (without the `body.` prefix) to messages.
  final Map<String, List<String>> fieldErrors;

  @override
  String toString() => 'ValidationFailed(${fieldErrors.keys.join(', ')})';
}

final class RateLimited extends VikunjaFailure {
  const new({this.retryAfter, super.message}) : super();

  final Duration? retryAfter;

  @override
  String toString() => 'RateLimited(retryAfter: $retryAfter)';
}

final class ServerFailure extends VikunjaFailure {
  const new(this.statusCode, {super.code, super.message});

  final int statusCode;

  @override
  String toString() => 'ServerFailure($statusCode, code: $code)';
}

/// Any other error Vikunja reported with a numeric code (e.g. 3001 project
/// not found is a [NotFound]; 4029 invalid repeat is a [DomainError]).
final class DomainError extends VikunjaFailure {
  const new(this.statusCode, {required int super.code, super.message});

  final int statusCode;

  @override
  String toString() => 'DomainError($statusCode, code: $code)';
}

/// A response that matches none of the known shapes.
final class UnexpectedResponse extends VikunjaFailure {
  const new(this.statusCode, {super.message}) : super();

  final int? statusCode;

  @override
  String toString() => 'UnexpectedResponse($statusCode)';
}
