import 'package:vikunja_api/vikunja_api.dart';

/// The access token of a token response that was not persisted yet; it is
/// minutes old, so a rejection is final.
final class IssuedAccessToken implements AccessTokenSource {
  const new(this._accessToken);

  final String _accessToken;

  @override
  Future<String> validAccessToken() async => _accessToken;

  @override
  Future<String?> refreshAfterRejection(String rejectedToken) async => null;
}
