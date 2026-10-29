import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/teams/presentation/team_failure.dart';

import '../../helpers/pump_app.dart';

void main() {
  for (final l10n in [en, de]) {
    group(l10n.localeName, () {
      test('an empty name (6001) asks for a valid name', () {
        expect(
          teamFailureText(
            l10n,
            const DomainError(
              400,
              code: 6001,
              message: 'The team name cannot be empty',
            ),
            TeamChange.create,
          ),
          l10n.teamInvalid,
        );
      });

      test('a server error in our words', () {
        expect(
          teamFailureText(
            l10n,
            const ServerFailure(500, message: 'Internal Server Error'),
            TeamChange.edit,
          ),
          l10n.actionFailureServerError,
        );
      });

      test('an unmapped refusal keeps the server detail', () {
        expect(
          teamFailureText(
            l10n,
            const DomainError(400, code: 9999, message: 'Odd'),
            TeamChange.edit,
          ),
          l10n.teamRefused('Odd'),
        );
      });
    });
  }
}
