import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

TokenSet _tokens({String refreshToken = 'refresh-secret'}) => TokenSet(
  accessToken: 'access-secret',
  refreshToken: refreshToken,
  accessTokenExpiry: DateTime.utc(2026, 10, 9, 8, 10),
  issuedAt: DateTime.utc(2026, 10, 9, 8),
  sessionId: 'sid-1',
  userId: 7,
  username: 'alice',
);

void main() {
  test('toString never shows a token', () {
    final text = '${_tokens()}';

    expect(text, isNot(contains('access-secret')));
    expect(text, isNot(contains('refresh-secret')));
    expect(text, contains('sid-1'));
  });

  test('token sets with the same fields are equal', () {
    expect(_tokens(), _tokens());
    expect(_tokens().hashCode, _tokens().hashCode);
    expect(_tokens(), isNot(_tokens(refreshToken: 'rotated')));
  });
}
