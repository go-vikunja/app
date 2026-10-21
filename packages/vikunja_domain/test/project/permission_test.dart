import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

void main() {
  test('the server values', () {
    expect(Permission.fromValue(0), Permission.read);
    expect(Permission.fromValue(1), Permission.write);
    expect(Permission.fromValue(2), Permission.admin);
  });

  test('anything else is unknown', () {
    for (final value in [null, 3, -1, '1', 1.5, true]) {
      expect(Permission.fromValue(value), isNull, reason: '$value');
    }
  });

  test('write and admin can write', () {
    expect(Permission.read.canWrite, isFalse);
    expect(Permission.write.canWrite, isTrue);
    expect(Permission.admin.canWrite, isTrue);
  });
}
