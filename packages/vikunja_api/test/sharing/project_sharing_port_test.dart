import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';
import '../helpers/server_connection.dart';

// The answers were captured by tool/capture_sharing_fixtures.dart: the owner
// (145) shared project 418 with the member (146, read, then write) and the
// guest (147, write, then read), with team one (9, write, then read) and
// team two (10, read, then write), both of which have the member but not the
// guest, and by three links (18 read, 19 write with a password, 20 admin).
const _v1 = '$testServerRoot/api/v1';
const _v2 = '$testServerRoot/api/v2';
const _project = 418;
const _owner = User(id: 145, username: 'fixtureowner');
const _member = User(id: 146, username: 'fixturemember');
const _guest = User(id: 147, username: 'fixtureguest');
final String _scrubbedHash = 'x' * 40;

ProjectSharingPort _port(Dio dio, String version, {int perPage = 50}) =>
    createProjectSharingPort(
      dio: dio,
      connection: testConnection(
        hasV2: version == 'v2',
        maxItemsPerPage: perPage,
      ),
    );

FakeRoute _captured(String name) => capturedFixture('sharing/${name}_2.7.0');

List<String> _calls(Dio dio) => [
  for (final request in adapterOf(dio).requests)
    '${request.method} ${request.uri}',
];

Matcher _domainError(int status, int code) => isA<DomainError>()
    .having((f) => f.statusCode, 'status', status)
    .having((f) => f.code, 'code', code);

Matcher _notFound(int code) =>
    isA<NotFound>().having((f) => f.code, 'code', code);

Matcher _forbidden([int? code]) =>
    isA<Forbidden>().having((f) => f.code, 'code', code);

