import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

void main() {
  test('equal by name, teams in order and the confirmation flag', () {
    InvitePreview preview({bool skips = true}) => InvitePreview(
      name: 'Spring intake',
      teams: const [
        InviteTeam(id: 3, name: 'Kitchen'),
        InviteTeam(id: 5, name: 'Garden'),
      ],
      skipsEmailConfirmation: skips,
    );

    expect(preview(), preview());
    expect(preview().hashCode, preview().hashCode);
    expect(preview(), isNot(preview(skips: false)));
    expect(
      preview(),
      isNot(
        InvitePreview(
          name: 'Spring intake',
          teams: const [
            InviteTeam(id: 5, name: 'Garden'),
            InviteTeam(id: 3, name: 'Kitchen'),
          ],
          skipsEmailConfirmation: true,
        ),
      ),
    );
  });

  test('the teams cannot be changed afterwards', () {
    final teams = [const InviteTeam(id: 1, name: 'A')];
    final preview = InvitePreview(name: '', teams: teams);
    teams.add(const InviteTeam(id: 2, name: 'B'));

    expect(preview.teams, hasLength(1));
    expect(
      () => preview.teams.add(const InviteTeam(id: 3, name: 'C')),
      throwsUnsupportedError,
    );
  });

  test('toString names neither the invite nor its teams', () {
    final preview = InvitePreview(
      name: 'Secret club',
      teams: const [InviteTeam(id: 9, name: 'Inner circle')],
    );

    expect('$preview', isNot(contains('Secret')));
    expect('$preview', isNot(contains('Inner')));
    expect('${preview.teams.single}', 'InviteTeam(9)');
  });
}
