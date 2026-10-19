import 'package:vikunja_logic/src/links/url_text.dart';

/// The task id of a web task URL (`<base>/tasks/<id>`), or null: the web's
/// `parseTaskIdFromUrl`.
///
/// [href] is resolved against the origin of the first of [bases] (so a
/// relative href works; the web resolves against its window origin, never
/// against a base path). A base is the server's root or the `frontend_url`
/// of `/info`, each with its path prefix; bases that are not absolute
/// http(s) URLs are ignored. The href is cleaned like a browser's URL
/// parser does (surrounding spaces and controls trimmed, tabs and newlines
/// removed, `\` as `/` before the query). It qualifies when its origin
/// (scheme, lower-cased host, effective port) equals a base's origin and
/// its percent-encoded path is exactly `<base path>/tasks/<digits>` with an
/// id above 0 and at most 2^53 - 1 (the web's numbers are doubles); query
/// and fragment are ignored. Anything else is null: `/tasks/12/edit`,
/// `/tasks/0`, `/tasks/by/upcoming`, look-alike hosts, other schemes, no
/// base path.
int? parseTaskIdFromUrl(String href, {required Iterable<Uri> bases}) {
  final usable = [
    for (final base in bases)
      if (_isHttpBase(base)) base,
  ];
  if (usable.isEmpty) return null;
  final cleaned = cleanUrlText(href);
  if (cleaned.isEmpty) return null;
  final scheme = _scheme.firstMatch(cleaned)?[1]?.toLowerCase();
  if (scheme != null && scheme != 'http' && scheme != 'https') return null;
  final slashed = _slashesBeforeQuery(cleaned);
  if (_hasEscapedUnreservedInPath(slashed)) return null;
  final parsed = Uri.tryParse(slashed);
  if (parsed == null) return null;
  final first = usable.first;
  final Uri resolved;
  try {
    resolved = Uri.parse('${first.origin}/').resolveUri(parsed);
  } on FormatException {
    return null;
  }
  if (!_isHttpBase(resolved)) return null;
  for (final base in usable) {
    if (!_sameOrigin(resolved, base)) continue;
    final basePath = base.path.endsWith('/') ? base.path : '${base.path}/';
    final prefix = '${basePath}tasks/';
    final path = resolved.path;
    if (!path.startsWith(prefix)) continue;
    final rest = path.substring(prefix.length);
    if (!_digits.hasMatch(rest)) continue;
    final id = int.tryParse(rest);
    if (id != null && id > 0 && id <= maxSafeInteger) return id;
  }
  return null;
}

final _scheme = RegExp(r'^([a-zA-Z][a-zA-Z0-9+.\-]*):');
final _digits = RegExp(r'^[0-9]+$');

// http(s) treats a backslash like a slash in the authority and path.
String _slashesBeforeQuery(String text) {
  final end = text.indexOf(RegExp('[?#]'));
  final head = end < 0 ? text : text.substring(0, end);
  final tail = end < 0 ? '' : text.substring(end);
  return '${head.replaceAll(r'\', '/')}$tail';
}

// Dart's Uri decodes `%35` to `5` in a path, a browser keeps the escape,
// so the web never sees digits there.
bool _hasEscapedUnreservedInPath(String text) {
  final end = text.indexOf(RegExp('[?#]'));
  var path = end < 0 ? text : text.substring(0, end);
  final authority = _authorityStart.firstMatch(path);
  if (authority != null) {
    final slash = path.indexOf('/', authority.end);
    path = slash < 0 ? '' : path.substring(slash);
  }
  for (final escape in _escape.allMatches(path)) {
    final char = int.parse(escape[1]!, radix: 16);
    if (_isUnreserved(char)) return true;
  }
  return false;
}

final _authorityStart = RegExp(r'^(?:[a-zA-Z][a-zA-Z0-9+.\-]*:)?//');
final _escape = RegExp('%([0-9A-Fa-f]{2})');

bool _isUnreserved(int char) =>
    (char >= 0x30 && char <= 0x39) ||
    (char >= 0x41 && char <= 0x5a) ||
    (char >= 0x61 && char <= 0x7a) ||
    char == 0x2d ||
    char == 0x2e ||
    char == 0x5f ||
    char == 0x7e;

bool _isHttpBase(Uri uri) =>
    (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;

bool _sameOrigin(Uri a, Uri b) =>
    a.scheme == b.scheme &&
    a.host.toLowerCase() == b.host.toLowerCase() &&
    a.port == b.port;
