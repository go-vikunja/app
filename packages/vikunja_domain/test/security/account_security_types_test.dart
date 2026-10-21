import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

void main() {
  test('a session is equal by every field and prints only its id', () {
    final created = DateTime.utc(2026, 10, 21, 5);
    UserSession session({String device = 'Firefox'}) => UserSession(
      id: 'c0ffee00-0000-4000-8000-000000000001',
      deviceInfo: device,
      ipAddress: '172.20.0.1',
      created: created,
      lastActive: created,
    );

    expect(session(), session());
    expect(session().hashCode, session().hashCode);
    expect(session(device: 'Chrome'), isNot(session()));
    expect(
      session().toString(),
      'UserSession(c0ffee00-0000-4000-8000-000000000001)',
    );
  });

  test('an export is expired from its expiry on', () {
    final expires = DateTime.utc(2026, 10, 28, 5);
    final export = UserDataExport(id: 458, size: 2372, expires: expires);

    expect(export.isExpiredAt(expires), isTrue);
    expect(
      export.isExpiredAt(expires.subtract(const Duration(minutes: 1))),
      isFalse,
    );
    expect(export, UserDataExport(id: 458, size: 2372, expires: expires));
    expect(
      export,
      isNot(UserDataExport(id: 459, size: 2372, expires: expires)),
    );
  });

  test('CalDAV tokens are equal by id and creation', () {
    expect(const CaldavToken(id: 1), const CaldavToken(id: 1));
    expect(
      CaldavToken(id: 1, created: DateTime.utc(2026)),
      isNot(const CaldavToken(id: 1)),
    );
  });
}
