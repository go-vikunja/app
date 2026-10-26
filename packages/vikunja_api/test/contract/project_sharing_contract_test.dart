@Tags(['contract'])
@Timeout(Duration(minutes: 6))
library;

import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import 'helpers.dart';

// Three throwaway users: the owner shares projects with the member and the
// guest, the guest is in the owner's team, the member is not. No link
// share hash is ever printed: failures name shapes only.
const _pace = Duration(milliseconds: 500);
final _hashShape = RegExp(r'^[A-Za-z0-9]{40}$');

Matcher _domainError(int status, int code) => isA<DomainError>()
    .having((f) => f.statusCode, 'status', status)
    .having((f) => f.code, 'code', code);

Matcher _notFound(int code) =>
    isA<NotFound>().having((f) => f.code, 'code', code);

Matcher _forbidden([int? code]) =>
    isA<Forbidden>().having((f) => f.code, 'code', code);

void main() {
  group('project sharing on local Docker servers', skip: contractSkip, () {
    for (final (:port, :version) in contractServers) {
      group('$version on :$port', () {
        late Dio dio;
        late ServerConnection connection;
        late TestUser owner;
        late TestUser member;
        late TestUser guest;
        late String runId;

        Future<T> paced<T>(Future<T> Function() write) async {
          final result = await despiteWriteRaces(write);
          await Future<void>.delayed(_pace);
          return result;
        }

        Future<int> createProject(String title, {int parent = 0}) async {
          final v1 = connection.apiBaseUri(ApiVersion.v1);
          final response = await paced(
            () => dio.putUri<Map<String, Object?>>(
              v1.replace(path: '${v1.path}/projects'),
              data: {'title': title, 'parent_project_id': parent},
              options: Options(
                headers: {'Authorization': 'Bearer ${owner.jwt}'},
              ),
            ),
          );
          return response.data!['id']! as int;
        }

        Dio authenticated(TestUser user, ServerConnection over) =>
            createAuthenticatedDio(
              base: dio,
              connection: over,
              tokens: StaticJwt(user.jwt),
            );

        setUpAll(() async {
          dio = contractDio();
          connection = await DioServerConnector(dio)
              .connect('http://localhost:$port');
          owner = await registerAndLogin(dio, connection);
          member = await registerAndLogin(dio, connection);
          guest = await registerAndLogin(dio, connection);
          runId = Random.secure().nextInt(1 << 16).toRadixString(16);
        });

        tearDownAll(() => dio.close(force: true));

        for (final apiVersion in ApiVersion.values) {
          group(apiVersion.pathSegment, () {
            late ProjectSharingPort sharing;
            late ProjectSharingPort memberSharing;
            late ProjectsPort memberProjects;
            late ProjectsPort guestProjects;
            late TeamsPort teams;
            late String suffix;

            setUpAll(() {
              suffix = '${apiVersion.pathSegment} $runId';
              final only = onlyVersion(connection, apiVersion);
              sharing = createProjectSharingPort(
                dio: authenticated(owner, only),
                connection: only,
              );
              memberSharing = createProjectSharingPort(
                dio: authenticated(member, only),
                connection: only,
              );
              memberProjects = createReadClient(
                dio: authenticated(member, only),
                connection: only,
              ).projects;
              guestProjects = createReadClient(
                dio: authenticated(guest, only),
                connection: only,
              ).projects;
              teams = createTeamsPort(
                dio: authenticated(owner, only),
                connection: only,
              );
            });

            // What the sync of the app sees: every page, archived included,
            // with the permissions.
            Future<Map<int, Permission?>> visible(ProjectsPort projects) async {
              final all = await projects.listAll(includeArchived: true);
              return {
                for (final project in all)
                  if (!project.isPseudo) project.id: project.maxPermission,
              };
            }

            test('acceptance: a share made read-only, raised to write and '
                'removed reaches the sharee with the next list', () async {
              final project = await createProject('Acceptance $suffix');
              final child = await createProject(
                'Acceptance child $suffix',
                parent: project,
              );

              await paced(
                () =>
                    sharing.addUser(project, member.username, Permission.read),
              );
              final shared = await visible(memberProjects);

              expect(shared[project], Permission.read);
              expect(shared[child], Permission.read);
              expect(
                (await memberProjects.read(project)).maxPermission,
                Permission.read,
              );

              await paced(
                () => sharing.setUserPermission(
                  project,
                  member.username,
                  Permission.write,
                ),
              );
              final raised = await visible(memberProjects);

              expect(raised[project], Permission.write);
              expect(raised[child], Permission.write);

              await paced(() => sharing.removeUser(project, member.username));
              final removed = await visible(memberProjects);

              expect(removed.keys, isNot(contains(project)));
              expect(removed.keys, isNot(contains(child)));
            });

            test('user shares: listed, refused twice and for unknown '
                'users, changed only by admins', () async {
              final project = await createProject('Users $suffix');

              await paced(
                () =>
                    sharing.addUser(project, member.username, Permission.read),
              );
              await paced(
                () =>
                    sharing.addUser(project, guest.username, Permission.write),
              );

              expect(await sharing.listUsers(project), [
                ProjectUserShare(
                  user: User(id: member.id, username: member.username),
                  permission: Permission.read,
                ),
                ProjectUserShare(
                  user: User(id: guest.id, username: guest.username),
                  permission: Permission.write,
                ),
              ]);
              await expectLater(
                sharing.addUser(project, member.username, Permission.read),
                throwsA(_domainError(409, 7002)),
              );
              await expectLater(
                sharing.addUser(project, owner.username, Permission.read),
                throwsA(_domainError(409, 7002)),
              );
              await expectLater(
                sharing.addUser(project, 'nobody-$runId', Permission.read),
                throwsA(_notFound(1005)),
              );
              await expectLater(
                memberSharing.setUserPermission(
                  project,
                  guest.username,
                  Permission.admin,
                ),
                throwsA(_forbidden()),
              );
              expect(
                (await memberSharing.listUsers(project)).map((s) => s.user.id),
                [member.id, guest.id],
              );

              await paced(() => sharing.removeUser(project, guest.username));
              await expectLater(
                sharing.removeUser(project, guest.username),
                throwsA(_forbidden(7003)),
              );
              await expectLater(
                sharing.removeUser(project, 'nobody-$runId'),
                throwsA(_notFound(1005)),
              );
            });

            test('team shares: the members get the permission, others see '
                'the team nameless', () async {
              final project = await createProject('Teams $suffix');
              final team = await paced(
                () => teams.create(NewTeam(name: 'Sharers $suffix')),
              );
              await paced(() => teams.addMember(team.id, guest.username));
              await paced(
                () =>
                    sharing.addUser(project, member.username, Permission.read),
              );

              await paced(
                () => sharing.addTeam(project, team.id, Permission.write),
              );

              expect(await sharing.listTeams(project), [
                ProjectTeamShare(
                  teamId: team.id,
                  teamName: 'Sharers $suffix',
                  memberCount: 2,
                  permission: Permission.write,
                ),
              ]);
              expect(await memberSharing.listTeams(project), [
                ProjectTeamShare(teamId: team.id, permission: Permission.write),
              ]);
              expect((await visible(guestProjects))[project], Permission.write);
              await expectLater(
                sharing.addTeam(project, team.id, Permission.read),
                throwsA(_domainError(409, 6004)),
              );
              await expectLater(
                sharing.addTeam(project, 99999999, Permission.read),
                throwsA(_notFound(6002)),
              );

              await paced(
                () => sharing.setTeamPermission(
                  project,
                  team.id,
                  Permission.admin,
                ),
              );
              expect((await visible(guestProjects))[project], Permission.admin);

              await paced(() => sharing.removeTeam(project, team.id));
              expect(
                (await visible(guestProjects)).keys,
                isNot(contains(project)),
              );
              await expectLater(
                sharing.removeTeam(project, team.id),
                throwsA(_forbidden(6007)),
              );
              await paced(() => teams.delete(team.id));
            });

            test('link shares: created with and without a password, listed '
                'for admins only, deleted', () async {
              final project = await createProject('Links $suffix');
              await paced(
                () =>
                    sharing.addUser(project, member.username, Permission.write),
              );

              final plain = await paced(
                () => sharing.createLinkShare(
                  project,
                  NewLinkShare(
                    permission: Permission.read,
                    name: 'Read $suffix',
                  ),
                ),
              );
              final guarded = await paced(
                () => sharing.createLinkShare(
                  project,
                  NewLinkShare(
                    permission: Permission.write,
                    password: 'pw-$runId-${Random.secure().nextInt(1 << 32)}',
                  ),
                ),
              );

              expect(_hashShape.hasMatch(plain.hash), isTrue);
              expect(plain.passwordProtected, isFalse);
              expect(plain.name, 'Read $suffix');
              expect(plain.sharedBy?.id, owner.id);
              expect(guarded.passwordProtected, isTrue);
              expect(guarded.permission, Permission.write);
              final listed = await sharing.listLinkShares(project);
              expect(listed.map((link) => link.id), [plain.id, guarded.id]);
              expect(listed.first.hash == plain.hash, isTrue);
              await expectLater(
                memberSharing.listLinkShares(project),
                throwsA(isA<Forbidden>()),
              );
              await expectLater(
                memberSharing.createLinkShare(
                  project,
                  const NewLinkShare(permission: Permission.read),
                ),
                throwsA(_forbidden()),
              );

              await paced(() => sharing.deleteLinkShare(project, plain.id));
              await expectLater(
                sharing.deleteLinkShare(project, plain.id),
                throwsA(_notFound(3006)),
              );
              expect(
                (await sharing.listLinkShares(project)).map((link) => link.id),
                [guarded.id],
              );
            });
          });
        }
      });
    }
  });
}
