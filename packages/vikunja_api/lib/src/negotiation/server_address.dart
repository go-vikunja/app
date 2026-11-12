import 'package:meta/meta.dart';
import 'package:vikunja_api/src/negotiation/punycode.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

@immutable
final class ServerAddress {
  const new({
    required this.root,
    required this.hasExplicitScheme,
    required this.hasExplicitPort,
  });

  /// Lowercase scheme and host (punycode for international names), optional
  /// port and sub-path, e.g. `https://example.com/vikunja`. It has no query,
  /// fragment or trailing slash, and the path is cut at its last `/api/v1` or
  /// `/api/v2`.
  final Uri root;
  final bool hasExplicitScheme;
  final bool hasExplicitPort;

  @override
  String toString() =>
      'ServerAddress($root, explicitScheme: $hasExplicitScheme, '
      'explicitPort: $hasExplicitPort)';
}

final _explicitScheme = RegExp('^([a-zA-Z][a-zA-Z0-9+.-]*)://');
final _mistypedHttpScheme = RegExp('^https?[:/]', caseSensitive: false);
// Copy and paste brings these along, and `\s` does not match them.
final _invisible = RegExp(r'[\u00AD\u200B-\u200D\u2060]');
final _whitespace = RegExp(r'\s');
final _authorityEnd = RegExp('[/?#]');
final _ipv6Literal = RegExp(r'\[[^\]]*\]');
final _port = RegExp(r':(\d+)$');
final _trailingSlashes = RegExp(r'/+$');
final _upToApiVersion = RegExp(
  r'^(.*)/api/v[12](?:/.*)?$',
  caseSensitive: false,
);
const _maxLabelLength = 63;

/// Turns what a user typed into the root address of a server. Throws
/// [InvalidServerAddress] for input that cannot name an http(s) server.
ServerAddress normalizeServerAddress(String input) {
  final trimmed = input.replaceAll(_invisible, '').trim();
  if (trimmed.isEmpty ||
      _whitespace.hasMatch(trimmed) ||
      trimmed.startsWith('/')) {
    throw InvalidServerAddress(input);
  }

  final schemeMatch = _explicitScheme.firstMatch(trimmed);
  final hasExplicitScheme = schemeMatch != null;
  if (!hasExplicitScheme && _mistypedHttpScheme.hasMatch(trimmed)) {
    throw InvalidServerAddress(input);
  }
  final scheme = schemeMatch?.group(1)!.toLowerCase() ?? 'https';
  if (scheme != 'http' && scheme != 'https') {
    throw InvalidServerAddress(input);
  }

  final rest = hasExplicitScheme ? trimmed.substring(schemeMatch.end) : trimmed;
  final authorityEnd = rest.indexOf(_authorityEnd);
  final authority = authorityEnd < 0 ? rest : rest.substring(0, authorityEnd);
  // Dart's Uri drops a port equal to the scheme default, so whether the user
  // typed one is read from the raw text.
  final hostAndPort = authority.replaceAll(_ipv6Literal, '');
  final portMatch = _port.firstMatch(hostAndPort);
  final hasExplicitPort = portMatch != null;
  if (authority.contains('@') ||
      (!hasExplicitPort && hostAndPort.contains(':'))) {
    throw InvalidServerAddress(input);
  }

  final host = hasExplicitPort
      ? authority.substring(0, authority.length - portMatch.group(0)!.length)
      : authority;
  final asciiHost = _asciiHost(host, input);
  final parsed = Uri.tryParse(
    '$scheme://$asciiHost${rest.substring(host.length)}',
  );
  if (parsed == null || parsed.host.isEmpty) {
    throw InvalidServerAddress(input);
  }
  if (hasExplicitPort && (parsed.port < 1 || parsed.port > 65535)) {
    throw InvalidServerAddress(input);
  }

  final withoutSlash = parsed.path.replaceFirst(_trailingSlashes, '');
  final path =
      (_upToApiVersion.firstMatch(withoutSlash)?.group(1) ?? withoutSlash)
          .replaceFirst(_trailingSlashes, '');

  return ServerAddress(
    root: Uri(
      scheme: scheme,
      host: parsed.host.toLowerCase(),
      port: hasExplicitPort ? parsed.port : null,
      path: path,
    ),
    hasExplicitScheme: hasExplicitScheme,
    hasExplicitPort: hasExplicitPort,
  );
}

// Dart's Uri percent-encodes a non-ASCII host, which no resolver accepts.
String _asciiHost(String host, String input) =>
    punycodeHost(host) ?? (throw InvalidServerAddress(input));

/// [host] as a resolver takes it: an ASCII host as it is, any other in
/// lower case with its non-ASCII labels in punycode (`xn--…`). Null when
/// such a host has an empty label or one longer than DNS allows.
String? punycodeHost(String host) {
  if (_isAscii(host)) return host;
  final labels = [
    for (final label in host.toLowerCase().split('.'))
      if (_isAscii(label)) label else 'xn--${punycodeEncode(label)}',
  ];
  return labels.any((label) => label.isEmpty || label.length > _maxLabelLength)
      ? null
      : labels.join('.');
}

bool _isAscii(String text) => text.runes.every((codePoint) => codePoint < 0x80);
