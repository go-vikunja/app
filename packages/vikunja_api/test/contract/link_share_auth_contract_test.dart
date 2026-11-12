@Tags(['contract'])
@Timeout(Duration(minutes: 8))
library;

import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import 'helpers.dart';

// One throwaway owner shares a project per API version by a read link and
// a password link; the guests sign in, renew, read, and lose access when the
// read link is deleted. Link share sign-in and the invite check count
// against the limit per minute and IP that sign-in and registration share
// across every test file (10 unless raised, as test_servers/docker-compose.yaml
// does), so those calls are spaced for a server with the default.
// No hash, token or password is ever printed: failures name shapes only.
const _unauthenticatedSpacing = Duration(seconds: 7);
const _pace = Duration(milliseconds: 500);

Matcher _gone(Object? code) =>
    isA<LinkShareGone>().having((f) => f.code, 'code', code);

String _randomWord(int length) {
  const alphabet =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final random = Random.secure();
  return String.fromCharCodes([
    for (var i = 0; i < length; i++)
      alphabet.codeUnitAt(random.nextInt(alphabet.length)),
  ]);
}

void main() {
  group('link share guests on local Docker servers', skip: contractSkip, () {
    for (final (:port, :version) in contractServers) {
      group('$version on :$port', () {
        late Dio dio;
        late ServerConnection connection;
        late TestUser owner;
        DateTime? lastUnauthenticated;

        Future<T> unauthenticated<T>(Future<T> Function() call) async {
          if (lastUnauthenticated case final last?) {
            final left =
                _unauthenticatedSpacing - DateTime.now().difference(last);
            if (left > Duration.zero) await Future<void>.delayed(left);
          }
          try {
            return await patiently(call);
          } finally {
            lastUnauthenticated = DateTime.now();
          }
        }

        Future<T> paced<T>(Future<T> Function() write) async {
          final result = await despiteWriteRaces(write);
          await Future<void>.delayed(_pace);
          return result;
        }

        Dio asOwner(ServerConnection over) => createAuthenticatedDio(
          base: dio,
          connection: over,
          tokens: StaticJwt(owner.jwt),
        );

        setUpAll(() async {
          dio = contractDio();
          connection = await DioServerConnector(dio)
              .connect('http://localhost:$port');
          expect(connection.info.linkSharingEnabled, isTrue);
          owner = await registerAndLogin(dio, connection);
          lastUnauthenticated = DateTime.now();
        });

        tearDownAll(() => dio.close(force: true));

        for (final apiVersion in ApiVersion.values) {
          group(apiVersion.pathSegment, () {
            final linkPassword = 'link-${_randomWord(16)}';
            late ServerConnection only;
            late LinkShareAuthClient client;
            late ProjectSharingPort sharing;
            late int projectId;
            late LinkShare readLink;
            late LinkShare passwordLink;
            late LinkShareAuth readGuest;
            final gone = <LinkShareGone>[];

            ProjectsPort guestProjects(String token) {
              final guestDio = createAuthenticatedDio(
                base: dio,
                connection: only,
                tokens: StaticJwt(token),
                interceptors: [LinkShareGoneInterceptor(onGone: gone.add)],
              );
              return createReadClient(dio: guestDio, connection: only).projects;
            }

            setUpAll(() async {
              only = onlyVersion(connection, apiVersion);
              client = LinkShareAuthClient(dio, only);
              final ownerDio = asOwner(only);
              sharing = createProjectSharingPort(
                dio: ownerDio,
                connection: only,
              );
              projectId = (await paced(
                () => createWriteClient(dio: ownerDio, connection: only)
                    .projects
                    .create(
                      NewProject(title: 'Shared ${apiVersion.pathSegment}'),
                    ),
              )).id;
              readLink = await paced(
                () => sharing.createLinkShare(
                  projectId,
                  const NewLinkShare(
                    permission: Permission.read,
                    name: 'Contract guest',
                  ),
                ),
              );
              passwordLink = await paced(
                () => sharing.createLinkShare(
                  projectId,
                  NewLinkShare(
                    permission: Permission.write,
                    password: linkPassword,
                  ),
                ),
              );
            });

            tearDownAll(() async {
              await paced(
                () => createWriteClient(
                  dio: asOwner(only),
                  connection: only,
                ).projects.delete(projectId),
              );
            });

            test('a read link signs in without a password', () async {
              readGuest = await unauthenticated(
                () => client.authenticate(readLink.hash),
              );

              expect(readGuest.shareId, readLink.id);
              expect(readGuest.projectId, projectId);
              expect(readGuest.permission, Permission.read);
              expect(readGuest.name, 'Contract guest');
              final claims = readGuest.token.claims;
              expect(claims.shareId, readLink.id);
              expect(claims.projectId, projectId);
              expect(claims.permission, Permission.read);
              expect(claims.sharedById, owner.id);
              expect(
                claims.expiresAt.difference(claims.issuedAt!),
                const Duration(hours: 72),
              );
            });

            test('a password link asks for it, refuses a wrong one and '
                'grants write with the right one', () async {
              await expectLater(
                unauthenticated(() => client.authenticate(passwordLink.hash)),
                throwsA(
                  isA<DomainError>()
                      .having((f) => f.statusCode, 'status', 412)
                      .having((f) => f.code, 'code', 13001),
                ),
              );
              await expectLater(
                unauthenticated(
                  () => client.authenticate(
                    passwordLink.hash,
                    password: 'wrong-${_randomWord(8)}',
                  ),
                ),
                throwsA(isA<Forbidden>().having((f) => f.code, 'code', 13002)),
              );

              final writer = await unauthenticated(
                () => client.authenticate(
                  passwordLink.hash,
                  password: linkPassword,
                ),
              );

              expect(writer.shareId, passwordLink.id);
              expect(writer.permission, Permission.write);
              expect(writer.name, isNull);
            });

            test('the guest reads only the shared project, without its '
                'permission in the list', () async {
              final projects = await guestProjects(readGuest.token.jwt)
                  .listAll(includeArchived: true);

              expect([for (final p in projects) p.id], [projectId]);
              expect(projects.single.maxPermission, isNull);
              expect(
                (await guestProjects(readGuest.token.jwt).read(projectId))
                    .maxPermission,
                Permission.read,
              );
            });

            test(
              'renewal gives a token for the same link that works',
              () async {
                final renewed = await client.renew(readGuest.token.jwt);

                expect(renewed.claims.shareId, readLink.id);
                expect(renewed.claims.projectId, projectId);
                expect(
                  renewed.claims.expiresAt.isBefore(
                    readGuest.token.claims.expiresAt,
                  ),
                  isFalse,
                );
                expect(
                  await guestProjects(renewed.jwt).listAll(),
                  hasLength(1),
                );
              },
            );

            test('an expired or broken token cannot be renewed', () async {
              await expectLater(
                client.renew('not-a-jwt'),
                throwsA(isA<TokenRejected>()),
              );
            });

            test("a deleted link ends the guest's access", () async {
              await paced(
                () => sharing.deleteLinkShare(projectId, readLink.id),
              );

              await expectLater(
                guestProjects(readGuest.token.jwt).listAll(),
                throwsA(_gone(apiVersion == ApiVersion.v1 ? 13003 : isNull)),
              );
              expect(gone, hasLength(1));
              await expectLater(
                client.renew(readGuest.token.jwt),
                throwsA(isA<LinkShareGone>()),
              );
              await expectLater(
                unauthenticated(() => client.authenticate(readLink.hash)),
                throwsA(_gone(3006)),
              );
            });
          });
        }

        test('an invite that does not exist is 404 code 2005', () async {
          await expectLater(
            unauthenticated(
              () => createInviteLinksPort(
                dio: dio,
                connection: connection,
              ).check(_randomWord(64)),
            ),
            throwsA(isA<NotFound>().having((f) => f.code, 'code', 2005)),
          );
        });

        test('/info carries the notice fields', () {
          final info = connection.info;

          // The test server sets no message, demo mode, imprint or privacy
          // policy; its one legal link is the terms
          // (test_servers/docker-compose.yaml), which /info lists from 2.8.0.
          expect(info.motd, isEmpty);
          expect(info.demoModeEnabled, isFalse);
          expect(info.auth.localEnabled, isTrue);
          expect(info.auth.registrationEnabled, isTrue);
          expect(info.legal.imprintUrl, isNull);
          expect(info.legal.privacyPolicyUrl, isNull);
          expect(
            info.legal.links,
            info.version!.isAtLeast(2, 8)
                ? [
                    LegalLink(
                      text: 'Terms of Service',
                      url: Uri.parse('https://example.org/terms'),
                    ),
                  ]
                : isEmpty,
          );
          expect(info.enabledProFeatures, isNot(contains('user_invites')));
          expect(connection.capabilities.has(Capability.userInvites), isFalse);
        });
      });
    }
  });
}
