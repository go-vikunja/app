@Tags(['contract'])
@Timeout(Duration(minutes: 10))
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/token_store.dart';
import 'package:vikunja_mobile/core/repositories/account_security_repository.dart';
import 'package:vikunja_mobile/core/repositories/account_security_repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/account_settings/application/integration_addresses.dart';

import '../helpers/auth_fakes.dart';
import 'helpers.dart';

Future<void> _pace() => Future<void>.delayed(const Duration(milliseconds: 500));

String _sessionOf(String jwt) => JwtClaims.tryParse(jwt)!.sessionId;

const _propfind = '''
<?xml version="1.0" encoding="utf-8"?>
<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:prop><d:current-user-principal/><c:calendar-home-set/></d:prop>
</d:propfind>''';

/// Checks a secret's shape without ever putting it into a failure message.
void _expectShape(String secret, RegExp shape) => expect(
  shape.hasMatch(secret),
  isTrue,
  reason: 'a secret of length ${secret.length}',
);

void main() {
  group(
    'account security against the local Docker server',
    skip: contractSkip,
    () {
      late Dio dio;
      late ServerConnection connection;
      late TestUser user;
      late Future<String> Function() loginAgain;

      setUpAll(() async {
        dio = contractDio();
        connection = await DioServerConnector(dio)
            .connect('http://localhost:$contractServerPort');
        (:user, :loginAgain) = await registerAndLoginAgainLater(
          dio,
          connection,
        );
      });

      tearDownAll(() => dio.close(force: true));

      // At the address the CalDAV page shows; the status alone, never the
      // password, goes into a failure message.
      Future<int> propfind(String password) async {
        final credentials = base64Encode(
          utf8.encode('${user.username}:$password'),
        );
        final response = await patiently(
          () => dio.requestUri<String>(
            caldavPrincipalUri(connection, user.username),
            data: _propfind,
            options: Options(
              method: 'PROPFIND',
              contentType: 'application/xml; charset=utf-8',
              responseType: ResponseType.plain,
              headers: {'Authorization': 'Basic $credentials', 'Depth': '0'},
              validateStatus: (_) => true,
            ),
          ),
        );
        return response.statusCode!;
      }

      for (final apiVersion in [ApiVersion.v2, ApiVersion.v1]) {
        group('over ${apiVersion.pathSegment}', () {
          final accountId = 'contract-${apiVersion.pathSegment}';
          late AccountSecurityRepository repository;

          setUpAll(() async {
            final only = onlyApiVersion(connection, apiVersion);
            final authenticated = createAuthenticatedDio(
              base: dio,
              connection: only,
              tokens: StaticJwt(user.jwt),
            );
            final preferences = MemoryPreferencesStore();
            final secureStore = MemorySecureStore();
            await AccountRegistry(preferences).upsert(
              RegisteredAccount(
                account: Account(
                  id: accountId,
                  serverRoot: only.rootUri,
                  userId: user.id,
                  username: user.username,
                  displayName: user.username,
                  addedAt: DateTime.utc(2026, 10, 21),
                ),
                connection: only,
              ),
              activate: true,
            );
            // The login's JWT stands in for the app's access token; it
            // carries the session's sid the same way.
            await secureStore.write(TokenStore.refreshTokenKey(accountId), '-');
            await secureStore.write(
              TokenStore.accessTokenKey(accountId),
              user.jwt,
            );
            final container = ProviderContainer(
              overrides: [
                preferencesStoreProvider.overrideWithValue(preferences),
                secureStoreProvider.overrideWithValue(secureStore),
                tokenGatewayProvider.overrideWithValue(FakeTokenGateway()),
                accountDioProvider.overrideWith((ref, _) => authenticated),
              ],
            );
            addTearDown(container.dispose);
            await container.read(accountsProvider.future);
            repository = container
                .listen(
                  accountSecurityRepositoryForProvider(accountId),
                  (_, _) {},
                )
                .read();
          });

          test("lists the sessions with this app's own among them, and ends "
              'another one', () async {
            final other = _sessionOf(await loginAgain());
            final current = await repository.currentSessionId();

            expect(current, _sessionOf(user.jwt));
            final ids = [
              for (final session in await repository.sessions()) session.id,
            ];
            expect(ids, containsAll([current, other]));
            final own = (await repository.sessions()).firstWhere(
              (session) => session.id == current,
            );
            expect(own.deviceInfo, 'Rurana contract tests');
            expect(own.created, isNotNull);
            expect(own.lastActive, isNotNull);

            await expectLater(
              repository.revokeSession(current!),
              throwsArgumentError,
            );
            await despiteWriteRaces(() => repository.revokeSession(other));
            await _pace();
            final after = [
              for (final session in await repository.sessions()) session.id,
            ];
            expect(after, contains(current));
            expect(after, isNot(contains(other)));
            // Gone already: ending it again is no failure.
            await repository.revokeSession(other);
          });

          test('ends every other session and keeps its own', () async {
            final others = [
              _sessionOf(await loginAgain()),
              _sessionOf(await loginAgain()),
            ];

            final ended = await despiteWriteRaces(
              repository.revokeOtherSessions,
            );
            await _pace();

            expect(ended, greaterThanOrEqualTo(others.length));
            expect(
              [for (final session in await repository.sessions()) session.id],
              [_sessionOf(user.jwt)],
            );
          });

          test(
            'creates an API token, shows its value once and deletes it',
            () async {
              final permissions = await repository.apiPermissions();
              expect(permissions.offers('tasks', 'read_all'), isTrue);
              expect(
                permissions.groupNames.last,
                ApiPermissionGroups.otherGroup,
              );

              final created = await despiteWriteRaces(
                () => repository.createApiToken(
                  NewApiToken(
                    title: 'Rurana contract ${apiVersion.pathSegment}',
                    permissions: const {
                      'tasks': ['read_all'],
                      'caldav': ['access'],
                    },
                    expiresAt: DateTime.now().add(const Duration(days: 1)),
                  ),
                ),
              );
              await _pace();

              _expectShape(created.secret, RegExp(r'^tk_[0-9a-f]{40}$'));
              expect(
                created.toString().contains(created.secret),
                isFalse,
                reason: 'toString names the value',
              );
              final listed = (await repository.apiTokens()).singleWhere(
                (token) => token.id == created.token.id,
              );
              expect(listed.title, 'Rurana contract ${apiVersion.pathSegment}');
              expect(listed.permissions, {
                'tasks': ['read_all'],
                'caldav': ['access'],
              });
              expect(listed.isExpiredAt(DateTime.now()), isFalse);

              await despiteWriteRaces(
                () => repository.deleteApiToken(created.token.id),
              );
              await _pace();
              expect(
                (await repository.apiTokens()).map((token) => token.id),
                isNot(contains(created.token.id)),
              );
              // 2.7.1 answers 404 code 14017, which counts as deleted.
              await expectLater(
                repository.deleteApiToken(created.token.id),
                (connection.info.version?.isAtLeast(2, 7, 1) ?? false)
                    ? completes
                    : throwsA(isA<Forbidden>()),
              );
            },
          );

          test(
            'creates a CalDAV token, shows its value once and deletes it',
            () async {
              final created = await despiteWriteRaces(
                repository.createCaldavToken,
              );
              await _pace();

              _expectShape(created.secret, RegExp(r'^[A-Za-z0-9]{64}$'));
              expect(
                created.toString().contains(created.secret),
                isFalse,
                reason: 'toString names the value',
              );
              expect(
                (await repository.caldavTokens()).map((token) => token.id),
                contains(created.token.id),
              );
              expect(await propfind(created.secret), 207);

              await despiteWriteRaces(
                () => repository.deleteCaldavToken(created.token.id),
              );
              await _pace();
              expect(
                (await repository.caldavTokens()).map((token) => token.id),
                isNot(contains(created.token.id)),
              );
              expect(await propfind(created.secret), 401);
            },
          );

          test('a new account has neither two-factor authentication nor an '
              'export', () async {
            expect(await repository.totpStatus(), TotpStatus.notSetUp);
            expect(await repository.dataExport(), isNull);
          });
        });
      }
    },
  );
}
