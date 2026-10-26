import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/jwt.dart';
import '../helpers/link_share_fixtures.dart';

void main() {
  test('the claims a 2.7.0 server signs for a read link', () {
    final claims = LinkShareClaims.tryParse(
      recordedToken('v1_auth_open_2.7.0'),
    )!;

    expect(claims.shareId, 87);
    expect(claims.projectId, 1384);
    expect(claims.permission, Permission.read);
    expect(claims.sharedById, 445);
    expect(claims.guestUserId, -87);
    expect(claims.issuedAt, DateTime.utc(2026, 10, 26, 18, 16, 23));
    expect(
      claims.expiresAt.difference(claims.issuedAt!),
      const Duration(hours: 72),
    );
    expect(claims.expiresAt.isUtc, isTrue);
  });

  test('a write link', () {
    expect(
      LinkShareClaims.tryParse(recordedToken('v2_auth_password_2.7.0'))
          ?.permission,
      Permission.write,
    );
  });

  test('only id, project and expiry are required', () {
    final claims = LinkShareClaims.tryParse(
      unsignedJwt({'type': 2, 'id': 5, 'project_id': 9, 'exp': 1793297783}),
    )!;

    expect(claims.shareId, 5);
    expect(claims.permission, isNull);
    expect(claims.sharedById, isNull);
    expect(claims.issuedAt, isNull);
  });

  test('anything else is not a link share token', () {
    Map<String, Object?> payload() => {
      'type': 2,
      'id': 5,
      'project_id': 9,
      'exp': 1793297783,
    };
    for (final token in [
      fakeJwt(),
      unsignedJwt({...payload(), 'type': 1}),
      unsignedJwt({...payload(), 'type': '2'}),
      unsignedJwt(payload()..remove('id')),
      unsignedJwt({...payload(), 'id': 0}),
      unsignedJwt(payload()..remove('project_id')),
      unsignedJwt(payload()..remove('exp')),
      unsignedJwt({...payload(), 'exp': 'soon'}),
      'eyJ_placeholder_not_a_jwt',
      'a.b.c',
      '',
    ]) {
      expect(LinkShareClaims.tryParse(token), isNull, reason: token);
    }
  });

  test('a link share token is not a user token', () {
    expect(JwtClaims.tryParse(fakeLinkShareJwt()), isNull);
  });

  test('an unknown permission is left open', () {
    expect(
      LinkShareClaims.tryParse(
        unsignedJwt({
          'type': 2,
          'id': 5,
          'project_id': 9,
          'exp': 1793297783,
          'permission': 7,
        }),
      )?.permission,
      isNull,
    );
  });

  test('toString names share and project, never the hash', () {
    final claims = LinkShareClaims.tryParse(fakeLinkShareJwt())!;

    expect('$claims', 'LinkShareClaims(share: 84, project: 1378)');
  });
}