void main() {
  for (final version in ['v1', 'v2']) {
    final base = version == 'v2' ? _v2 : _v1;
    final shares = '$base/projects/$_project';
    final create = version == 'v2' ? 'POST' : 'PUT';
    final change = version == 'v2' ? 'PUT' : 'POST';

    group('$version user shares', () {
      test('listed with their permissions', () async {
        final dio = fakeDio({
          '$shares/users?page=1&per_page=50': _captured(
            '${version}_project_users',
          ),
        });

        final users = await _port(dio, version).listUsers(_project);

        expect(users, const [
          ProjectUserShare(user: _member, permission: Permission.write),
          ProjectUserShare(user: _guest, permission: Permission.read),
        ]);
      });

      test('page after page', () async {
        final dio = fakeDio({
          for (final page in [1, 2])
            '$shares/users?page=$page&per_page=1': _captured(
              '${version}_project_users_page_$page',
            ),
        });

        final users = await _port(dio, version, perPage: 1).listUsers(_project);

        expect(users.map((share) => share.user.id), [_member.id, _guest.id]);
        expect(adapterOf(dio).requests, hasLength(2));
      });

      test('added with only the username and the permission', () async {
        final dio = fakeDio({
          '$shares/users': _captured('${version}_project_user_add'),
        });

        await _port(dio, version).addUser(
          _project,
          version == 'v2' ? 'fixtureguest' : 'fixturemember',
          version == 'v2' ? Permission.write : Permission.read,
        );

        expect(_calls(dio), ['$create $shares/users']);
        expect(adapterOf(dio).decodedBodies.single, switch (version) {
          'v2' => {'username': 'fixtureguest', 'permission': 1},
          _ => {'username': 'fixturemember', 'permission': 0},
        });
      });

      test('refusals of an add', () async {
        for (final (fixture, matcher) in [
          ('${version}_project_user_add_again', _domainError(409, 7002)),
          ('${version}_project_user_add_owner', _domainError(409, 7002)),
          ('${version}_project_user_add_unknown', _notFound(1005)),
          (
            '${version}_project_user_add_bad_permission',
            version == 'v2'
                ? isA<ValidationFailed>().having(
                    (f) => f.fieldErrors.keys,
                    'fields',
                    ['permission'],
                  )
                : _domainError(400, 2004),
          ),
        ]) {
          final dio = fakeDio({'$shares/users': _captured(fixture)});

          await expectLater(
            _port(dio, version).addUser(_project, 'x', Permission.read),
            throwsA(matcher),
            reason: fixture,
          );
        }
      });

      test('a permission changed by username', () async {
        final username = version == 'v2' ? 'fixtureguest' : 'fixturemember';
        final dio = fakeDio({
          '$shares/users/$username': _captured(
            '${version}_project_user_update',
          ),
        });

        await _port(dio, version).setUserPermission(
          _project,
          username,
          version == 'v2' ? Permission.read : Permission.write,
        );

        expect(_calls(dio), ['$change $shares/users/$username']);
        expect(adapterOf(dio).decodedBodies, [
          {'permission': version == 'v2' ? 0 : 1},
        ]);
      });

      test('only an admin changes a share', () async {
        final dio = fakeDio({
          '$shares/users/fixtureguest': _captured(
            '${version}_project_user_update_forbidden',
          ),
        });

        await expectLater(
          _port(
            dio,
            version,
          ).setUserPermission(_project, 'fixtureguest', Permission.admin),
          throwsA(_forbidden()),
        );
      });

      test('removed by username', () async {
        final username = version == 'v2' ? 'fixtureguest' : 'fixturemember';
        final dio = fakeDio({
          '$shares/users/$username': _captured(
            '${version}_project_user_remove',
          ),
        });

        await _port(dio, version).removeUser(_project, username);

        expect(_calls(dio), ['DELETE $shares/users/$username']);
      });

      test('removing someone without a share, or nobody', () async {
        for (final (username, fixture, matcher) in [
          (
            'fixtureguest',
            '${version}_project_user_remove_none',
            _forbidden(7003),
          ),
          (
            'nobody-at-all',
            '${version}_project_user_remove_unknown',
            _notFound(1005),
          ),
        ]) {
          final dio = fakeDio({'$shares/users/$username': _captured(fixture)});

          await expectLater(
            _port(dio, version).removeUser(_project, username),
            throwsA(matcher),
            reason: fixture,
          );
        }
      });
    });

    group('$version team shares', () {
      test('listed with names and member counts', () async {
        final dio = fakeDio({
          '$shares/teams?page=1&per_page=50': _captured(
            '${version}_project_teams',
          ),
        });

        final teams = await _port(dio, version).listTeams(_project);

        expect(teams, const [
          ProjectTeamShare(
            teamId: 9,
            teamName: 'Fixture team one',
            memberCount: 2,
            permission: Permission.read,
          ),
          ProjectTeamShare(
            teamId: 10,
            teamName: 'Fixture team renamed',
            memberCount: 2,
            permission: Permission.write,
          ),
        ]);
      });

      test('teams the reader is not in come without a name', () async {
        final dio = fakeDio({
          '$shares/teams?page=1&per_page=50': _captured(
            '${version}_project_teams_hidden',
          ),
        });

        final teams = await _port(dio, version).listTeams(_project);

        expect(teams, const [
          ProjectTeamShare(teamId: 9, permission: Permission.read),
          ProjectTeamShare(teamId: 10, permission: Permission.write),
        ]);
        expect(teams.every((share) => share.isHidden), isTrue);
      });

      test('added by team id', () async {
        final team = version == 'v2' ? 10 : 9;
        final dio = fakeDio({
          '$shares/teams': _captured('${version}_project_team_add'),
        });

        await _port(dio, version).addTeam(
          _project,
          team,
          version == 'v2' ? Permission.read : Permission.write,
        );

        expect(_calls(dio), ['$create $shares/teams']);
        expect(adapterOf(dio).decodedBodies, [
          {'team_id': team, 'permission': version == 'v2' ? 0 : 1},
        ]);
      });

      test('refusals of an add', () async {
        for (final (fixture, matcher) in [
          ('${version}_project_team_add_again', _domainError(409, 6004)),
          ('${version}_project_team_add_unknown', _notFound(6002)),
        ]) {
          final dio = fakeDio({'$shares/teams': _captured(fixture)});

          await expectLater(
            _port(dio, version).addTeam(_project, 9, Permission.read),
            throwsA(matcher),
            reason: fixture,
          );
        }
      });

      test('a permission changed by team id', () async {
        final team = version == 'v2' ? 10 : 9;
        final dio = fakeDio({
          '$shares/teams/$team': _captured('${version}_project_team_update'),
        });

        await _port(dio, version).setTeamPermission(
          _project,
          team,
          version == 'v2' ? Permission.write : Permission.read,
        );

        expect(_calls(dio), ['$change $shares/teams/$team']);
        expect(adapterOf(dio).decodedBodies, [
          {'permission': version == 'v2' ? 1 : 0},
        ]);
      });

      test('removed, without a share, an unknown team', () async {
        final team = version == 'v2' ? 10 : 9;
        final removed = fakeDio({
          '$shares/teams/$team': _captured('${version}_project_team_remove'),
        });

        await _port(removed, version).removeTeam(_project, team);

        expect(_calls(removed), ['DELETE $shares/teams/$team']);
        for (final (id, fixture, matcher) in [
          (10, '${version}_project_team_remove_none', _forbidden(6007)),
          (99999999, '${version}_project_team_remove_unknown', _notFound(6002)),
        ]) {
          final dio = fakeDio({'$shares/teams/$id': _captured(fixture)});

          await expectLater(
            _port(dio, version).removeTeam(_project, id),
            throwsA(matcher),
            reason: fixture,
          );
        }
      });
    });

    group('$version link shares', () {
      test("listed with the hash, never anyone's email", () async {
        final dio = fakeDio({
          '$shares/shares?page=1&per_page=50': _captured(
            '${version}_link_shares',
          ),
        });

        final links = await _port(dio, version).listLinkShares(_project);

        expect(links.map((link) => link.id), [18, 19, 20]);
        expect(links.map((link) => link.permission), [
          Permission.read,
          Permission.write,
          Permission.admin,
        ]);
        expect(links.map((link) => link.name), [
          'Fixture read link',
          'Fixture team link',
          '',
        ]);
        expect(links.map((link) => link.passwordProtected), [
          false,
          true,
          false,
        ]);
        expect(links.every((link) => link.hash == _scrubbedHash), isTrue);
        expect(links.first.sharedBy, _owner);
        expect(links.first.sharedBy?.email, isNull);
        expect(links.first.created, DateTime.utc(2026, 10, 26, 11, 17, 30));
      });

      test('page after page', () async {
        final dio = fakeDio({
          for (final page in [1, 2])
            '$shares/shares?page=$page&per_page=2': _captured(
              '${version}_link_shares_page_$page',
            ),
        });

        final links = await _port(
          dio,
          version,
          perPage: 2,
        ).listLinkShares(_project);

        expect(links.map((link) => link.id), [18, 19, 20]);
      });

      test('listed only for admins', () async {
        final dio = fakeDio({
          '$shares/shares?page=1&per_page=50': _captured(
            '${version}_link_shares_forbidden',
          ),
        });

        await expectLater(
          _port(dio, version).listLinkShares(_project),
          throwsA(_forbidden(1)),
        );
      });

      test('a server with link sharing off has no route', () async {
        final dio = fakeDio({
          '$shares/shares?page=1&per_page=50': json({
            'message': 'Not Found',
          }, status: 404),
        });

        await expectLater(
          _port(dio, version).listLinkShares(_project),
          throwsA(
            isA<NotFound>().having((f) => f.routeAbsent, 'routeAbsent', true),
          ),
        );
      });

      test('deleted, then gone', () async {
        final id = version == 'v2' ? 19 : 18;
        final deleted = fakeDio({
          '$shares/shares/$id': _captured('${version}_link_share_delete'),
        });
        final gone = fakeDio({
          '$shares/shares/19': _captured('${version}_link_share_delete_gone'),
        });

        await _port(deleted, version).deleteLinkShare(_project, id);

        expect(_calls(deleted), ['DELETE $shares/shares/$id']);
        await expectLater(
          _port(gone, version).deleteLinkShare(_project, 19),
          throwsA(_notFound(3006)),
        );
      });
    });
  }

  test('v1 creates a link share with a name and gets it back', () async {
    final dio = fakeDio({
      '$_v1/projects/$_project/shares': _captured('v1_link_share_create'),
    });

    final link = await _port(dio, 'v1').createLinkShare(
      _project,
      const NewLinkShare(
        permission: Permission.read,
        name: 'Fixture read link',
      ),
    );

    expect(_calls(dio), ['PUT $_v1/projects/$_project/shares']);
    expect(adapterOf(dio).decodedBodies, [
      {'permission': 0, 'name': 'Fixture read link'},
    ]);
    expect(link.id, 18);
    expect(link.hash, _scrubbedHash);
    expect(link.passwordProtected, isFalse);
    expect(link.sharedBy, _owner);
  });

  test('v2 creates a link share with a password', () async {
    final dio = fakeDio({
      '$_v2/projects/$_project/shares': _captured('v2_link_share_create'),
    });

    final link = await _port(dio, 'v2').createLinkShare(
      _project,
      const NewLinkShare(
        permission: Permission.write,
        name: 'Fixture team link',
        password: 'correct horse',
      ),
    );

    expect(_calls(dio), ['POST $_v2/projects/$_project/shares']);
    expect(adapterOf(dio).decodedBodies, [
      {
        'permission': 1,
        'name': 'Fixture team link',
        'password': 'correct horse',
      },
    ]);
    expect(link.id, 19);
    expect(link.passwordProtected, isTrue);
    expect(link.permission, Permission.write);
  });

  test(
    'a link share without name or password sends only the permission',
    () async {
      final dio = fakeDio({
        '$_v2/projects/$_project/shares': _captured('v2_link_share_create'),
      });

      await _port(dio, 'v2').createLinkShare(
        _project,
        const NewLinkShare(
          permission: Permission.admin,
          name: '',
          password: '',
        ),
      );

      expect(adapterOf(dio).decodedBodies, [
        {'permission': 2},
      ]);
    },
  );

  test('a permission the server does not know is refused', () async {
    for (final (version, matcher) in [
      ('v1', _domainError(400, 2004)),
      ('v2', isA<ValidationFailed>()),
    ]) {
      final base = version == 'v2' ? _v2 : _v1;
      final dio = fakeDio({
        '$base/projects/$_project/shares': _captured(
          '${version}_link_share_create_bad_permission',
        ),
      });

      await expectLater(
        _port(dio, version).createLinkShare(
          _project,
          const NewLinkShare(permission: Permission.read),
        ),
        throwsA(matcher),
        reason: version,
      );
    }
  });
}
