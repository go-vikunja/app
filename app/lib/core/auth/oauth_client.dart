import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:vikunja_api/vikunja_api.dart';

/// Vikunja only accepts custom redirect schemes that start with `vikunja-`.
/// Android registers it for flutter_web_auth_2's CallbackActivity in
/// AndroidManifest.xml.
const oauthCallbackScheme = 'vikunja-dev.coderoftime.vikunja';

final OAuthClientConfig appOAuthClient = OAuthClientConfig(
  clientId: 'dev.coderoftime.vikunja',
  redirectUri: Uri.parse('$oauthCallbackScheme://oauth/callback'),
);

/// The same user on the same server always maps to the same id, so signing
/// in again replaces the session instead of adding a second account.
String accountIdFor(Uri serverRoot, int userId) => sha256
    .convert(utf8.encode('$serverRoot|$userId'))
    .toString()
    .substring(0, 32);
