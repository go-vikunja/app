import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

void main() {
  test('equal by every field', () {
    expect(
      const ChecklistToggle.byId('a1', checked: true),
      const ChecklistToggle.byId('a1', checked: true),
    );
    expect(
      const ChecklistToggle.byPosition(
        ordinal: 2,
        text: 'milk',
        checked: false,
      ),
      const ChecklistToggle.byPosition(
        ordinal: 2,
        text: 'milk',
        checked: false,
      ),
    );
    expect(
      const ChecklistToggle.byId('a1', checked: true),
      isNot(const ChecklistToggle.byId('a1', checked: false)),
    );
    expect(
      const ChecklistToggle.byPosition(ordinal: 2, text: 'milk', checked: true),
      isNot(
        const ChecklistToggle.byPosition(
          ordinal: 2,
          text: 'eggs',
          checked: true,
        ),
      ),
    );
  });

  test('a position names no id, an id no position', () {
    const byId = ChecklistToggle.byId('a1', checked: true);
    const byPosition = ChecklistToggle.byPosition(
      ordinal: 0,
      text: 'x',
      checked: true,
    );

    expect((byId.ordinal, byId.text), (null, null));
    expect(byPosition.itemId, isNull);
  });

  test('toString leaves the text out', () {
    expect(
      const ChecklistToggle.byPosition(
        ordinal: 3,
        text: 'secret',
        checked: true,
      ).toString(),
      isNot(contains('secret')),
    );
  });
}
