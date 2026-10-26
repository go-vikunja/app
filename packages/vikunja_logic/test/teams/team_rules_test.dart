import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';

const _me = 1;

TeamMember _member(int id, {bool admin = false}) => TeamMember(
  user: User(id: id, username: 'u$id'),
  admin: admin,
);

TeamGuards _guards(List<TeamMember> members, {bool isExternal = false}) =>
    TeamGuards(members: members, currentUserId: _me, isExternal: isExternal);

void main() {
  group('externalTeamProvider', () {
    test('the provider from the suffix the sync appends', () {
      expect(externalTeamProvider('Developers (Keycloak)'), 'Keycloak');
      expect(externalTeamProvider('Ops (LDAP)'), 'LDAP');
      expect(externalTeamProvider('All staff (Azure AD) '), 'Azure AD');
      expect(externalTeamProvider('a (b) (Authentik)'), 'Authentik');
    });

    test('null without a provider suffix', () {
      for (final name in [
        'Developers',
        '(LDAP)',
        'Developers ()',
        'Developers (  )',
        'Developers(Keycloak)',
        'Developers (Key(cloak))',
        'Developers (Keycloak) x',
        '',
      ]) {
        expect(externalTeamProvider(name), isNull, reason: name);
      }
    });
  });

  group('TeamGuards', () {
    test('an admin of a normal team may do everything but act on itself', () {
      final me = _member(_me, admin: true);
      final other = _member(2);
      final guards = _guards([me, other, _member(3, admin: true)]);

      expect(guards.isMember, isTrue);
      expect(guards.isAdmin, isTrue);
      expect(guards.canEdit, isTrue);
      expect(guards.canAddMembers, isTrue);
      expect(guards.canDelete, isTrue);
      expect(guards.canToggleAdmin(other), isTrue);
      expect(guards.canRemoveMember(other), isTrue);
      expect(guards.canToggleAdmin(me), isFalse);
      expect(guards.canRemoveMember(me), isFalse);
      expect(guards.leave, TeamLeaveRule.allowed);
    });

    test('a member only leaves', () {
      final guards = _guards([_member(_me), _member(2, admin: true)]);

      expect(guards.isAdmin, isFalse);
      expect(guards.canEdit, isFalse);
      expect(guards.canAddMembers, isFalse);
      expect(guards.canDelete, isFalse);
      expect(guards.canToggleAdmin(_member(2, admin: true)), isFalse);
      expect(guards.canRemoveMember(_member(2, admin: true)), isFalse);
      expect(guards.leave, TeamLeaveRule.allowed);
    });

    test('the only admin with others makes someone admin first', () {
      expect(
        _guards([_member(_me, admin: true), _member(2)]).leave,
        TeamLeaveRule.makeSomeoneAdminFirst,
      );
    });

    test('the last member deletes the team instead, if allowed', () {
      expect(
        _guards([_member(_me, admin: true)]).leave,
        TeamLeaveRule.deleteInstead,
      );
      // A team whose admins left: nobody can delete it.
      expect(_guards([_member(_me)]).leave, TeamLeaveRule.unavailable);
    });

    test('a member of a team without admins may leave it', () {
      expect(_guards([_member(_me), _member(2)]).leave, TeamLeaveRule.allowed);
    });

    test('an external team is managed by its provider', () {
      final other = _member(2);
      final guards = _guards([
        _member(_me, admin: true),
        other,
      ], isExternal: true);

      expect(guards.canEdit, isFalse);
      expect(guards.canAddMembers, isFalse);
      expect(guards.canToggleAdmin(other), isTrue);
      expect(guards.canRemoveMember(other), isFalse);
      expect(guards.canDelete, isTrue);
      expect(guards.leave, TeamLeaveRule.unavailable);
    });

    test('someone outside the team may do nothing', () {
      final guards = _guards([_member(2, admin: true), _member(3)]);

      expect(guards.isMember, isFalse);
      expect(guards.isAdmin, isFalse);
      expect(guards.canEdit, isFalse);
      expect(guards.canDelete, isFalse);
      expect(guards.canToggleAdmin(_member(3)), isFalse);
      expect(guards.leave, TeamLeaveRule.unavailable);
    });

    test('of takes the members and the external flag from the team', () {
      final team = Team(
        id: 1,
        name: 'Ops (LDAP)',
        isExternal: true,
        members: [_member(_me, admin: true)],
      );

      final guards = TeamGuards.of(team, currentUserId: _me);

      expect(guards.isAdmin, isTrue);
      expect(guards.isExternal, isTrue);
      expect(guards.canEdit, isFalse);
    });
  });
}
