import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

void main() {
  group('displayName', () {
    test('is the name when there is one', () {
      expect(
        const User(id: 1, username: 'jdoe', name: 'Jane Doe').displayName,
        'Jane Doe',
      );
    });

    test('is trimmed', () {
      expect(
        const User(id: 1, username: 'jdoe', name: '  Jane  ').displayName,
        'Jane',
      );
    });

    test('falls back to the username for an empty or blank name', () {
      expect(const User(id: 1, username: 'jdoe').displayName, 'jdoe');
      expect(
        const User(id: 1, username: 'jdoe', name: ' \t').displayName,
        'jdoe',
      );
    });
  });

  test('users with the same fields are equal', () {
    const a = User(id: 1, username: 'u', name: 'n', email: 'e@example.com');
    const b = User(id: 1, username: 'u', name: 'n', email: 'e@example.com');

    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(const User(id: 1, username: 'u', name: 'n')));
    expect(a, isNot(const User(id: 2, username: 'u', name: 'n')));
  });

  test('toString shows id and username only', () {
    expect(
      '${const User(id: 1, username: 'u', email: 'secret@example.com')}',
      'User(1, u)',
    );
  });
}
