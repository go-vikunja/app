import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

void main() {
  for (final (what, problem) in [
    ('label title', labelTitleProblem),
    ('team name', teamNameProblem),
  ]) {
    group(what, () {
      test('required and not blank', () {
        expect(problem(''), NameProblem.blank);
        expect(problem('   '), NameProblem.blank);
        expect(problem('\t\n'), NameProblem.blank);
      });

      test('at most 250 code points, counted as the server does', () {
        expect(problem('a' * 250), isNull);
        expect(problem('a' * 251), NameProblem.tooLong);
        expect(problem('ä' * 250), isNull);
        // One code point, two UTF-16 units.
        expect(problem('😀' * 250), isNull);
        expect(problem('😀' * 251), NameProblem.tooLong);
      });

      test('anything else is fine as it is', () {
        expect(problem('2026'), isNull);
        expect(problem(' padded '), isNull);
      });
    });
  }
}
