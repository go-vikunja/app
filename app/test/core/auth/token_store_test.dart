import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/auth/token_store.dart';

import '../../helpers/auth_fakes.dart';

void main() {
  final issuedAt = DateTime.utc(2026, 10, 9, 12);
  late MemorySecureStore secureStore;
  late TokenStore store;

  setUp(() {
    secureStore = MemorySecureStore();
    store = TokenStore(secureStore);
  });

  test('keeps tokens per account under their documented keys', () async {
    final alice = issueTokens(issuedAt: issuedAt, refreshToken: 'r-alice');
    final bob = issueTokens(
      issuedAt: issuedAt,
      userId: 8,
      refreshToken: 'r-bob',
    );

    await store.write('a1', alice);
    await store.write('b2', bob);

    expect(secureStore.values, {
      'account.a1.refresh_token': 'r-alice',
      'account.a1.access_token': alice.accessToken,
      'account.b2.refresh_token': 'r-bob',
      'account.b2.access_token': bob.accessToken,
    });
    final read = await store.read('a1');
    expect(read?.refreshToken, 'r-alice');
    expect(read?.accessToken, alice.accessToken);
  });

  test('writes the rotated refresh token before the access token', () async {
    await store.write('a1', issueTokens(issuedAt: issuedAt));

    expect(secureStore.operations, [
      'write account.a1.refresh_token',
      'write account.a1.access_token',
    ]);
  });

  test('without a refresh token there is no session', () async {
    secureStore.values['account.a1.access_token'] = 'orphan';

    expect(await store.read('a1'), isNull);
  });

  test('a refresh token without an access token is still a session', () async {
    secureStore.values['account.a1.refresh_token'] = 'r';

    final read = await store.read('a1');

    expect(read?.refreshToken, 'r');
    expect(read?.accessToken, isEmpty);
  });

  test('delete removes only that account', () async {
    await store.write('a1', issueTokens(issuedAt: issuedAt));
    await store.write('b2', issueTokens(issuedAt: issuedAt));

    await store.delete('a1');

    expect(await store.read('a1'), isNull);
    expect(await store.read('b2'), isNotNull);
    expect(secureStore.values.keys, everyElement(startsWith('account.b2.')));
  });

  test('never prints tokens', () async {
    final tokens = issueTokens(issuedAt: issuedAt);
    await store.write('a1', tokens);

    final read = await store.read('a1');

    expect('$read', isNot(contains(tokens.refreshToken)));
    expect('$read', isNot(contains(tokens.accessToken)));
  });
}
