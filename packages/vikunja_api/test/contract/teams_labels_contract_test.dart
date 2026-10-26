@Tags(['contract'])
@Timeout(Duration(minutes: 6))
library;

import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import 'helpers.dart';

// Two throwaway users: the owner writes through the ports, the member is
// shared into one project with write permission and added to teams.
const _pace = Duration(milliseconds: 500);

Matcher _domainError(int status, int code) => isA<DomainError>()
    .having((f) => f.statusCode, 'status', status)
    .having((f) => f.code, 'code', code);

Matcher _notFound(int code) =>
    isA<NotFound>().having((f) => f.code, 'code', code);

void main() {
  group(
    'labels, teams and the user search on local Docker servers',
    skip: contractSkip,
    () {
      for (final (:port, :version) in contractServers) {
        group('$version on :$port', () {
          late Dio dio;
          late ServerConnection connection;
          late TestUser owner;
          late TestUser member;
          late int projectId;
          late String runId;

          Future<T> paced<T>(Future<T> Function() write) async {
            final result = await despiteWriteRaces(write);
            await Future<void>.delayed(_pace);
            return result;
          }

          Future<Object?> raw(
            TestUser user,
            String method,
            String path, [
            Map<String, Object?>? body,
          ]) async {
            final v1 = connection.apiBaseUri(ApiVersion.v1);
            try {
              final response = await paced(
                () => dio.requestUri<Object?>(
                  v1.replace(path: '${v1.path}$path'),
                  data: body,
                  options: Options(
                    method: method,
                    headers: {'Authorization': 'Bearer ${user.jwt}'},
                  ),
                ),
              );
              return response.data;
            } on DioException catch (error) {
              throw StateError(
                '$method $path failed with ${error.response?.statusCode}',
              );
            }
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
            runId = Random.secure().nextInt(1 << 16).toRadixString(16);
            final project =
                (await raw(owner, 'PUT', '/projects', {
                      'title': 'Teams contract $runId',
                    }))!
                    as Map<String, Object?>;
            projectId = project['id']! as int;
            await raw(owner, 'PUT', '/projects/$projectId/users', {
              'username': member.username,
              'permission': 1,
            });
          });

          tearDownAll(() => dio.close(force: true));

          for (final apiVersion in ApiVersion.values) {
            group(apiVersion.pathSegment, () {
              late LabelsWritePort labels;
              late LabelsWritePort memberLabels;
              late VikunjaReadClient reads;
              late TeamsPort teams;
              late TeamsPort memberTeams;
              late String suffix;

              setUpAll(() {
                suffix = '${apiVersion.pathSegment} $runId';
                final only = onlyVersion(connection, apiVersion);
                final ownerDio = authenticated(owner, only);
                final memberDio = authenticated(member, only);
                labels = RetryingLabelsWrites(
                  createWriteClient(dio: ownerDio, connection: only).labels,
                );
                memberLabels = createWriteClient(
                  dio: memberDio,
                  connection: only,
                ).labels;
                reads = createReadClient(dio: ownerDio, connection: only);
                teams = createTeamsPort(dio: ownerDio, connection: only);
                memberTeams = createTeamsPort(dio: memberDio, connection: only);
              });

              group('labels', () {
                test("the creator changes only what is set; another client's "
                    'colour and description survive', () async {
                  final label = await labels.create(
                    NewLabel(
                      title: 'Odd $suffix',
                      hexColor: 'ABC',
                      description: '<p>Kept</p>',
                    ),
                  );

                  final renamed = await paced(
                    () => labels.update(
                      label.id,
                      LabelChanges(title: 'Renamed $suffix'),
                    ),
                  );
                  final stored =
                      (await raw(owner, 'GET', '/labels/${label.id}'))!
                          as Map<String, Object?>;

                  expect(renamed.title, 'Renamed $suffix');
                  expect(stored['hex_color'], 'ABC');
                  expect(stored['description'], '<p>Kept</p>');

                  final recoloured = await paced(
                    () => labels.update(
                      label.id,
                      const LabelChanges(hexColor: '#1973ff'),
                    ),
                  );
                  final cleared = await paced(
                    () => labels.update(
                      label.id,
                      const LabelChanges(hexColor: '', description: ''),
                    ),
                  );

                  expect(recoloured.hexColor, '1973ff');
                  expect(recoloured.title, 'Renamed $suffix');
                  expect(cleared.hexColor, '');
                  expect(cleared.description, '');
                  expect(cleared.title, 'Renamed $suffix');
                });

                test('an unchanged label is read back', () async {
                  final label = await labels.create(
                    NewLabel(title: 'Same $suffix', hexColor: 'e8e8e8'),
                  );

                  final same = await labels.update(
                    label.id,
                    LabelChanges(title: 'Same $suffix'),
                  );

                  expect(same.id, label.id);
                  expect(same.hexColor, 'e8e8e8');
                });

                test('a title above 250 code points is refused', () async {
                  final label = await labels.create(
                    NewLabel(title: 'Long $suffix'),
                  );

                  await expectLater(
                    labels.update(label.id, LabelChanges(title: 'ä' * 251)),
                    throwsA(isA<ValidationFailed>()),
                  );
                });

                test('someone else may not change or delete a label they '
                    'see; one they cannot see is not found for them', () async {
                  final shared = await labels.create(
                    NewLabel(title: 'Shared $suffix'),
                  );
                  final private = await labels.create(
                    NewLabel(title: 'Private $suffix'),
                  );
                  final task =
                      (await raw(owner, 'PUT', '/projects/$projectId/tasks', {
                            'title': 'Carries $suffix',
                          }))!
                          as Map<String, Object?>;
                  await raw(owner, 'PUT', '/tasks/${task['id']}/labels', {
                    'label_id': shared.id,
                  });

                  await expectLater(
                    memberLabels.update(
                      shared.id,
                      const LabelChanges(title: 'x'),
                    ),
                    throwsA(
                      isA<Forbidden>().having((f) => f.code, 'code', isNull),
                    ),
                  );
                  await expectLater(
                    memberLabels.delete(shared.id),
                    throwsA(isA<Forbidden>()),
                  );
                  await expectLater(
                    memberLabels.update(
                      private.id,
                      const LabelChanges(title: 'x'),
                    ),
                    throwsA(_notFound(8002)),
                  );
                  final unchanged =
                      (await raw(owner, 'GET', '/labels/${shared.id}'))!
                          as Map<String, Object?>;
                  expect(unchanged['title'], 'Shared $suffix');
                });

                test('deleted twice, then gone for an update', () async {
                  final label = await labels.create(
                    NewLabel(title: 'Doomed $suffix'),
                  );

                  await paced(() => labels.delete(label.id));
                  await paced(() => labels.delete(label.id));

                  await expectLater(
                    labels.update(label.id, const LabelChanges(title: 'x')),
                    throwsA(_notFound(8002)),
                  );
                  final all = await reads.labels.listAll();
                  expect(all.map((l) => l.id), isNot(contains(label.id)));
                });

                test('a numeric title is found by a search for it', () async {
                  final number =
                      '${Random.secure().nextInt(900000000) + 100000000}';
                  final label = await labels.create(NewLabel(title: number));

                  final page = await reads.labels.list(search: number);

                  expect(page.items.map((l) => l.id), contains(label.id));
                });
              });

              group('teams', () {
                test('created as admin, read by a member as member', () async {
                  final team = await paced(
                    () => teams.create(
                      NewTeam(
                        name: 'Team $suffix',
                        description: '<p>Hello</p>',
                      ),
                    ),
                  );
                  await paced(() => teams.addMember(team.id, member.username));

                  final asMember = await memberTeams.read(team.id);
                  final asOwner = await teams.read(team.id);

                  expect(team.maxPermission, Permission.admin);
                  expect(team.members.single.user.id, owner.id);
                  expect(team.members.single.admin, isTrue);
                  expect(team.description, '<p>Hello</p>');
                  expect(team.isExternal, isFalse);
                  expect(asMember.maxPermission, Permission.read);
                  expect(asOwner.members.map((m) => m.user.id), [
                    owner.id,
                    member.id,
                  ]);
                  final listed = await teams.list(query: 'Team $suffix');
                  expect(listed.map((t) => t.id), [team.id]);
                  expect(listed.single.members, hasLength(2));
                });

                test('members added once, admin toggled, removed, the last '
                    'one kept', () async {
                  final team = await paced(
                    () => teams.create(NewTeam(name: 'Members $suffix')),
                  );
                  final other = await paced(
                    () => teams.create(NewTeam(name: 'Other $suffix')),
                  );

                  await paced(() => teams.addMember(team.id, member.username));
                  await expectLater(
                    teams.addMember(team.id, member.username),
                    throwsA(_domainError(409, 6005)),
                  );
                  await expectLater(
                    teams.addMember(team.id, 'nobody-$runId'),
                    throwsA(_notFound(1005)),
                  );

                  expect(
                    await paced(
                      () => teams.toggleAdmin(team.id, member.username),
                    ),
                    isTrue,
                  );
                  expect(
                    (await teams.read(team.id)).members.last.admin,
                    isTrue,
                  );
                  expect(
                    await paced(
                      () => teams.toggleAdmin(team.id, member.username),
                    ),
                    isFalse,
                  );
                  await expectLater(
                    teams.toggleAdmin(other.id, member.username),
                    throwsA(isA<TeamMemberMissing>()),
                  );
                  expect(
                    (await teams.read(other.id)).members.map((m) => m.user.id),
                    [owner.id],
                  );

                  await expectLater(
                    memberTeams.update(
                      team.id,
                      const TeamChanges(name: 'Hijacked'),
                    ),
                    throwsA(isA<Forbidden>()),
                  );
                  await paced(
                    () => teams.removeMember(team.id, member.username),
                  );
                  await expectLater(
                    teams.removeMember(team.id, owner.username),
                    throwsA(_domainError(400, 6006)),
                  );
                  await paced(() => teams.delete(team.id));
                  await paced(() => teams.delete(other.id));
                  await expectLater(
                    teams.read(team.id),
                    throwsA(isA<Forbidden>()),
                  );
                });

                test('updated without losing the public flag; a description '
                    'cleared as an empty paragraph', () async {
                  final team = await paced(
                    () => teams.create(
                      NewTeam(
                        name: 'Edit $suffix',
                        description: '<p>Old</p>',
                        isPublic: true,
                      ),
                    ),
                  );

                  final renamed = await paced(
                    () => teams.update(
                      team.id,
                      TeamChanges(name: 'Edited $suffix'),
                    ),
                  );
                  final cleared = await paced(
                    () => teams.update(
                      team.id,
                      const TeamChanges(description: ''),
                    ),
                  );
                  final read = await teams.read(team.id);

                  expect(renamed.name, 'Edited $suffix');
                  expect(renamed.isPublic, isTrue);
                  expect(renamed.description, '<p>Old</p>');
                  expect(cleared.description, '<p></p>');
                  expect(read.description, '<p></p>');
                  expect(read.isPublic, isTrue);
                  await paced(() => teams.delete(team.id));
                });
              });

              test('the user search finds the exact username in any case, '
                  'never with an email', () async {
                final found = await reads.users.searchUsers(
                  member.username.toUpperCase(),
                );
                final prefix = await reads.users.searchUsers(
                  member.username.substring(0, member.username.length - 1),
                );

                expect(found.map((user) => user.id), [member.id]);
                expect(found.single.username, member.username);
                expect(found.single.email, isNull);
                expect(prefix, isEmpty);
                expect(await reads.users.searchUsers(' '), isEmpty);
              });
            });
          }
        });
      }
    },
  );
}
