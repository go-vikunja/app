import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/features/common/presentation/initials_avatar.dart';

void main() {
  test('initialsOf takes the first letters of the first and last word', () {
    expect(initialsOf('Alice Mary Example'), 'AE');
    expect(initialsOf('  bob  '), 'B');
    expect(initialsOf('élodie durand'), 'ÉD');
    expect(initialsOf('👩‍💻 Dev'), '👩‍💻D');
    expect(initialsOf(''), '?');
  });
}
