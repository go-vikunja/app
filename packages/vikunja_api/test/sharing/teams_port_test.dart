import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/server_connection.dart';

// The answers were captured by tool/capture_sharing_fixtures.dart: the owner
// (145) created team one (9) on v1 and team two (10) on v2, added the member
// (146) to both, toggled them to admin and back, and made an external team
// (11) through 2.7.0's `external_id` quirk; the guest (147) is in no team.
const _v1 = '$testServerRoot/api/v1';
const _v2 = '$testServerRoot/api/v2';
const _teamOne = 9;
const _teamTwo = 10;
const _external = 11;
const _owner = User(id: 145, username: 'fixtureowner');
const _member = User(id: 146, username: 'fixturemember');

TeamsPort _port(Dio dio, String version, {int perPage = 50}) => createTeamsPort(
  dio: dio,
  connection: testConnection(hasV2: version == 'v2', maxItemsPerPage: perPage),
);

String _base(String version) => version == 'v2' ? _v2 : _v1;

int _team(String version) => version == 'v2' ? _teamTwo : _teamOne;

FakeRoute _captured(String name) => capturedFixture('sharing/${name}_2.7.0');

FakeRoute _byMethod(Map<String, FakeRoute> routes) =>
    (request) => (routes[request.method] ?? refused)(request);

List<String> _calls(Dio dio) => [
  for (final request in adapterOf(dio).requests)
    '${request.method} ${request.uri}',
];

Matcher _domainError(int status, int code) => isA<DomainError>()
    .having((f) => f.statusCode, 'status', status)
    .having((f) => f.code, 'code', code);

Matcher _notFound(int code) =>
    isA<NotFound>().having((f) => f.code, 'code', code);

final Matcher _forbidden = isA<Forbidden>().having(
  (f) => f.code,
  'code',
  isNull,
);

