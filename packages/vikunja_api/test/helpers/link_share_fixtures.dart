import 'package:dio/dio.dart';

import 'fake_http_adapter.dart';
import 'jwt.dart';

/// What the capture tool puts where a JWT was.
const jwtPlaceholder = 'eyJ_placeholder_not_a_jwt';

/// A capture under test/fixtures/link_share whose token placeholder is
/// replaced by [recordedToken].
FakeRoute linkShareFixture(String name) =>
    (_) => linkShareFixtureBody(name);

ResponseBody linkShareFixtureBody(String name) {
  final fixture = fixtureJson('link_share/$name.json');
  final headers = fixture['headers']! as Map<String, Object?>;
  final body = fixture['body']! as String;
  return ResponseBody.fromString(
    fixture['token_claims'] == null
        ? body
        : body.replaceAll(jwtPlaceholder, recordedToken(name)),
    fixture['status']! as int,
    headers: {
      for (final MapEntry(:key, :value) in headers.entries)
        key: [value! as String],
    },
  );
}

/// An unsigned JWT with the claims the server sent in capture [name].
String recordedToken(String name) => unsignedJwt(
  fixtureJson('link_share/$name.json')['token_claims']! as Map<String, Object?>,
);
