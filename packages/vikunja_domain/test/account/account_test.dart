import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

final _account = Account(
  id: '0123456789abcdef0123456789abcdef',
  serverRoot: Uri.parse('https://tasks.example.com/vikunja'),
  userId: 7,
  username: 'alice',
  displayName: 'Alice',
  addedAt: DateTime.utc(2026, 10, 9),
);

void main() {
  test('accounts with the same fields are equal', () {
    final copy = Account(
      id: _account.id,
      serverRoot: Uri.parse('https://tasks.example.com/vikunja'),
      userId: 7,
      username: 'alice',
      displayName: 'Alice',
      addedAt: DateTime.utc(2026, 10, 9),
    );

    expect(copy, _account);
    expect(copy.hashCode, _account.hashCode);
    expect(_account.needsReauth, isFalse);
  });

  test('copyWith changes only the display name and needsReauth', () {
    final changed = _account.copyWith(
      displayName: 'Alice A.',
      needsReauth: true,
    );

    expect(changed.displayName, 'Alice A.');
    expect(changed.needsReauth, isTrue);
    expect(changed.id, _account.id);
    expect(changed.serverRoot, _account.serverRoot);
    expect(changed.userId, _account.userId);
    expect(changed.username, _account.username);
    expect(changed.addedAt, _account.addedAt);
    expect(changed, isNot(_account));
    expect(_account.copyWith(), _account);
  });

  test('toString names user and host', () {
    expect(
      '$_account',
      'Account(0123456789abcdef0123456789abcdef, alice@tasks.example.com)',
    );
  });
}
