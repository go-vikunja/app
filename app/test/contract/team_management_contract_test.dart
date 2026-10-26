@Tags(['contract'])
@Timeout(Duration(minutes: 10))
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/repositories/local/local_user_repository.dart';
import 'package:vikunja_mobile/core/repositories/online/online_team_repository.dart';

import '../helpers/recording_sync_engine.dart';
import '../helpers/test_database.dart';
import 'helpers.dart';

Future<void> _pace() => Future<void>.delayed(const Duration(milliseconds: 500));

// Two users: the team's creator and a colleague found by the user search.
void main() {
  group(
    'team management against the local Docker server',
    skip: contractSkip,
    () {
      late Dio dio;
      late ServerConnection connection;
      late TestUser alice;
      late TestUser ben;

      setUpAll(() async {
        dio = contractDio();
        connection = await DioServerConnector(dio)
            .connect('http://localhost:$contractServerPort');
        alice = await registerAndLogin(dio, connection);
        ben = await registerAndLogin(dio, connection);
      });

      tearDownAll(() => dio.close(force: true));

      for (final apiVersion in ApiVersion.values) {
        test('a team made, changed, staffed, left and deleted over '
            '${apiVersion.pathSegment}', () async {
          final name = apiVersion.pathSegment;
          final only = onlyApiVersion(connection, apiVersion);
          Dio authenticatedAs(TestUser user) => createAuthenticatedDio(
            base: dio,
            connection: only,
            tokens: StaticJwt(user.jwt),
          );
          final aliceSync = RecordingSyncEngine();
          final aliceDio = authenticatedAs(alice);
          final alicePort = createTeamsPort(dio: aliceDio, connection: only);
          final teams = OnlineTeamRepository(
            port: alicePort,
            sync: aliceSync,
            currentUser: () => (id: alice.id, username: alice.username),
          );
          final benSync = RecordingSyncEngine();
          final benTeams = OnlineTeamRepository(
            port: createTeamsPort(dio: authenticatedAs(ben), connection: only),
            sync: benSync,
            currentUser: () => (id: ben.id, username: ben.username),
          );
          final db = testDatabase();
          addTearDown(db.close);
          final users = LocalUserRepository(
            db,
            createReadClient(dio: aliceDio, connection: only),
          );

          final created = await teams.create(NewTeam(name: 'Crew $name'));
          await _pace();
          expect(created.name, 'Crew $name');
          expect(created.members.single.user.id, alice.id);
          expect(created.members.single.admin, isTrue);
          final id = created.id;
          expect((await teams.read(id)).maxPermission, Permission.admin);
          expect((await teams.list()).map((team) => team.id), contains(id));

          final renamed = await teams.update(
            id,
            TeamChanges(
              name: 'Crew $name renamed',
              description: '<p>We build things</p>',
              isPublic: true,
            ),
          );
          await _pace();
          expect(renamed.name, 'Crew $name renamed');
          expect(renamed.description, '<p>We build things</p>');
          expect(renamed.isPublic, isTrue);
          final described = await teams.update(
            id,
            const TeamChanges(name: 'Crew again'),
          );
          await _pace();
          expect(described.isPublic, isTrue, reason: 'v1 must send it back');
          expect(described.description, '<p>We build things</p>');
          final cleared = await teams.update(
            id,
            const TeamChanges(description: ''),
          );
          await _pace();
          expect(
            cleared.description,
            '<p></p>',
            reason: 'the server keeps the old text for an empty one',
          );

          final found = await users.search(ben.username.toUpperCase());
          expect(found.map((user) => user.username), [ben.username]);
          expect(
            await users.search(ben.username.substring(0, 6)),
            isEmpty,
            reason: 'a part of a username finds nobody',
          );

          await teams.addMember(id, found.single.username);
          await _pace();
          var team = await teams.read(id);
          expect(team.members.map((member) => (member.user.id, member.admin)), [
            (alice.id, true),
            (ben.id, false),
          ]);
          await expectLater(
            teams.addMember(id, ben.username),
            throwsA(isA<DomainError>().having((f) => f.code, 'code', 6005)),
          );
          await expectLater(
            teams.addMember(id, 'nobody-${alice.username}'),
            throwsA(isA<NotFound>().having((f) => f.code, 'code', 1005)),
          );
          await expectLater(
            benTeams.update(id, const TeamChanges(name: 'Mine')),
            throwsA(isA<Forbidden>()),
          );
          expect(
            TeamGuards.of(team, currentUserId: alice.id).leave,
            TeamLeaveRule.makeSomeoneAdminFirst,
          );
          await expectLater(teams.leave(id), throwsArgumentError);

          expect(await teams.toggleAdmin(id, ben.username), isTrue);
          await _pace();
          expect((await teams.read(id)).members.map((member) => member.admin), [
            true,
            true,
          ]);
          expect(await teams.toggleAdmin(id, ben.username), isFalse);
          await _pace();
          await teams.removeMember(id, ben.username);
          await _pace();
          team = await teams.read(id);
          expect(team.members.map((member) => member.user.id), [alice.id]);
          await expectLater(
            teams.toggleAdmin(id, ben.username),
            throwsA(isA<TeamMemberMissing>()),
          );
          await expectLater(teams.leave(id), throwsArgumentError);
          await expectLater(
            alicePort.removeMember(id, alice.username),
            throwsA(isA<DomainError>().having((f) => f.code, 'code', 6006)),
          );
          await _pace();

          await teams.addMember(id, ben.username, admin: true);
          await _pace();
          await teams.leave(id);
          await _pace();
          expect(aliceSync.refreshAfterWriteCalls, 1);
          await expectLater(teams.read(id), throwsA(isA<Forbidden>()));
          final benSees = await benTeams.read(id);
          expect(benSees.members.map((member) => member.user.id), [ben.id]);
          expect(benSees.maxPermission, Permission.admin);

          await benTeams.delete(id);
          await _pace();
          expect(benSync.refreshAfterWriteCalls, 1);
          await expectLater(benTeams.read(id), throwsA(isA<Forbidden>()));
        });
      }
    },
  );
}
