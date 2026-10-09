/// Supplies the bearer token for an authenticated client. Implemented by the
/// app's session manager, so refresh policy and storage stay outside the API
/// package.
abstract interface class AccessTokenSource {
  /// A token that is not about to expire, refreshing proactively if needed.
  /// Throws a `VikunjaFailure` when no valid token can be obtained.
  Future<String> validAccessToken();

  /// Called once after the server answered 401 code 11 for [rejectedToken].
  /// Returns a newer token to retry with, or null when retrying is pointless.
  Future<String?> refreshAfterRejection(String rejectedToken);
}
