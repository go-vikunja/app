import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/online/online_project_sharing_repository.dart';
import 'package:vikunja_mobile/core/repositories/online/online_team_repository.dart';

import '../../helpers/recording_sync_engine.dart';

const _me = User(id: 1, username: 'Me');
const _ben = User(id: 2, username: 'ben');
const _cleo = User(id: 3, username: 'cleo');

Team _team({List<TeamMember> members = const [], bool external = false}) =>
    Team(id: 5, name: 'Crew', isExternal: external, members: members);

/// Answers [read] with [team] and records every call; [failure] fails the
/// next one.
final class _TeamsPort implements TeamsPort {
  Team team = _team();
  final List<String> calls = [];
  Exception? failure;

  Future<void> _call(String call) async {
    calls.add(call);
    if (failure case final failure?) {
      this.failure = null;
      throw failure;
    }
  }

  @override
  Future<List<Team>> list({String? query, bool includePublic = false}) async {
    await _call('list $query $includePublic');
    return [team];
  }

  @override
  Future<Team> read(int id) async {
    await _call('read $id');
    return team;
  }

  @override
  Future<Team> create(NewTeam team) async {
    await _call('create');
    return this.team;
  }

  @override
  Future<Team> update(int id, TeamChanges changes) async {
    await _call('update $id $changes');
    return team;
  }

  @override
  Future<void> delete(int id) => _call('delete $id');

  @override
  Future<void> addMember(int teamId, String username, {bool admin = false}) =>
      _call('addMember $teamId $username $admin');

  @override
  Future<void> removeMember(int teamId, String username) =>
      _call('removeMember $teamId $username');

  @override
  Future<bool> toggleAdmin(int teamId, String username) async {
    await _call('toggleAdmin $teamId $username');
    return true;
  }
}

final class _SharingPort implements ProjectSharingPort {
  final List<String> calls = [];
  Exception? failure;

  Future<void> _call(String call) async {
    calls.add(call);
    if (failure case final failure?) throw failure;
  }

  @override
  Future<List<ProjectUserShare>> listUsers(int projectId) async {
    await _call('listUsers $projectId');
    return const [ProjectUserShare(user: _ben, permission: Permission.write)];
  }

  @override
  Future<void> addUser(int projectId, String username, Permission permission) =>
      _call('addUser $projectId $username ${permission.name}');

  @override
  Future<void> setUserPermission(
    int projectId,
    String username,
    Permission permission,
  ) => _call('setUserPermission $projectId $username ${permission.name}');

  @override
  Future<void> removeUser(int projectId, String username) =>
      _call('removeUser $projectId $username');

  @override
  Future<List<ProjectTeamShare>> listTeams(int projectId) async {
    await _call('listTeams $projectId');
    return const [ProjectTeamShare(teamId: 9, permission: Permission.read)];
  }

  @override
  Future<void> addTeam(int projectId, int teamId, Permission permission) =>
      _call('addTeam $projectId $teamId ${permission.name}');

  @override
  Future<void> setTeamPermission(
    int projectId,
    int teamId,
    Permission permission,
  ) => _call('setTeamPermission $projectId $teamId ${permission.name}');

  @override
  Future<void> removeTeam(int projectId, int teamId) =>
      _call('removeTeam $projectId $teamId');

  @override
  Future<List<LinkShare>> listLinkShares(int projectId) async {
    await _call('listLinkShares $projectId');
    return const [];
  }

  @override
  Future<LinkShare> createLinkShare(int projectId, NewLinkShare share) async {
    await _call('createLinkShare $projectId $share');
    return LinkShare(id: 4, hash: 'x' * 40, permission: share.permission);
  }

  @override
  Future<void> deleteLinkShare(int projectId, int shareId) =>
      _call('deleteLinkShare $projectId $shareId');
}

