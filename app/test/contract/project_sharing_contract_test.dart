@Tags(['contract'])
@Timeout(Duration(minutes: 10))
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/repositories/online/online_project_sharing_repository.dart';
import 'package:vikunja_mobile/core/repositories/online/online_team_repository.dart';

import '../helpers/recording_sync_engine.dart';
import 'helpers.dart';

Future<void> _pace() => Future<void>.delayed(const Duration(milliseconds: 500));

// Two users: the project's owner and a colleague it is shared with.
void main() {
  group(
    'project sharing against the local Docker server',
    skip: contractSkip,
    () {
      late Dio dio;
      late ServerConnection connection;
      late TestUser owner;
      late TestUser colleague;

      setUpAll(() async {
        dio = contractDio();
        connection = await DioServerConnector(dio)
            .connect('http://localhost:$contractServerPort');
        owner = await registerAndLogin(dio, connection);
        colleague = await registerAndLogin(dio, connection);
      });

      tearDownAll(() => dio.close(force: true));

      for (final apiVersion in ApiVersion.values) {
        group('over ${apiVersion.pathSegment}', () {
          final name = apiVersion.pathSegment;
          late ServerConnection only;
          late RecordingSyncEngine ownerSync;
          late RecordingSyncEngine colleagueSync;
          late OnlineProjectSharingRepository sharing;
          late OnlineProjectSharingRepository colleagueSharing;
          late OnlineTeamRepository teams;
          late Seeder seeder;

          Dio authenticatedAs(TestUser user) => createAuthenticatedDio(
            base: dio,
            connection: only,
            tokens: StaticJwt(user.jwt),
          );

          setUp(() {
            only = onlyApiVersion(connection, apiVersion);
            seeder = Seeder(dio, connection, owner);
            ownerSync = RecordingSyncEngine();
            colleagueSync = RecordingSyncEngine();
            final ownerDio = authenticatedAs(owner);
            sharing = OnlineProjectSharingRepository(
              port: createProjectSharingPort(dio: ownerDio, connection: only),
              sync: ownerSync,
              currentUsername: () => owner.username,
            );
            colleagueSharing = OnlineProjectSharingRepository(
              port: createProjectSharingPort(
                dio: authenticatedAs(colleague),
                connection: only,
              ),
              sync: colleagueSync,
              currentUsername: () => colleague.username,
            );
            teams = OnlineTeamRepository(
              port: createTeamsPort(dio: ownerDio, connection: only),
              sync: ownerSync,
              currentUser: () => (id: owner.id, username: owner.username),
            );
          });

          test("people are added, changed and removed, with the server's "
              'refusals', () async {
            final projectId = await seeder.create('/projects', {
              'title': 'People over $name',
            });
            await _pace();
            expect(await sharing.userShares(projectId), isEmpty);

            await sharing.shareWithUser(
              projectId,
              colleague.username,
              Permission.read,
            );
            await _pace();
            final shares = await sharing.userShares(projectId);
            expect(shares.single.user.id, colleague.id);
            expect(shares.single.permission, Permission.read);
            expect(shares.single.user.email, isNull);

            await expectLater(
              sharing.shareWithUser(
                projectId,
                colleague.username,
                Permission.write,
              ),
              throwsA(isA<DomainError>().having((f) => f.code, 'code', 7002)),
            );
            await expectLater(
              sharing.shareWithUser(projectId, owner.username, Permission.read),
              throwsA(isA<DomainError>().having((f) => f.code, 'code', 7002)),
              reason: 'the owner',
            );
            await expectLater(
              sharing.shareWithUser(
                projectId,
                'nobody-${owner.username}',
                Permission.read,
              ),
              throwsA(isA<NotFound>().having((f) => f.code, 'code', 1005)),
            );
            await expectLater(
              colleagueSharing.shareWithUser(
                projectId,
                owner.username,
                Permission.read,
              ),
              throwsA(isA<Forbidden>()),
              reason: 'only admins share',
            );

            await sharing.setUserPermission(
              projectId,
              colleague.username,
              Permission.admin,
            );
            await _pace();
            expect(
              (await sharing.userShares(projectId)).single.permission,
              Permission.admin,
            );
            expect(ownerSync.refreshAfterWriteCalls, 0);

            await colleagueSharing.setUserPermission(
              projectId,
              colleague.username,
              Permission.write,
            );
            await _pace();
            expect(colleagueSync.refreshAfterWriteCalls, 1);
            expect(
              (await colleagueSharing.userShares(projectId)).single.permission,
              Permission.write,
            );

            await sharing.removeUserShare(projectId, colleague.username);
            await _pace();
            expect(await sharing.userShares(projectId), isEmpty);
            await expectLater(
              sharing.removeUserShare(projectId, colleague.username),
              throwsA(isA<Forbidden>().having((f) => f.code, 'code', 7003)),
            );
          });

          test('teams are added, changed and removed, and one the reader is '
              'not in comes without its name', () async {
            final projectId = await seeder.create('/projects', {
              'title': 'Teams over $name',
            });
            await _pace();
            final team = await teams.create(NewTeam(name: 'Builders $name'));
            await _pace();

            await sharing.shareWithTeam(projectId, team.id, Permission.read);
            await _pace();
            var shares = await sharing.teamShares(projectId);
            expect(shares.single.teamId, team.id);
            expect(shares.single.teamName, 'Builders $name');
            expect(shares.single.memberCount, 1);
            expect(shares.single.permission, Permission.read);

            await expectLater(
              sharing.shareWithTeam(projectId, team.id, Permission.write),
              throwsA(isA<DomainError>().having((f) => f.code, 'code', 6004)),
            );
            await expectLater(
              sharing.shareWithTeam(projectId, 999999999, Permission.read),
              throwsA(isA<NotFound>().having((f) => f.code, 'code', 6002)),
            );

            await sharing.setTeamPermission(
              projectId,
              team.id,
              Permission.admin,
            );
            await _pace();
            expect(
              (await sharing.teamShares(projectId)).single.permission,
              Permission.admin,
            );
            expect(ownerSync.refreshAfterWriteCalls, 1);

            await sharing.shareWithUser(
              projectId,
              colleague.username,
              Permission.admin,
            );
            await _pace();
            final hidden = (await colleagueSharing.teamShares(projectId))
                .single;
            expect(hidden.teamId, team.id);
            expect(hidden.isHidden, isTrue);
            expect(hidden.permission, Permission.admin);

            await sharing.removeTeamShare(projectId, team.id);
            await _pace();
            shares = await sharing.teamShares(projectId);
            expect(shares, isEmpty);
            expect(ownerSync.refreshAfterWriteCalls, 2);
            await expectLater(
              sharing.removeTeamShare(projectId, team.id),
              throwsA(isA<Forbidden>().having((f) => f.code, 'code', 6007)),
            );
            await teams.delete(team.id);
            await _pace();
          });

          test('links are created with and without a password, listed and '
              'deleted', () async {
            final projectId = await seeder.create('/projects', {
              'title': 'Links over $name',
            });
            await _pace();
            expect(await sharing.linkShares(projectId), isEmpty);

            final open = await sharing.createLinkShare(
              projectId,
              const NewLinkShare(permission: Permission.read),
            );
            await _pace();
            final guarded = await sharing.createLinkShare(
              projectId,
              const NewLinkShare(
                permission: Permission.write,
                name: 'Guests',
                password: 'a-secret-for-guests',
              ),
            );
            await _pace();
            expect(open.hash, hasLength(40));
            expect(open.passwordProtected, isFalse);
            expect(open.sharedBy?.id, owner.id);
            expect(guarded.passwordProtected, isTrue);
            expect(guarded.name, 'Guests');
            expect(guarded.permission, Permission.write);
            expect('$guarded', isNot(contains(guarded.hash)));

            final listed = await sharing.linkShares(projectId);
            expect(listed.map((link) => link.id), [open.id, guarded.id]);
            expect(listed.first.hash, open.hash);
            final url = linkShareUrl(
              base: webFrontendBase(
                serverRoot: only.rootUri,
                frontendUrl: only.info.frontendUrl,
              ),
              hash: open.hash,
              viewId: 3,
            );
            expect(url.path, endsWith('/share/${open.hash}/auth'));
            expect(url.queryParameters, {'view': '3'});

            await sharing.shareWithUser(
              projectId,
              colleague.username,
              Permission.write,
            );
            await _pace();
            await expectLater(
              colleagueSharing.linkShares(projectId),
              throwsA(isA<Forbidden>()),
              reason: 'links are for admins',
            );

            await sharing.deleteLinkShare(projectId, open.id);
            await _pace();
            expect(
              (await sharing.linkShares(projectId)).map((link) => link.id),
              [guarded.id],
            );
            await sharing.deleteLinkShare(projectId, open.id);
            await _pace();
          });
        });
      }
    },
  );
}
