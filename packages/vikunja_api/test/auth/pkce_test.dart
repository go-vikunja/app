import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/src/auth/pkce.dart';

final _base64UrlWithoutPadding = RegExp(r'^[A-Za-z0-9_-]+$');

void main() {
  test('the S256 challenge matches RFC 7636 appendix B', () {
    expect(
      codeChallengeS256('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'),
      'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
    );
  });

  test('the RFC 7636 appendix B octets encode to its verifier', () {
    const octets = [
      116, 24, 223, 180, 151, 153, 224, 37, 79, 250, 96, 125, 216, 173, //
      187, 186, 22, 212, 37, 77, 105, 214, 191, 240, 91, 88, 5, 88, 83, //
      132, 141, 121,
    ];
    final verifier = generateCodeVerifier(random: _Replay(octets));

    expect(verifier, 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk');
  });

  test('a verifier is 43 characters from 32 random bytes', () {
    final verifier = generateCodeVerifier();

    expect(verifier, hasLength(43));
    expect(verifier, matches(_base64UrlWithoutPadding));
  });

  test('a state is 22 characters from 16 random bytes', () {
    final state = generateState();

    expect(state, hasLength(22));
    expect(state, matches(_base64UrlWithoutPadding));
  });

  test('every call draws new randomness', () {
    final verifiers = {for (var i = 0; i < 50; i++) generateCodeVerifier()};

    expect(verifiers, hasLength(50));
  });
}

final class _Replay implements Random {
  new(this._values);

  final List<int> _values;
  var _next = 0;

  @override
  int nextInt(int max) => _values[_next++];

  @override
  bool nextBool() => throw UnimplementedError();

  @override
  double nextDouble() => throw UnimplementedError();
}
