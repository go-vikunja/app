import 'package:meta/meta.dart';
import 'package:vikunja_logic/src/links/url_text.dart';
import 'package:vikunja_logic/src/text/rich_text_parser.dart';

/// What the editor's link sheet makes of a typed address.
@immutable
sealed class TypedLinkAddress {
  const new();
}

final class LinkAddressAccepted extends TypedLinkAddress {
  const new(this.href);

  final String href;

  @override
  bool operator ==(Object other) =>
      other is LinkAddressAccepted && other.href == href;

  @override
  int get hashCode => href.hashCode;

  @override
  String toString() => 'LinkAddressAccepted($href)';
}

/// A scheme the web's editor drops a link for, such as `javascript`,
/// lower-cased.
final class LinkAddressRefused extends TypedLinkAddress {
  const new(this.scheme);

  final String scheme;

  @override
  bool operator ==(Object other) =>
      other is LinkAddressRefused && other.scheme == scheme;

  @override
  int get hashCode => scheme.hashCode;

  @override
  String toString() => 'LinkAddressRefused($scheme)';
}

/// [input] as a link's href, read as a browser's address bar reads it: a
/// host without a scheme (`www.example.com/a`, `example.com:8080`,
/// `localhost:3456`, an IP address) gets `https://` and an email address
/// `mailto:`, as either would otherwise point relatively at the Vikunja
/// server. A scheme the web's editor keeps and a relative address (`/a`,
/// `#a`, `notes`) stay as typed, cleaned like a browser cleans a URL; any
/// other scheme is refused, as the editor would drop the link. Null for an
/// empty input.
TypedLinkAddress? typedLinkAddress(String input) {
  final text = cleanUrlText(input);
  if (text.isEmpty) return null;
  if (_emailAddress.hasMatch(text)) return LinkAddressAccepted('mailto:$text');
  if (_hostAddress.hasMatch(text)) return LinkAddressAccepted('https://$text');
  if (allowedLinkHref(text) case final href?) return LinkAddressAccepted(href);
  // The editor's test ignores whitespace, so `java script:` is refused as
  // `javascript`.
  final scheme = _scheme.firstMatch(text.replaceAll(_whitespace, ''));
  return LinkAddressRefused(scheme?[1]?.toLowerCase() ?? '');
}

final _scheme = RegExp(r'^([a-z][a-z0-9+.\-]*):', caseSensitive: false);

final _whitespace = RegExp(
  r'[\x00-\x20\xA0\u1680\u180E\u2000-\u2029\u205F\u3000]',
);

final _emailAddress = RegExp(r'^[^\s@/?#:]+@[^\s@/?#:]+\.[^\s@/?#:]+$');

// A domain needs a top-level label of letters, so `v1.2` and `a.1` stay
// relative.
final _hostAddress = RegExp(
  '^(?:'
  r'(?:[\p{L}\p{N}](?:[\p{L}\p{N}-]*[\p{L}\p{N}])?\.)+'
  r'(?:\p{L}{2,}|xn--[a-z0-9-]+)\.?'
  '|localhost'
  r'|\d{1,3}(?:\.\d{1,3}){3}'
  r'|\[[0-9a-f:.]+\]'
  r')(?::\d{1,5})?(?:[/?#].*)?$',
  caseSensitive: false,
  unicode: true,
);
