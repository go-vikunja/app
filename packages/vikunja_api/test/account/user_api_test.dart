import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';

import '../helpers/fake_http_adapter.dart';

const _root = 'https://tasks.example.com';

ServerConnection _connection({required bool hasV2}) {
  const info = ServerInfo(version: ServerVersion(2, 7, 0));
  final apiVersions = {ApiVersion.v1, if (hasV2) ApiVersion.v2};
  return ServerConnection(
    rootUri: Uri.parse(_root),
    apiVersions: apiVersions,
    info: info,
    capabilities: ServerCapabilities.derive(
      info: info,
      apiVersions: apiVersions,
    ),
  );
}

void main() {
  group('currentUser', () {
    for (final (hasV2, url, fixtureName) in [
      (true, '$_root/api/v2/user', 'user/v2_user_2.7.0.json'),
      (false, '$_root/api/v1/user', 'user/v1_user_2.7.0.json'),
    ]) {
      test('reads $url', () async {
        final dio = fakeDio({url: fixture(fixtureName)});

        final user = await AccountApi(
          dio,
          _connection(hasV2: hasV2),
        ).currentUser();

        expect(user, const User(id: 5, username: 'usrd7253b34'));
        expect(user.displayName, 'usrd7253b34');
        expect(adapterOf(dio).requests.single.method, 'GET');
      });
    }

    test('keeps name and email when the server sends them', () async {
      final dio = fakeDio({
        '$_root/api/v2/user': json({
          'id': 9,
          'username': 'dora',
          'name': 'Dora Explorer',
          'email': 'dora@example.com',
        }),
      });

      final user = await AccountApi(
        dio,
        _connection(hasV2: true),
      ).currentUser();

      expect(
        user,
        const User(
          id: 9,
          username: 'dora',
          name: 'Dora Explorer',
          email: 'dora@example.com',
        ),
      );
      expect(user.displayName, 'Dora Explorer');
    });

    for (final body in [
      {'username': 'no-id'},
      {'id': '5', 'username': 'string-id'},
      {'id': 5},
    ]) {
      test('rejects $body', () async {
        final dio = fakeDio({'$_root/api/v2/user': json(body)});

        await expectLater(
          AccountApi(dio, _connection(hasV2: true)).currentUser(),
          throwsA(isA<UnexpectedResponse>()),
        );
      });
    }

    test('a non-object body is unexpected', () async {
      final dio = fakeDio({
        '$_root/api/v2/user': json([1]),
      });

      await expectLater(
        AccountApi(dio, _connection(hasV2: true)).currentUser(),
        throwsA(isA<UnexpectedResponse>()),
      );
    });

    test('errors are normalized', () async {
      final dio = fakeDio({
        '$_root/api/v2/user': errorFixture('v2_401_code11_missing_2.7.0'),
      });

      await expectLater(
        AccountApi(dio, _connection(hasV2: true)).currentUser(),
        throwsA(isA<TokenRejected>()),
      );
    });

    test('network failures are normalized', () async {
      await expectLater(
        AccountApi(fakeDio({}), _connection(hasV2: true)).currentUser(),
        throwsA(isA<NetworkFailure>()),
      );
    });
  });

  group('logout', () {
    for (final (hasV2, url) in [
      (true, '$_root/api/v2/logout'),
      (false, '$_root/api/v1/user/logout'),
    ]) {
      test('posts to $url', () async {
        final dio = fakeDio({
          url: json({'message': 'Successfully logged out.'}),
        });

        await AccountApi(dio, _connection(hasV2: hasV2)).logout();

        expect(adapterOf(dio).requests.single.method, 'POST');
      });
    }

    test('errors are normalized', () async {
      final dio = fakeDio({
        '$_root/api/v2/logout': errorFixture('v2_401_code11_garbage_2.7.0'),
      });

      await expectLater(
        AccountApi(dio, _connection(hasV2: true)).logout(),
        throwsA(isA<TokenRejected>()),
      );
    });
  });
}
