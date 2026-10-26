import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

const _hash = 'AbCdEfGhIjKlMnOpQrStUvWxYz0123456789abcd';

void main() {
  group('LinkShare', () {
    final share = LinkShare(
      id: 3,
      hash: _hash,
      permission: Permission.write,
      name: 'Agency',
      passwordProtected: true,
      sharedBy: const User(id: 1, username: 'owner'),
      created: DateTime.utc(2026),
    );

    test('toString never shows the hash or the name', () {
      expect(share.toString(), isNot(contains(_hash)));
      expect(share.toString(), isNot(contains('Agency')));
      expect(share.toString(), 'LinkShare(3, write, passwordProtected: true)');
    });

    test('equal by value', () {
      expect(
        share,
        LinkShare(
          id: 3,
          hash: _hash,
          permission: Permission.write,
          name: 'Agency',
          passwordProtected: true,
          sharedBy: const User(id: 1, username: 'owner'),
          created: DateTime.utc(2026),
        ),
      );
      expect(
        const LinkShare(id: 3, hash: 'a', permission: Permission.read),
        isNot(const LinkShare(id: 3, hash: 'b', permission: Permission.read)),
      );
    });
  });

  test('a new link share never shows its password or name', () {
    const share = NewLinkShare(
      permission: Permission.read,
      name: 'Agency',
      password: 'hunter22',
    );

    expect(share.toString(), 'NewLinkShare(read, password: true)');
    expect(
      const NewLinkShare(permission: Permission.admin).toString(),
      'NewLinkShare(admin, password: false)',
    );
  });

  test('a team share without a name is a hidden team', () {
    const hidden = ProjectTeamShare(teamId: 9, permission: Permission.read);
    const named = ProjectTeamShare(
      teamId: 9,
      permission: Permission.read,
      teamName: 'Design',
      memberCount: 3,
    );

    expect(hidden.isHidden, isTrue);
    expect(named.isHidden, isFalse);
    expect(named, isNot(hidden));
    expect(named.toString(), 'ProjectTeamShare(9, read)');
  });

  test('user shares are equal by user and permission', () {
    const user = User(id: 2, username: 'b');

    expect(
      const ProjectUserShare(user: user, permission: Permission.admin),
      const ProjectUserShare(user: user, permission: Permission.admin),
    );
    expect(
      const ProjectUserShare(user: user, permission: Permission.admin),
      isNot(const ProjectUserShare(user: user, permission: Permission.read)),
    );
    expect(
      const ProjectUserShare(
        user: user,
        permission: Permission.read,
      ).toString(),
      'ProjectUserShare(2, read)',
    );
  });
}
