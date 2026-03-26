String normalizeServerURL(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) return trimmed;
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  return 'https://$trimmed';
}

String? extractRefreshCookie(Map<String, String> headers) {
  var setCookie = headers['set-cookie'];
  if (setCookie == null) return null;

  var match = RegExp(r'vikunja_refresh_token=([^;]+)').firstMatch(setCookie);
  return match?.group(1);
}
