import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

void main() {
  test('the defaults: a local account without a provider, no pending email '
      'and no update time', () {
    const profile = UserProfile(id: 1, username: 'dora');

    expect(profile.name, '');
    expect(profile.isLocalUser, isTrue);
    expect(profile.authProvider, '');
    expect(profile.pendingEmail, isNull);
    expect(profile.updated, isNull);
  });

  test('displayName is the trimmed name, else the username', () {
    expect(
      const UserProfile(id: 1, username: 'dora', name: ' Dora ').displayName,
      'Dora',
    );
    expect(
      const UserProfile(id: 1, username: 'dora', name: ' ').displayName,
      'dora',
    );
  });

  test('user carries id, username and name', () {
    expect(
      const UserProfile(
        id: 7,
        username: 'dora',
        name: 'Dora',
        isLocalUser: false,
        authProvider: 'Company SSO',
      ).user,
      const User(id: 7, username: 'dora', name: 'Dora'),
    );
  });

  test('equal by every field', () {
    final updated = DateTime.utc(2026, 10, 20, 9);
    final base = UserProfile(
      id: 1,
      username: 'dora',
      name: 'Dora',
      authProvider: 'local',
      pendingEmail: 'new@example.com',
      updated: updated,
    );

    expect(
      UserProfile(
        id: 1,
        username: 'dora',
        name: 'Dora',
        authProvider: 'local',
        pendingEmail: 'new@example.com',
        updated: updated,
      ),
      base,
    );
    for (final other in [
      UserProfile(id: 2, username: 'dora', name: 'Dora', updated: updated),
      UserProfile(
        id: 1,
        username: 'dora',
        name: 'Dora',
        authProvider: 'local',
        pendingEmail: 'new@example.com',
        updated: updated.add(const Duration(seconds: 1)),
      ),
      UserProfile(
        id: 1,
        username: 'dora',
        name: 'Dora',
        isLocalUser: false,
        authProvider: 'local',
        pendingEmail: 'new@example.com',
        updated: updated,
      ),
      UserProfile(
        id: 1,
        username: 'dora',
        name: 'Dora',
        authProvider: 'ldap',
        pendingEmail: 'new@example.com',
        updated: updated,
      ),
      UserProfile(
        id: 1,
        username: 'dora',
        name: 'Dora',
        authProvider: 'local',
        updated: updated,
      ),
    ]) {
      expect(other, isNot(base));
    }
    expect(
      base.hashCode,
      isNot(const UserProfile(id: 1, username: 'x').hashCode),
    );
  });

  test('toString leaves out the name and the pending email', () {
    const profile = UserProfile(
      id: 1,
      username: 'dora',
      name: 'Dora Secret',
      pendingEmail: 'hidden@example.com',
    );

    expect(profile.toString(), 'UserProfile(1, dora)');
  });
}
