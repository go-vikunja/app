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

  group('a link share guest', () {
    Account guest({String? shareName = 'Helper', bool needsReauth = false}) =>
        Account.linkShare(
          id: 'fedcba9876543210fedcba9876543210',
          serverRoot: Uri.parse('https://tasks.example.com/vikunja'),
          shareId: 84,
          projectId: 1378,
          displayName: 'Shopping',
          addedAt: DateTime.utc(2026, 10, 26),
          shareName: shareName,
          needsReauth: needsReauth,
        );

    test('is the pseudo user the server shows for the share', () {
      final account = guest();

      expect(account.kind, AccountKind.linkShare);
      expect(account.isLinkShare, isTrue);
      expect(account.linkShareId, 84);
      expect(account.projectId, 1378);
      expect(account.shareName, 'Helper');
      expect(account.userId, -84);
      expect(account.username, 'link-share-84');
      expect(account.displayName, 'Shopping');
    });

    test('a user has no guest fields', () {
      expect(_account.kind, AccountKind.user);
      expect(_account.isLinkShare, isFalse);
      expect(_account.linkShareId, isNull);
      expect(_account.projectId, isNull);
      expect(_account.shareName, isNull);
    });

    test('equality covers the kind and the guest fields', () {
      expect(guest(), guest());
      expect(guest().hashCode, guest().hashCode);
      expect(guest(), isNot(guest(shareName: null)));
      expect(guest(), isNot(guest(needsReauth: true)));
      expect(
        Account(
          id: guest().id,
          serverRoot: guest().serverRoot,
          userId: -84,
          username: 'link-share-84',
          displayName: 'Shopping',
          addedAt: DateTime.utc(2026, 10, 26),
        ),
        isNot(guest(shareName: null)),
      );
    });

    test('copyWith keeps it a guest of the same share', () {
      final changed = guest().copyWith(
        displayName: 'Groceries',
        needsReauth: true,
      );

      expect(changed.isLinkShare, isTrue);
      expect(changed.linkShareId, 84);
      expect(changed.projectId, 1378);
      expect(changed.shareName, 'Helper');
      expect(changed.userId, -84);
      expect(changed.displayName, 'Groceries');
      expect(changed.needsReauth, isTrue);
      expect(guest().copyWith(), guest());
    });
  });
}
