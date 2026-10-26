import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

void main() {
  test('a cleared colour is a change, an unset one is not', () {
    expect(const LabelChanges().isEmpty, isTrue);
    expect(const LabelChanges(hexColor: '').isEmpty, isFalse);
    expect(const LabelChanges(hexColor: ''), isNot(const LabelChanges()));
  });

  test('equal by every field', () {
    expect(
      const LabelChanges(title: 'a', description: '<p>b</p>', hexColor: 'c'),
      const LabelChanges(title: 'a', description: '<p>b</p>', hexColor: 'c'),
    );
    expect(
      const LabelChanges(title: 'a').hashCode,
      const LabelChanges(title: 'a').hashCode,
    );
    expect(const LabelChanges(title: 'a'), isNot(const LabelChanges()));
  });

  test('toString names the fields without their text', () {
    const changes = LabelChanges(title: 'Secret plans', hexColor: '');

    expect(changes.toString(), 'LabelChanges(title, hexColor)');
  });

  test('the title limit is the server limit', () {
    expect(Label.maxTitleLength, 250);
  });
}
