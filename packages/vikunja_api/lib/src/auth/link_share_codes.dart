/// Vikunja's error codes for link shares.
abstract final class LinkShareCodes {
  /// The share has a password and none was given.
  static const passwordRequired = 13001;

  static const wrongPassword = 13002;

  /// v1's answer to a guest whose share is gone; v2 answers 401 without a
  /// code, which only `LinkShareGoneInterceptor` can tell from a user's 401.
  static const tokenInvalid = 13003;
}
