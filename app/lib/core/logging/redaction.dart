const redactedPlaceholder = '[redacted]';

/// Scheme, host, port and path only: query strings, fragments and user info
/// can carry tokens or credentials.
String describeUriForLog(Uri uri) {
  if (!uri.hasScheme || uri.host.isEmpty) {
    return redactSecrets(uri.path.isEmpty ? '<relative>' : uri.path);
  }
  final port = uri.hasPort ? ':${uri.port}' : '';
  return '${uri.scheme}://${uri.host}$port${uri.path}';
}

final _redactions = <(RegExp, String Function(Match))>[
  (
    RegExp(
      r'\b(authorization|proxy-authorization|cookie|set-cookie)\s*[:=]\s*[^\r\n]*',
      caseSensitive: false,
    ),
    (m) => '${m[1]}: $redactedPlaceholder',
  ),
  (
    RegExp(r'\b(bearer)\s+[A-Za-z0-9\-._~+/]{16,}=*', caseSensitive: false),
    (m) => '${m[1]} $redactedPlaceholder',
  ),
  (
    RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*'),
    (_) => redactedPlaceholder,
  ),
  (RegExp(r'\btk_[A-Za-z0-9]+'), (_) => redactedPlaceholder),
  (
    RegExp(
      '"(password|old_password|new_password|token|access_token|refresh_token|'
      r'id_token|code|code_verifier|client_secret|totp_passcode|passcode)"\s*:\s*"[^"]*"',
      caseSensitive: false,
    ),
    (m) => '"${m[1]}":"$redactedPlaceholder"',
  ),
  (
    RegExp(
      r'\b(password|token|access_token|refresh_token|id_token|code|'
      r'code_verifier|client_secret|state)=[^&\s"]+',
      caseSensitive: false,
    ),
    (m) => '${m[1]}=$redactedPlaceholder',
  ),
  (
    RegExp(r'(\b[a-z][a-z0-9+.-]*://)[^/\s@]+@', caseSensitive: false),
    (m) => '${m[1]}$redactedPlaceholder@',
  ),
];

/// Removes credentials that may hide in free text such as exception messages.
String redactSecrets(String text) {
  var result = text;
  for (final (pattern, replacement) in _redactions) {
    result = result.replaceAllMapped(pattern, replacement);
  }
  return result;
}