void main() {
  for (final version in ['v1', 'v2']) {
    final base = _base(version);
    final team = _team(version);
    final create = version == 'v2' ? 'POST' : 'PUT';

    group('$version list', () {
      test('every team with its members, nothing permission-wise', () async {
        final dio = fakeDio({
          '$base/teams?page=1&per_page=50': _captured('${version}_teams'),
        });

        final teams = await _port(dio, version).list();

        expect(_calls(dio), ['GET $base/teams?page=1&per_page=50']);
        expect(teams.map((team) => team.id), [_teamOne, _teamTwo]);
        final one = teams.first;
        expect(one.name, 'Fixture team one');
        expect(one.description, '<p>First</p>');
        expect(one.isPublic, isFalse);
        expect(one.isExternal, isFalse);
        expect(one.createdBy, _owner);
        expect(one.members, const [
          TeamMember(user: _owner, admin: true),
          TeamMember(user: _member),
        ]);
        expect(one.maxPermission, isNull);
        expect(one.created, DateTime.utc(2026, 10, 26, 11, 17, 5));
      });

      test('page after page', () async {
        final dio = fakeDio({
          for (final page in [1, 2])
            '$base/teams?page=$page&per_page=1': _captured(
              '${version}_teams_page_$page',
            ),
        });

        final teams = await _port(dio, version, perPage: 1).list();

        expect(teams.map((team) => team.id), [_teamOne, _teamTwo]);
        expect(adapterOf(dio).requests, hasLength(2));
      });

      test('searched, with public teams', () async {
        final search = version == 'v2' ? 'q' : 's';
        final url =
            '$base/teams?$search=TWO&include_public=true&page=1&per_page=50';
        final dio = fakeDio({url: _captured('${version}_teams_search')});

        final teams = await _port(
          dio,
          version,
        ).list(query: ' TWO ', includePublic: true);

        expect(_calls(dio), ['GET $url']);
        expect(teams.single.id, _teamTwo);
      });

      test('a team listed without members is read on its own', () async {
        final listed = {
          'id': _teamOne,
          'name': 'Fixture team one',
          'members': null,
          'is_public': false,
        };
        final dio = fakeDio({
          '$base/teams?page=1&per_page=50': json(
            version == 'v2'
                ? {
                    'items': [listed],
                    'total': 1,
                    'page': 1,
                    'per_page': 50,
                    'total_pages': 1,
                  }
                : [listed],
          ),
          '$base/teams/$_teamOne': _captured('v1_team_read'),
        });

        final teams = await _port(dio, version).list();

        expect(teams.single.members, hasLength(2));
        expect(teams.single.maxPermission, Permission.admin);
      });
    });

    group('$version read', () {
      test('the admin gets admin, a member read', () async {
        final admin = fakeDio({
          '$base/teams/$team': _captured('${version}_team_read'),
        });
        final member = fakeDio({
          '$base/teams/$team': _captured('${version}_team_read_member'),
        });

        final asAdmin = await _port(admin, version).read(team);
        final asMember = await _port(member, version).read(team);

        expect(asAdmin.maxPermission, Permission.admin);
        expect(asAdmin.members, hasLength(2));
        expect(asMember.maxPermission, Permission.read);
        expect(asMember.id, team);
      });

      test('someone outside the team is refused', () async {
        final dio = fakeDio({
          '$base/teams/$team': _captured('${version}_team_read_forbidden'),
        });

        await expectLater(_port(dio, version).read(team), throwsA(_forbidden));
      });

      test('an external team is marked, its id never kept', () async {
        final dio = fakeDio({
          '$base/teams/$_external': _captured('${version}_team_external_read'),
        });

        final external = await _port(dio, version).read(_external);

        expect(external.isExternal, isTrue);
        expect(external.name, 'Fixture group (Keycloak)');
      });
    });

    group('$version create', () {
      test('sends name and description and reads the team back', () async {
        final dio = fakeDio({
          '$base/teams': _captured('${version}_team_create'),
          '$base/teams/$team': _captured('${version}_team_read'),
        });

        final created = await _port(dio, version).create(
          version == 'v2'
              ? const NewTeam(name: 'Fixture team two', isPublic: false)
              : const NewTeam(
                  name: 'Fixture team one',
                  description: '<p>First</p>',
                ),
        );

        expect(_calls(dio), ['$create $base/teams', 'GET $base/teams/$team']);
        expect(adapterOf(dio).decodedBodies.first, switch (version) {
          'v2' => {'name': 'Fixture team two', 'is_public': false},
          _ => {'name': 'Fixture team one', 'description': '<p>First</p>'},
        });
        expect(created.id, team);
        expect(created.members, hasLength(2));
        expect(created.maxPermission, Permission.admin);
      });

      test('a failed read back still returns the created team, with its '
          'creator as admin, so nobody creates it twice', () async {
        final dio = fakeDio({
          '$base/teams': _captured('${version}_team_create'),
          '$base/teams/$team': refused,
        });

        final created = await _port(
          dio,
          version,
        ).create(const NewTeam(name: 'Fixture team'));

        expect(_calls(dio), ['$create $base/teams', 'GET $base/teams/$team']);
        expect(created.id, team);
        expect(created.members, [const TeamMember(user: _owner, admin: true)]);
        expect(created.maxPermission, Permission.admin);
      });

      test('an empty name is refused', () async {
        final dio = fakeDio({
          '$base/teams': _captured('${version}_team_create_empty_name'),
        });

        await expectLater(
          _port(dio, version).create(const NewTeam(name: '')),
          throwsA(
            isA<ValidationFailed>().having(
              (f) => f.fieldErrors.keys,
              'fields',
              ['name'],
            ),
          ),
        );
      });
    });

    group('$version members', () {
      test('added as member by username', () async {
        final dio = fakeDio({
          '$base/teams/$team/members': _captured('${version}_team_member_add'),
        });

        await _port(dio, version).addMember(team, 'fixturemember');

        expect(_calls(dio), ['$create $base/teams/$team/members']);
        expect(adapterOf(dio).decodedBodies, [
          {'username': 'fixturemember', 'admin': false},
        ]);
      });

      test('someone in the team already, or nobody by that name', () async {
        for (final (fixture, matcher) in [
          ('${version}_team_member_add_again', _domainError(409, 6005)),
          ('${version}_team_member_add_unknown', _notFound(1005)),
        ]) {
          final dio = fakeDio({
            '$base/teams/$team/members': _captured(fixture),
          });

          await expectLater(
            _port(dio, version).addMember(team, 'fixturemember'),
            throwsA(matcher),
            reason: fixture,
          );
        }
      });

      test('the admin flag flips and comes back', () async {
        final url = '$base/teams/$team/members/fixturemember/admin';
        final dio = fakeDio({
          url: sequence([
            _captured('${version}_team_member_toggle'),
            _captured('${version}_team_member_toggle_back'),
          ]),
        });
        final port = _port(dio, version);

        expect(await port.toggleAdmin(team, 'fixturemember'), isTrue);
        expect(await port.toggleAdmin(team, 'fixturemember'), isFalse);
        expect(_calls(dio), ['POST $url', 'POST $url']);
        expect(adapterOf(dio).requestBodies, [null, null]);
      });

      test('toggling someone outside the team fails, as the team read '
          'after the empty answer shows', () async {
        final dio = fakeDio({
          '$base/teams/$team/members/fixtureguest/admin': _captured(
            '${version}_team_member_toggle_non_member',
          ),
          '$base/teams/$team': _captured('${version}_team_read'),
        });

        await expectLater(
          _port(dio, version).toggleAdmin(team, 'fixtureguest'),
          throwsA(isA<TeamMemberMissing>()),
        );
        expect(_calls(dio), [
          'POST $base/teams/$team/members/fixtureguest/admin',
          'GET $base/teams/$team',
        ]);
      });

      test('an answer without the membership, as from servers that do not '
          'carry the stored row back, is settled by the team read', () async {
        final read = fixtureJson('sharing/${version}_team_read_2.7.0.json');
        final body =
            jsonDecode(read['body']! as String) as Map<String, Object?>;
        // The read after the toggle: the member is admin now.
        final members = [
          for (final member in body['members']! as List<Object?>)
            if (member case {'username': 'fixturemember'})
              {...member as Map<String, Object?>, 'admin': true}
            else
              member,
        ];
        final dio = fakeDio({
          '$base/teams/$team/members/fixturemember/admin': json({
            'id': 0,
            'username': 'fixturemember',
            'admin': false,
            'created': '0001-01-01T00:00:00Z',
          }),
          '$base/teams/$team': json({...body, 'members': members}),
        });

        expect(
          await _port(dio, version).toggleAdmin(team, 'fixturemember'),
          isTrue,
        );
      });

      test('removed by username', () async {
        final url = '$base/teams/$team/members/fixturemember';
        final dio = fakeDio({url: _captured('${version}_team_member_remove')});

        await _port(dio, version).removeMember(team, 'fixturemember');

        expect(_calls(dio), ['DELETE $url']);
      });

      test('the last member, nobody by that name, an external team', () async {
        for (final (path, fixture, matcher) in [
          (
            '/teams/$team/members/fixtureowner',
            '${version}_team_member_remove_last',
            _domainError(400, 6006),
          ),
          (
            '/teams/$team/members/nobody-at-all',
            '${version}_team_member_remove_unknown',
            _notFound(1005),
          ),
          (
            '/teams/$_external/members/fixturemember',
            '${version}_team_member_remove_external',
            _domainError(412, 6010),
          ),
        ]) {
          final segments = path.split('/');
          final dio = fakeDio({'$base$path': _captured(fixture)});

          await expectLater(
            _port(
              dio,
              version,
            ).removeMember(int.parse(segments[2]), segments.last),
            throwsA(matcher),
            reason: fixture,
          );
        }
      });

      test('a username is one path segment', () async {
        final url = '$base/teams/$team/members/a%20b%2Fc';
        final dio = fakeDio({url: _captured('${version}_team_member_remove')});

        await _port(dio, version).removeMember(team, 'a b/c');

        expect(_calls(dio), ['DELETE $url']);
      });
    });

    test('$version delete', () async {
      final dio = fakeDio({
        '$base/teams/$team': _captured('${version}_team_delete'),
      });

      await _port(dio, version).delete(team);

      expect(_calls(dio), ['DELETE $base/teams/$team']);
    });

    test('$version empty changes are a read', () async {
      final dio = fakeDio({
        '$base/teams/$team': _captured('${version}_team_read'),
      });

      final read = await _port(dio, version).update(team, const TeamChanges());

      expect(_calls(dio), ['GET $base/teams/$team']);
      expect(read.maxPermission, Permission.admin);
    });
  }

  group('v2 update', () {
    test('a merge-patch of the changed fields', () async {
      final dio = fakeDio({
        '$_v2/teams/$_teamTwo': _captured('v2_team_update'),
      });

      final updated = await _port(dio, 'v2').update(
        _teamTwo,
        const TeamChanges(
          name: 'Fixture team renamed',
          description: '<p>Second</p>',
        ),
      );

      expect(_calls(dio), ['PATCH $_v2/teams/$_teamTwo']);
      expect(
        adapterOf(dio).requests.single.headers['content-type'],
        'application/merge-patch+json',
      );
      expect(adapterOf(dio).decodedBodies, [
        {'name': 'Fixture team renamed', 'description': '<p>Second</p>'},
      ]);
      expect(updated.name, 'Fixture team renamed');
      expect(updated.description, '<p>Second</p>');
      expect(updated.members, hasLength(2));
    });

    test('a cleared description is sent as an empty paragraph', () async {
      final dio = fakeDio({
        '$_v2/teams/$_teamTwo': _captured('v2_team_update_clear_description'),
      });

      final updated = await _port(
        dio,
        'v2',
      ).update(_teamTwo, const TeamChanges(description: ''));

      expect(adapterOf(dio).decodedBodies, [
        {'description': '<p></p>'},
      ]);
      expect(updated.description, '<p></p>');
    });

    test('a member is refused', () async {
      final dio = fakeDio({
        '$_v2/teams/$_teamTwo': _captured('v2_team_update_forbidden'),
      });

      await expectLater(
        _port(dio, 'v2').update(_teamTwo, const TeamChanges(name: 'Hijacked')),
        throwsA(_forbidden),
      );
    });

    test('a member cannot delete the team', () async {
      final dio = fakeDio({
        '$_v2/teams/$_teamTwo': _captured('v2_team_delete_forbidden'),
      });

      await expectLater(_port(dio, 'v2').delete(_teamTwo), throwsA(_forbidden));
    });
  });

  group('v1 update', () {
    test('all three fields from a fresh read, the changes on top', () async {
      final dio = fakeDio({
        '$_v1/teams/$_teamOne': _byMethod({
          'GET': _captured('v1_team_read'),
          'POST': _captured('v1_team_update'),
        }),
      });

      final updated = await _port(dio, 'v1').update(
        _teamOne,
        const TeamChanges(description: '<p>First, edited</p>'),
      );

      expect(_calls(dio), [
        'GET $_v1/teams/$_teamOne',
        'POST $_v1/teams/$_teamOne',
      ]);
      expect(adapterOf(dio).decodedBodies.last, {
        'name': 'Fixture team one',
        'description': '<p>First, edited</p>',
        'is_public': false,
      });
      expect(updated.description, '<p>First, edited</p>');
      expect(updated.members, hasLength(2));
    });

    test('never sends the external id back', () async {
      final dio = fakeDio({
        '$_v1/teams/$_external': _byMethod({
          'GET': _captured('v1_team_external_read'),
          'POST': _captured('v1_team_update'),
        }),
      });

      await _port(
        dio,
        'v1',
      ).update(_external, const TeamChanges(isPublic: true));

      expect(adapterOf(dio).decodedBodies.last, {
        'name': 'Fixture group (Keycloak)',
        'description': '',
        'is_public': true,
      });
    });

    test('a member is refused', () async {
      final dio = fakeDio({
        '$_v1/teams/$_teamOne': _byMethod({
          'GET': _captured('v1_team_read_member'),
          'POST': _captured('v1_team_update_forbidden'),
        }),
      });

      await expectLater(
        _port(dio, 'v1').update(_teamOne, const TeamChanges(name: 'Hijacked')),
        throwsA(_forbidden),
      );
    });
  });
}
