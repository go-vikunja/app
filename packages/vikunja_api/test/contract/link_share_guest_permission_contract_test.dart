@Tags(['contract'])
@Timeout(Duration(minutes: 8))
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import 'helpers.dart';

// What a link-share guest of each permission is told about the shared
// project: before 2.6.0 the project list says read to every guest, from
// 2.6.0 it says nothing, and the single read says the share's permission
// on both API versions (v1 in `x-max-permission`). The app's GuestReadClient
// rests on this. Three share authentications, spaced for the sign-in limit.
const _pace = Duration(milliseconds: 500);
const _unauthenticatedSpacing = Duration(seconds: 7);

void main() {
  group(
    "a guest's permission on the local Docker server",
    skip: contractSkip,
    () {
      late Dio dio;
      late ServerConnection connection;
      late int projectId;
      final guests = <Permission, String>{};

      setUpAll(() async {
        dio = contractDio();
        connection = await DioServerConnector(dio)
            .connect('http://localhost:$contractPort');
        final owner = await registerAndLogin(dio, connection);
        final ownerDio = createAuthenticatedDio(
          base: dio,
          connection: connection,
          tokens: StaticJwt(owner.jwt),
        );
        projectId = (await despiteWriteRaces(
          () => createWriteClient(
            dio: ownerDio,
            connection: connection,
          ).projects.create(const NewProject(title: 'Shared by permission')),
        )).id;
        final sharing = createProjectSharingPort(
          dio: ownerDio,
          connection: connection,
        );
        final auth = LinkShareAuthClient(dio, connection);
        for (final permission in Permission.values) {
          await Future<void>.delayed(_pace);
          final share = await despiteWriteRaces(
            () => sharing.createLinkShare(
              projectId,
              NewLinkShare(permission: permission),
            ),
          );
          await Future<void>.delayed(_unauthenticatedSpacing);
          guests[permission] = (await patiently(
            () => auth.authenticate(share.hash),
          )).token.jwt;
        }
      });

      tearDownAll(() => dio.close(force: true));

      ProjectsPort projectsOf(String token, ApiVersion version) {
        final only = onlyVersion(connection, version);
        return createReadClient(
          dio: createAuthenticatedDio(
            base: dio,
            connection: only,
            tokens: StaticJwt(token),
          ),
          connection: only,
        ).projects;
      }

      for (final version in contractApiVersions) {
        test('the list says read before 2.6.0 and nothing from it, the single '
            "read the share's permission (${version.pathSegment})", () async {
          final listsRead = !contractServerVersion.isAtLeast(2, 6);
          for (final MapEntry(key: permission, value: token)
              in guests.entries) {
            final listed = await projectsOf(
              token,
              version,
            ).listAll(includeArchived: true);
            final read = await projectsOf(token, version).read(projectId);

            expect(
              [for (final project in listed) project.id],
              [projectId],
              reason: permission.name,
            );
            expect(
              listed.single.maxPermission,
              listsRead ? Permission.read : isNull,
              reason: permission.name,
            );
            expect(read.maxPermission, permission, reason: permission.name);
          }
        });
      }
    },
  );
}
