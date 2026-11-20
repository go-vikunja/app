import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/settings/user_profile_json.dart';

void main() {
  test('round-trips every field', () {
    final profiles = [
      UserProfile(
        id: 7,
        username: 'alice',
        name: 'Alice Example',
        isLocalUser: false,
        authProvider: 'Company SSO',
        pendingEmail: 'new@example.org',
        updated: DateTime.utc(2026, 10, 20, 9, 30, 15),
        deletionScheduledAt: DateTime.utc(2026, 10, 23, 9, 30, 15),
      ),
      const UserProfile(id: 8, username: 'bob'),
    ];

    for (final profile in profiles) {
      expect(decodeUserProfile(encodeUserProfile(profile)), profile);
    }
  });

  test('the time is stored in UTC', () {
    final profile = UserProfile(
      id: 7,
      username: 'alice',
      updated: DateTime.parse('2026-10-20T11:30:00+02:00'),
    );

    expect(encodeUserProfile(profile), contains('2026-10-20T09:30:00.000Z'));
    expect(
      decodeUserProfile(encodeUserProfile(profile))?.updated,
      DateTime.utc(2026, 10, 20, 9, 30),
    );
  });

  test('a profile stored before the deletion date was kept has none', () {
    final profile = decodeUserProfile(
      '{"id": 7, "username": "alice", "name": "Alice", '
      '"is_local_user": true, "auth_provider": "local", '
      '"updated": "2026-10-20T09:30:00.000Z"}',
    );

    expect(profile?.deletionScheduledAt, isNull);
    expect(profile?.name, 'Alice');
  });

  test('nothing stored, or a value this version cannot read, is null', () {
    for (final stored in [
      null,
      '',
      'not json',
      '[1]',
      '{"id": "7", "username": "alice"}',
      '{"id": 7}',
      '{"id": 7, "username": ""}',
    ]) {
      expect(decodeUserProfile(stored), isNull, reason: stored);
    }
  });

  test('odd fields fall back one by one', () {
    final profile = decodeUserProfile(
      '{"id": 7, "username": "alice", "name": 3, "is_local_user": "no", '
      '"auth_provider": null, "pending_email": "", "updated": "yesterday", '
      '"deletion_scheduled_at": 3}',
    );

    expect(profile, const UserProfile(id: 7, username: 'alice'));
  });

  test('a value stored by this version reads the same, field by field, '
      'and the stored format stays as it is', () {
    final everyField = UserProfile(
      id: 7,
      username: 'alice',
      name: 'Alice',
      isLocalUser: false,
      authProvider: 'oidc-company',
      pendingEmail: 'new@example.org',
      updated: DateTime.utc(2026, 10, 20, 9, 30, 15),
      deletionScheduledAt: DateTime.utc(2026, 10, 23, 9, 30, 15),
    );
    const stored =
        '{"id":7,"username":"alice","name":"Alice",'
        '"is_local_user":false,"auth_provider":"oidc-company",'
        '"pending_email":"new@example.org",'
        '"updated":"2026-10-20T09:30:15.000Z",'
        '"deletion_scheduled_at":"2026-10-23T09:30:15.000Z"}';
    const storedBare =
        '{"id":8,"username":"bob","name":"","is_local_user":true,'
        '"auth_provider":""}';
    const bare = UserProfile(id: 8, username: 'bob');

    expect(decodeUserProfile(stored), everyField);
    expect(encodeUserProfile(everyField), stored);
    expect(decodeUserProfile(storedBare), bare);
    expect(encodeUserProfile(bare), storedBare);
  });
}
