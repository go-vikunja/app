import 'package:meta/meta.dart';
import 'package:vikunja_logic/src/links/link_share_url.dart';

/// A link share's web address taken apart: the web frontend it is under,
/// the share's hash (its long-lived secret) and the view to open.
@immutable
final class ParsedLinkShareUrl {
  const new({required this.base, required this.hash, this.viewId});

  /// The web frontend as a directory, e.g. `https://example.com/vikunja/`.
  /// It is the server root unless the frontend runs on its own host.
  final Uri base;

  /// Never logged, shown or put in a route.
  final String hash;
  final int? viewId;

  /// The canonical link, see [linkShareUrl].
  Uri get url => linkShareUrl(base: base, hash: hash, viewId: viewId);

  /// The link with all but the first four characters of the hash cut, for
  /// showing which link is being opened.
  String get shortened {
    final shown = hash.length > _shownHashLength
        ? hash.substring(0, _shownHashLength)
        : '';
    return '${base}share/$shown…/auth';
  }

  @override
  bool operator ==(Object other) =>
      other is ParsedLinkShareUrl &&
      other.base == base &&
      other.hash == hash &&
      other.viewId == viewId;

  @override
  int get hashCode => Object.hash(base, hash, viewId);

  /// Never with the hash.
  @override
  String toString() => 'ParsedLinkShareUrl(${base.host}, view: $viewId)';
}

/// An admin's registration invite taken apart:
/// `{base}register#invite-link={token}`.
@immutable
final class ParsedInviteLink {
  const new({required this.base, required this.token});

  /// The web frontend as a directory.
  final Uri base;

  /// A secret like a password reset token: never logged, shown or stored.
  final String token;

  @override
  bool operator ==(Object other) =>
      other is ParsedInviteLink && other.base == base && other.token == token;

  @override
  int get hashCode => Object.hash(base, token);

  /// Never with the token.
  @override
  String toString() => 'ParsedInviteLink(${base.host})';
}

const _shownHashLength = 4;
final _hashPattern = RegExp(r'^[A-Za-z0-9]{40}$');
final _whitespace = RegExp(r'\s+');
const _shareAuthFragment = 'share-auth-token=';
const _inviteFragment = 'invite-link=';
// The server makes 64 letters and digits; the web puts them in the link
// percent-encoded, which leaves them as they are.
final _inviteTokenPattern = RegExp(r'^[A-Za-z0-9._~-]{1,512}$');
// The web's routes a guest can be on; everything before them is the base.
const _guestRoutes = {'share', 'projects', 'tasks'};

/// The link share in [text], or null. [text] is a link the web or the app
/// made, `{base}share/{hash}/auth` with an optional `?view={id}`, or an
/// address the web shows a guest, which carries the hash as
/// `#share-auth-token={hash}`; or a pasted or shared text with such a link
/// among other words. The link needs its http(s) scheme. `/auth` and
/// trailing slashes are optional, other query parameters (`logoVisible`)
/// are ignored, and a hash is 40 letters and digits.
ParsedLinkShareUrl? parseLinkShareUrl(String text) =>
    _firstLink(text, _linkShare);

/// The registration invite in [text], or null: `{base}register` with the
/// fragment `invite-link={token}`, alone or among other words.
ParsedInviteLink? parseInviteLink(String text) => _firstLink(text, _invite);

T? _firstLink<T>(String text, T? Function(Uri uri) parse) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  for (final candidate in [trimmed, ...trimmed.split(_whitespace)]) {
    final uri = Uri.tryParse(candidate);
    if (uri == null ||
        !(uri.isScheme('https') || uri.isScheme('http')) ||
        uri.host.isEmpty) {
      continue;
    }
    try {
      if (parse(uri) case final parsed?) return parsed;
    } on FormatException {
      // Percent-escapes that are not UTF-8.
    }
  }
  return null;
}

ParsedLinkShareUrl? _linkShare(Uri uri) {
  final segments = _nonEmpty(uri.pathSegments);
  final share = segments.lastIndexOf('share');
  if (share >= 0) {
    final rest = segments.sublist(share + 1);
    final isShareRoute =
        rest.length == 1 || rest.length == 2 && rest[1] == 'auth';
    if (isShareRoute && _hashPattern.hasMatch(rest.first)) {
      return ParsedLinkShareUrl(
        base: _base(uri, segments.take(share)),
        hash: rest.first,
        viewId: _viewOf(uri),
      );
    }
  }
  if (!uri.fragment.startsWith(_shareAuthFragment)) return null;
  final hash = uri.fragment.substring(_shareAuthFragment.length);
  if (!_hashPattern.hasMatch(hash)) return null;
  final route = segments.indexWhere(_guestRoutes.contains);
  final prefix = route < 0 ? segments : segments.take(route);
  final routeSegments = route < 0 ? const <String>[] : segments.sublist(route);
  return ParsedLinkShareUrl(
    base: _base(uri, prefix),
    hash: hash,
    viewId: switch (routeSegments) {
      ['projects', final project, final view]
          when _positiveInt(project) != null =>
        _positiveInt(view),
      _ => null,
    },
  );
}

ParsedInviteLink? _invite(Uri uri) {
  final segments = _nonEmpty(uri.pathSegments);
  if (segments.isEmpty ||
      segments.last.toLowerCase() != 'register' ||
      !uri.fragment.startsWith(_inviteFragment)) {
    return null;
  }
  final token = uri.fragment.substring(_inviteFragment.length).split('&').first;
  if (!_inviteTokenPattern.hasMatch(token)) return null;
  return ParsedInviteLink(
    base: _base(uri, segments.take(segments.length - 1)),
    token: token,
  );
}

List<String> _nonEmpty(List<String> segments) => [
  for (final segment in segments)
    if (segment.isNotEmpty) segment,
];

Uri _base(Uri uri, Iterable<String> prefix) => Uri(
  scheme: uri.scheme,
  userInfo: uri.userInfo,
  host: uri.host,
  port: uri.hasPort ? uri.port : null,
  path: '/${[...prefix.map(Uri.encodeComponent), ''].join('/')}',
);

int? _viewOf(Uri uri) {
  try {
    return _positiveInt(uri.queryParameters['view']);
  } on FormatException {
    return null;
  }
}

int? _positiveInt(String? text) => switch (int.tryParse(text ?? '')) {
  final value? when value > 0 => value,
  _ => null,
};