void main() {
  group('OnlineTeamRepository', () {
    late _TeamsPort port;
    late RecordingSyncEngine sync;
    late OnlineTeamRepository repository;
    var signedIn = true;

    setUp(() {
      port = _TeamsPort();
      sync = RecordingSyncEngine();
      signedIn = true;
      repository = OnlineTeamRepository(
        port: port,
        sync: sync,
        currentUser: () =>
            signedIn ? (id: _me.id, username: _me.username) : null,
      );
    });

    test('reads go to the server', () async {
      expect(await repository.list(query: 'cr', includePublic: true), [
        port.team,
      ]);
      expect(await repository.read(5), port.team);
      expect(port.calls, ['list cr true', 'read 5']);
      expect(sync.refreshAfterWriteCalls, 0);
    });

    test('a blank or too long name is refused before any request', () async {
      for (final name in ['', '  ', 'x' * 251]) {
        await expectLater(
          repository.create(NewTeam(name: name)),
          throwsArgumentError,
        );
        await expectLater(
          repository.update(5, TeamChanges(name: name)),
          throwsArgumentError,
        );
      }
      await repository.create(NewTeam(name: 'ü' * 250));
      await repository.update(5, const TeamChanges(isPublic: true));

      expect(port.calls, ['create', 'update 5 TeamChanges(isPublic: true)']);
    });

    test('member changes go to the server, never on the own row', () async {
      await repository.addMember(5, 'ben', admin: true);
      expect(await repository.toggleAdmin(5, 'ben'), isTrue);
      await repository.removeMember(5, 'ben');
      await expectLater(repository.removeMember(5, 'me'), throwsArgumentError);
      await expectLater(repository.toggleAdmin(5, 'ME'), throwsArgumentError);

      expect(port.calls, [
        'addMember 5 ben true',
        'toggleAdmin 5 ben',
        'removeMember 5 ben',
      ]);
      expect(sync.refreshAfterWriteCalls, 0);
    });

    test('a delete syncs quietly after it', () async {
      await repository.delete(5);

      expect(port.calls, ['delete 5']);
      expect(sync.refreshAfterWriteCalls, 1);
    });

    test('a failed delete does not sync', () async {
      port.failure = const Forbidden();

      await expectLater(repository.delete(5), throwsA(isA<Forbidden>()));

      expect(sync.refreshAfterWriteCalls, 0);
    });

    test('leaving reads the team, removes the user and syncs '
        'quietly', () async {
      port.team = _team(
        members: const [
          TeamMember(user: _me, admin: true),
          TeamMember(user: _ben, admin: true),
        ],
      );

      await repository.leave(5);

      expect(port.calls, ['read 5', 'removeMember 5 Me']);
      expect(sync.refreshAfterWriteCalls, 1);
    });

    test('a quiet sync that fails stays quiet', () async {
      port.team = _team(
        members: const [
          TeamMember(user: _me),
          TeamMember(user: _ben, admin: true),
        ],
      );
      sync.error = const NetworkFailure(NetworkProblem.unreachable);

      await repository.leave(5);
      await pumpEventQueue();

      expect(sync.refreshAfterWriteCalls, 1);
    });

    for (final (name, members, external) in [
      (
        'the only admin with others in the team',
        const [TeamMember(user: _me, admin: true), TeamMember(user: _ben)],
        false,
      ),
      ('the last member', const [TeamMember(user: _me, admin: true)], false),
      (
        'a member of an external team',
        const [TeamMember(user: _me), TeamMember(user: _cleo, admin: true)],
        true,
      ),
      ('not a member', const [TeamMember(user: _ben, admin: true)], false),
    ]) {
      test('$name cannot leave', () async {
        port.team = _team(members: members, external: external);

        await expectLater(repository.leave(5), throwsArgumentError);

        expect(port.calls, ['read 5']);
        expect(sync.refreshAfterWriteCalls, 0);
      });
    }

    test('signed out, leaving is a session failure', () async {
      signedIn = false;

      await expectLater(repository.leave(5), throwsA(isA<SessionEnded>()));
      expect(port.calls, isEmpty);
    });
  });

  group('OnlineProjectSharingRepository', () {
    late _SharingPort port;
    late RecordingSyncEngine sync;
    late OnlineProjectSharingRepository repository;

    setUp(() {
      port = _SharingPort();
      sync = RecordingSyncEngine();
      repository = OnlineProjectSharingRepository(
        port: port,
        sync: sync,
        currentUsername: () => 'Me',
      );
    });

    test('lists and adds go to the server without a sync', () async {
      expect(await repository.userShares(7), hasLength(1));
      expect(await repository.teamShares(7), hasLength(1));
      expect(await repository.linkShares(7), isEmpty);
      await repository.shareWithUser(7, 'ben', Permission.read);
      await repository.shareWithTeam(7, 9, Permission.write);
      final link = await repository.createLinkShare(
        7,
        const NewLinkShare(permission: Permission.read, password: 'secret'),
      );
      await repository.deleteLinkShare(7, link.id);

      expect(port.calls, [
        'listUsers 7',
        'listTeams 7',
        'listLinkShares 7',
        'addUser 7 ben read',
        'addTeam 7 9 write',
        'createLinkShare 7 NewLinkShare(read, password: true)',
        'deleteLinkShare 7 4',
      ]);
      expect(sync.refreshAfterWriteCalls, 0);
    });

    test("another user's share changes nothing here", () async {
      await repository.setUserPermission(7, 'ben', Permission.admin);
      await repository.removeUserShare(7, 'ben');

      expect(sync.refreshAfterWriteCalls, 0);
    });

    test('a change to the own share syncs quietly after it', () async {
      await repository.setUserPermission(7, 'me', Permission.read);
      await repository.removeUserShare(7, 'Me');

      expect(sync.refreshAfterWriteCalls, 2);
    });

    test('a team share change or removal syncs quietly after it', () async {
      await repository.setTeamPermission(7, 9, Permission.read);
      await repository.removeTeamShare(7, 9);

      expect(port.calls, ['setTeamPermission 7 9 read', 'removeTeam 7 9']);
      expect(sync.refreshAfterWriteCalls, 2);
    });

    test('a failed change does not sync', () async {
      port.failure = const Forbidden(code: 7003);

      await expectLater(
        repository.removeUserShare(7, 'me'),
        throwsA(isA<Forbidden>()),
      );
      await expectLater(
        repository.removeTeamShare(7, 9),
        throwsA(isA<Forbidden>()),
      );

      expect(sync.refreshAfterWriteCalls, 0);
    });

    test('a link share gone already counts as deleted', () async {
      port.failure = const NotFound(code: 3006);

      await repository.deleteLinkShare(7, 4);
    });

    test('link sharing turned off on the server still fails', () async {
      port.failure = const NotFound();

      await expectLater(
        repository.deleteLinkShare(7, 4),
        throwsA(isA<NotFound>().having((f) => f.routeAbsent, 'absent', true)),
      );
    });
  });
}
