import 'package:flutter/foundation.dart';

/// What a connection profile belongs to: scheme, host and effective port.
/// Two servers under different paths of one origin share TLS, so they share
/// the profile. ws and wss count as http and https.
@immutable
final class OriginKey {
  const new _(this.scheme, this.host, this.port);

  /// Throws an [ArgumentError] for a scheme other than http(s) or ws(s), or
  /// a URL without a host.
  factory of(Uri uri) {
    final scheme = switch (uri.scheme.toLowerCase()) {
      'http' || 'ws' => 'http',
      'https' || 'wss' => 'https',
      _ => throw ArgumentError.value(
        uri.scheme,
        'uri',
        'Not an http, https, ws or wss URL',
      ),
    };
    if (uri.host.isEmpty) {
      throw ArgumentError.value(uri.host, 'uri', 'A URL without a host');
    }
    final port = uri.hasPort ? uri.port : (scheme == 'https' ? 443 : 80);
    return OriginKey._(scheme, uri.host.toLowerCase(), port);
  }

  /// Parses exactly what [toString] produces; throws a [FormatException]
  /// for anything else.
  factory fromString(String value) {
    final match = _canonical.firstMatch(value);
    if (match != null) {
      final bracketed = match[2]!;
      final host = bracketed.startsWith('[')
          ? bracketed.substring(1, bracketed.length - 1)
          : bracketed;
      final port = int.parse(match[3]!);
      final key = OriginKey._(match[1]!, host, port);
      if (port > 0 &&
          port < 65536 &&
          host == host.toLowerCase() &&
          key.toString() == value) {
        return key;
      }
    }
    throw FormatException('Not an origin key', value);
  }

  static OriginKey? tryParse(String value) {
    try {
      return OriginKey.fromString(value);
    } on FormatException {
      return null;
    }
  }

  /// Null where [OriginKey.of] would throw.
  static OriginKey? tryOf(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (uri.host.isEmpty ||
        !const {'http', 'https', 'ws', 'wss'}.contains(scheme)) {
      return null;
    }
    return OriginKey.of(uri);
  }

  static final _canonical = RegExp(
    r'^(https?)://(\[[^\[\]/]+\]|[^\[\]/:@?#]+):(\d{1,5})$',
  );

  /// `http` or `https`.
  final String scheme;

  /// Lower case, as `Uri.host` gives it: an IPv6 address without brackets.
  final String host;
  final int port;

  bool get isSecure => scheme == 'https';

  Uri get uri => Uri(scheme: scheme, host: host, port: port);

  /// For texts: the host, in brackets when it is an IPv6 address, with the
  /// port only when it is not the scheme's default.
  String get authority {
    final defaultPort = isSecure ? 443 : 80;
    return port == defaultPort ? _bracketedHost : '$_bracketedHost:$port';
  }

  String get _bracketedHost => host.contains(':') ? '[$host]' : host;

  /// Always with the port, e.g. `https://example.com:443` or
  /// `https://[::1]:8443`.
  @override
  String toString() => '$scheme://$_bracketedHost:$port';

  @override
  bool operator ==(Object other) =>
      other is OriginKey &&
      other.scheme == scheme &&
      other.host == host &&
      other.port == port;

  @override
  int get hashCode => Object.hash(scheme, host, port);
}
