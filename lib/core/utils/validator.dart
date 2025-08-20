final RegExp _emailRegex = new RegExp(
  r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$',
);

bool isEmail(String? email) {
  if (email == null) return false;
  return _emailRegex.hasMatch(email);
}

final RegExp _url = new RegExp(
  r'https?:\/\/((([a-zA-Z0-9.\-\_]+)\.[a-zA-Z]+)|(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}))(:[0-9]+)?',
);

bool isUrl(String? url) {
  if (url == null) return false;
  return _url.hasMatch(url);
}
