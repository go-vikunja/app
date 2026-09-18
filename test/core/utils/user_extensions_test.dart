import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_app/core/utils/user_extensions.dart';

import '../../helpers/builders.dart';

void main() {
  group('UserDisplay.displayName', () {
    test('prefers the full name when one is set', () {
      final user = buildUser(username: 'jdoe', name: 'Jane Doe');

      expect(user.displayName, 'Jane Doe');
    });

    test('falls back to the username when the name is empty', () {
      final user = buildUser(username: 'jdoe', name: '');

      expect(user.displayName, 'jdoe');
    });
  });
}
