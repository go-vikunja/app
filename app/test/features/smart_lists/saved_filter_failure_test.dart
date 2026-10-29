import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/smart_lists/presentation/saved_filter_failure.dart';

import '../../helpers/pump_app.dart';

void main() {
  for (final l10n in [en, de]) {
    group(l10n.localeName, () {
      String text(Object error) =>
          savedFilterFailureText(l10n, error, fromForm: true);

      test('an invalid comparator keeps the server detail, at the filter '
          'field', () {
        const comparator = DomainError(
          400,
          code: 4017,
          message: ' Invalid comparator. ',
        );
        expect(
          text(comparator),
          l10n.projectViewFilterInvalid('Invalid comparator.'),
        );
        expect(isInvalidSavedFilter(comparator), isTrue);
      });

      test('a filter too complex in our words, at the filter field', () {
        const tooComplex = DomainError(
          400,
          code: 4033,
          message: 'The filter is too complex.',
        );
        expect(text(tooComplex), l10n.filterErrorTooComplex);
        expect(isInvalidSavedFilter(tooComplex), isTrue);
      });

      test('a server error in our words, not at the filter field', () {
        const busy = ServerFailure(500, message: 'Internal Server Error');
        expect(text(busy), l10n.actionFailureServerError);
        expect(isInvalidSavedFilter(busy), isFalse);
      });

      test('an unmapped refusal keeps the server detail', () {
        expect(
          text(const DomainError(400, code: 9999, message: 'Odd')),
          l10n.projectChangeRefused('Odd'),
        );
      });
    });
  }
}
