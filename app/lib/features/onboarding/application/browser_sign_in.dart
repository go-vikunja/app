import 'package:flutter/foundation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

@immutable
final class BrowserSignIn {
  const new({this.openIdProviderNames = const []});

  final List<String> openIdProviderNames;
}

/// Null when the server cannot be signed in to: browser sign-in
/// (OAuth 2.0 + PKCE) is the only sign-in method the app offers.
BrowserSignIn? browserSignInFor(ServerConnection connection) {
  final capabilities = connection.capabilities;
  if (!capabilities.isSupported || !capabilities.has(Capability.oauthPkce)) {
    return null;
  }
  return BrowserSignIn(
    openIdProviderNames: [
      if (capabilities.has(Capability.openIdConnect))
        for (final provider in connection.info.auth.openIdProviders)
          provider.name,
    ],
  );
}
