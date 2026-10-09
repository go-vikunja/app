import 'package:meta/meta.dart';

/// How this app identifies itself to Vikunja's OAuth server. Vikunja has no
/// client registry: [clientId] is free text that must match between the
/// authorize and token calls, and [redirectUri]'s scheme must start with
/// `vikunja-`.
@immutable
final class OAuthClientConfig {
  const new({required this.clientId, required this.redirectUri});

  final String clientId;
  final Uri redirectUri;
}
