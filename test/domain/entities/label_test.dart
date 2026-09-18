import 'package:flutter_test/flutter_test.dart';

import '../../helpers/builders.dart';

void main() {
  group('Label equality', () {
    test('two labels with the same id are equal regardless of title', () {
      expect(
        buildLabel(id: 1, title: 'Bug'),
        buildLabel(id: 1, title: 'Defect'),
      );
    });

    test('labels with different ids are not equal', () {
      expect(buildLabel(id: 1), isNot(buildLabel(id: 2)));
    });

    test('a label equals itself', () {
      final label = buildLabel();

      expect(label, label);
    });

    test('a label is not equal to a non-label', () {
      // ignore: unrelated_type_equality_checks
      expect(buildLabel(id: 1) == 'Bug', isFalse);
    });

    test('hashCode follows the id, so labels dedupe in a Set', () {
      final set = {
        buildLabel(id: 1, title: 'Bug'),
        buildLabel(id: 1, title: 'Defect'),
      };

      expect(set, hasLength(1));
    });
  });
}
