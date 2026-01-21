final RegExp _emailRegex = new RegExp(
  r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$',
);

bool isEmail(String? email) {
  if (email == null) return false;
  return _emailRegex.hasMatch(email);
}

final RegExp _urlRegex = new RegExp(
  r'https?:\/\/((([a-zA-Z0-9.\-\_]+)\.[a-zA-Z]+)|(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}))(:[0-9]+)?',
);

bool isUrl(String? url) {
  if (url == null) return false;
  return _urlRegex.hasMatch(url);
}

final RegExp versionRegex = new RegExp(
  r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$',
);

bool isURLValid(String? url) {
  if (url == null || url.isEmpty) return true;
  final trimmed = url.trim();
  if (isUrl(trimmed) || isUrl('https://$trimmed')) return true;
  return false;
}
