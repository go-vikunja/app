/// Two-factor authentication as `GET /user/settings/totp` reports it.
enum TotpStatus {
  notSetUp,

  /// Enrolled but never confirmed with a code. Only the web's TOTP page
  /// can finish it, or cancel it with the password.
  setupStarted,
  enabled,
}
