import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/auth/link_share_store.dart';

import '../../helpers/auth_fakes.dart';

void main() {
  final hash = 'x' * 40;
  late MemorySecureStore secureStore;
  late LinkShareStore store;

  setUp(() {
    secureStore = MemorySecureStore();
    store = LinkShareStore(secureStore);
  });

  test(
    'keeps the hash and the token per account under their own keys',
    () async {
      await store.write('g1', hash: hash, token: 'jwt-1');

      expect(secureStore.values, {
        'account.g1.share_hash': hash,
        'account.g1.share_token': 'jwt-1',
      });
      final read = await store.read('g1');
      expect(read?.hash, hash);
      expect(read?.token, 'jwt-1');
      expect(await store.read('other'), isNull);
    },
  );

  test('writes the hash before the token', () async {
    await store.write('g1', hash: hash, token: 'jwt-1');

    expect(secureStore.operations, [
      'write account.g1.share_hash',
      'write account.g1.share_token',
    ]);
  });

  test('a renewed token replaces only the token', () async {
    await store.write('g1', hash: hash, token: 'jwt-1');

    await store.writeToken('g1', 'jwt-2');

    expect((await store.read('g1'))?.token, 'jwt-2');
    expect((await store.read('g1'))?.hash, hash);
  });

  test(
    'a hash without its token still counts, a token alone does not',
    () async {
      secureStore.values['account.g1.share_hash'] = hash;
      secureStore.values['account.g2.share_token'] = 'jwt';

      expect((await store.read('g1'))?.token, isNull);
      expect(await store.read('g2'), isNull);
    },
  );

  test('delete removes both secrets, the hash first, and prints nothing of '
      'them', () async {
    await store.write('g1', hash: hash, token: 'jwt-1');
    final read = await store.read('g1');
    secureStore.operations.clear();

    await store.delete('g1');

    expect(secureStore.values, isEmpty);
    expect(secureStore.operations, [
      'delete account.g1.share_hash',
      'delete account.g1.share_token',
    ]);
    expect('$read', isNot(contains(hash)));
    expect('$read', isNot(contains('jwt-1')));
  });
}
