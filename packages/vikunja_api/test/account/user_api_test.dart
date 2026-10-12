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

  group('currentUserWithSettings', () {
    for (final (hasV2, url, fixtureName) in [
      (true, '$_root/api/v2/user', 'user/v2_user_2.7.0.json'),
      (false, '$_root/api/v1/user', 'user/v1_user_2.7.0.json'),
    ]) {
      test('reads the settings of $url', () async {
        final dio = fakeDio({url: fixture(fixtureName)});

        final (:user, :settings) = await AccountApi(
          dio,
          _connection(hasV2: hasV2),
        ).currentUserWithSettings();

        expect(user, const User(id: 5, username: 'usrd7253b34'));
        expect(
          settings,
          const UserSettings(defaultProjectId: 6, timezone: 'GMT'),
        );
        expect(adapterOf(dio).requests, hasLength(1));
      });
    }

    test('reads the quick-add settings the web stores', () async {
      final dio = fakeDio({
        '$_root/api/v2/user': json({
          'id': 9,
          'username': 'dora',
          'settings': {
            'default_project_id': 0,
            'week_start': 1,
            'frontend_settings': {
              'quick_add_magic_mode': 'disabled',
              'quick_add_default_reminders': [
                {'relative_period': -3600, 'relative_to': 'due_date'},
              ],
            },
          },
        }),
      });

      final (:user, :settings) = await AccountApi(
        dio,
        _connection(hasV2: true),
      ).currentUserWithSettings();

      expect(user.username, 'dora');
      expect(
        settings,
        const UserSettings(
          weekStart: 1,
          quickAddMagicMode: QuickAddMagicMode.disabled,
          quickAddDefaultReminders: [Duration(hours: -1)],
        ),
      );
    });

    test('a user without settings has the defaults', () async {
      final dio = fakeDio({
        '$_root/api/v2/user': json({'id': 9, 'username': 'dora'}),
      });

      final (:user, :settings) = await AccountApi(
        dio,
        _connection(hasV2: true),
      ).currentUserWithSettings();

      expect(user.id, 9);
      expect(settings, const UserSettings());
    });

    test('odd settings do not fail the user', () async {
      final dio = fakeDio({
        '$_root/api/v2/user': json({
          'id': 9,
          'username': 'dora',
          'settings': 'nonsense',
        }),
      });

      final (:settings, user: _) = await AccountApi(
        dio,
        _connection(hasV2: true),
      ).currentUserWithSettings();

      expect(settings, const UserSettings());
    });

    test('a body that is not a user is unexpected', () async {
      final dio = fakeDio({
        '$_root/api/v2/user': json({
          'username': 'no-id',
          'settings': {'default_project_id': 3},
        }),
      });

      await expectLater(
        AccountApi(dio, _connection(hasV2: true)).currentUserWithSettings(),
        throwsA(isA<UnexpectedResponse>()),
      );
    });

    test('network failures are normalized', () async {
      await expectLater(
        AccountApi(
          fakeDio({}),
          _connection(hasV2: true),
        ).currentUserWithSettings(),
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
