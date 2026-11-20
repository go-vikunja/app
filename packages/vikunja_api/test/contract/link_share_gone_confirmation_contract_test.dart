@Tags(['contract'])
@Timeout(Duration(minutes: 8))
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import 'helpers.dart';

// Before 2.7, v1 answers every request with a deleted share's token with a
// 500 ("Could not determine the current user."), as it answers a real
// server error, while a renewal of that token is a 404 code 3006 on v1 and
// a 401 on v2 on every version: LinkShareGoneInterceptor's confirmGone asks
// that renewal, as the app's guest session does. One share
// authentication.
const _pace = Duration(milliseconds: 500);

void main() {
  group(
    "a deleted share's token on the local Docker server",
    skip: contractSkip,
    () {
      late Dio dio;
      late ServerConnection connection;
      late int projectId;
      late String token;

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
          ).projects.create(const NewProject(title: 'Shared, then not')),
        )).id;
        final sharing = createProjectSharingPort(
          dio: ownerDio,
          connection: connection,
        );
        await Future<void>.delayed(_pace);
        final share = await despiteWriteRaces(
          () => sharing.createLinkShare(
            projectId,
            const NewLinkShare(permission: Permission.write),
          ),
        );
        token = (await patiently(
          () => LinkShareAuthClient(dio, connection).authenticate(share.hash),
        )).token.jwt;
        await Future<void>.delayed(_pace);
        await despiteWriteRaces(
          () => sharing.deleteLinkShare(projectId, share.id),
        );
        await Future<void>.delayed(_pace);
      });

      tearDownAll(() => dio.close(force: true));

      for (final version in contractApiVersions) {
        test('is told gone on ${version.pathSegment}, before 2.7 on v1 only '
            'through the renewal that confirmGone asks', () async {
          final only = onlyVersion(connection, version);
          final auth = LinkShareAuthClient(dio, only);
          final asked = <String>[];
          final gone = <LinkShareGone>[];
          ProjectsPort projects({required bool confirming}) => createReadClient(
            dio: createAuthenticatedDio(
              base: dio,
              connection: only,
              tokens: StaticJwt(token),
              interceptors: [
                LinkShareGoneInterceptor(
                  onGone: gone.add,
                  confirmGone: confirming
                      ? (token) async {
                          asked.add(token);
                          try {
                            await auth.renew(token);
                            return null;
                          } on LinkShareGone catch (failure) {
                            return failure;
                          }
                        }
                      : null,
                ),
              ],
            ),
            connection: only,
          ).projects;
          final answersServerError =
              version == ApiVersion.v1 &&
              !contractServerVersion.isAtLeast(2, 7);

          if (answersServerError) {
            await expectLater(
              projects(confirming: false).listAll(),
              throwsA(
                isA<ServerFailure>().having((f) => f.statusCode, 's', 500),
              ),
            );
          }
          await expectLater(
            projects(confirming: true).listAll(),
            throwsA(
              isA<LinkShareGone>().having(
                (f) => f.code,
                'code',
                switch (version) {
                  _ when answersServerError => 3006,
                  ApiVersion.v1 => 13003,
                  ApiVersion.v2 => isNull,
                },
              ),
            ),
          );
          expect(asked, answersServerError ? [token] : isEmpty);
          expect(gone, hasLength(1));
          await expectLater(
            auth.renew(token),
            throwsA(
              isA<LinkShareGone>().having(
                (f) => f.code,
                'code',
                version == ApiVersion.v1 ? 3006 : isNull,
              ),
            ),
          );
        });
      }
    },
  );
}
