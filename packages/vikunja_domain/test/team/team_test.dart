import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

const _owner = User(id: 1, username: 'owner', name: 'Olga');
const _member = User(id: 2, username: 'member');

Team _team({List<TeamMember>? members, Permission? maxPermission}) => Team(
  id: 4,
  name: 'Design',
  description: '<p>d</p>',
  createdBy: _owner,
  members:
      members ??
      const [TeamMember(user: _owner, admin: true), TeamMember(user: _member)],
  created: DateTime.utc(2026),
  updated: DateTime.utc(2026, 3),
  maxPermission: maxPermission,
);

void main() {
  test('teams are equal by value, members included', () {
    expect(_team(), _team());
    expect(_team().hashCode, _team().hashCode);
    expect(
      _team(members: const [TeamMember(user: _owner, admin: true)]),
      isNot(_team()),
    );
    expect(
      _team(
        members: const [
          TeamMember(user: _owner, admin: true),
          TeamMember(user: _member, admin: true),
        ],
      ),
      isNot(_team()),
    );
    expect(_team(maxPermission: Permission.admin), isNot(_team()));
  });

  test('members cannot be changed', () {
    expect(
      () => _team().members.add(const TeamMember(user: _member)),
      throwsUnsupportedError,
    );
  });

  test('toString leaves the name out', () {
    expect(_team().toString(), 'Team(4, 2 members)');
    expect(
      const TeamMember(user: _owner, admin: true).toString(),
      'TeamMember(1, admin: true)',
    );
  });

  test('new teams and team changes hide user text', () {
    expect(
      const NewTeam(name: 'Secret', isPublic: true).toString(),
      'NewTeam(isPublic: true)',
    );
    expect(
      const TeamChanges(name: 'Secret', description: '').toString(),
      'TeamChanges(name, description)',
    );
    expect(const TeamChanges().isEmpty, isTrue);
    expect(const TeamChanges(isPublic: false).isEmpty, isFalse);
    expect(const NewTeam(name: 'a'), const NewTeam(name: 'a'));
    expect(const TeamChanges(description: ''), isNot(const TeamChanges()));
  });

  test('the name limit is the server limit', () {
    expect(Team.maxNameLength, 250);
  });
}
