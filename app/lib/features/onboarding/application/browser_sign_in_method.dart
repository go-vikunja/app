import 'package:flutter/foundation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

@immutable
final class BrowserSignInMethod {
  const new({
    this.openIdProviderNames = const [],
    this.offersRegistration = false,
    this.offersPasswordReset = false,
    this.registrationNeedsInvitation = false,
  });

  final List<String> openIdProviderNames;

  /// What the web's login page links to besides signing in.
  final bool offersRegistration;
  final bool offersPasswordReset;

  /// Registration is closed, but the server's invite links still open it.
  final bool registrationNeedsInvitation;
}

/// Null when the server cannot be signed in to: browser sign-in
/// (OAuth 2.0 + PKCE) is the only sign-in method the app offers.
BrowserSignInMethod? browserSignInMethodFor(ServerConnection connection) {
  final capabilities = connection.capabilities;
  if (!capabilities.isSupported || !capabilities.has(Capability.oauthPkce)) {
    return null;
  }
  final localAuth = capabilities.has(Capability.localAuth);
  final registration = capabilities.has(Capability.registration);
  return BrowserSignInMethod(
    openIdProviderNames: [
      if (capabilities.has(Capability.openIdConnect))
        for (final provider in connection.info.auth.openIdProviders)
          provider.name,
    ],
    offersRegistration: registration,
    // The web shows "Forgot your password?" with local accounts only.
    offersPasswordReset: localAuth,
    registrationNeedsInvitation:
        localAuth && !registration && capabilities.has(Capability.userInvites),
  );
}
