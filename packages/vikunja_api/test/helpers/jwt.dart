import 'dart:convert';

String _segment(Object json) =>
    base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');

/// An unsigned JWT with Vikunja's claim layout; the signature is not checked
/// by the client.
String fakeJwt({
  int type = 1,
  int id = 7,
  String username = 'alice',
  String? sid = '4b1c2a3e-1111-4222-8333-944455556666',
  DateTime? issuedAt,
  DateTime? expiresAt,
  bool withIssuedAt = true,
}) {
  final iat = issuedAt ?? DateTime.utc(2026, 10, 9, 8);
  final exp = expiresAt ?? iat.add(const Duration(minutes: 10));
  return [
    _segment({'alg': 'HS256', 'typ': 'JWT'}),
    _segment({
      'exp': exp.millisecondsSinceEpoch ~/ 1000,
      if (withIssuedAt) 'iat': iat.millisecondsSinceEpoch ~/ 1000,
      'id': id,
      'is_admin': false,
      'jti': '0b6f3c1e-aaaa-4bbb-8ccc-dddddddddddd',
      'sid': ?sid,
      'type': type,
      'username': username,
    }),
    'c2lnbmF0dXJl',
  ].join('.');
}
