import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/vikunja_app.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/oauth_client.dart';
import 'package:vikunja_mobile/core/auth/web_authenticator.dart';
import 'package:vikunja_mobile/core/links/external_link_opener.dart';
import 'package:vikunja_mobile/core/network/dio_factory.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/features/home/application/app_version.dart';
import 'package:vikunja_mobile/features/home/presentation/home_shell.dart';
import 'package:vikunja_mobile/features/notifications/application/notifications_onboarding.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_server_screen.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/server_overview_screen.dart';

import '../helpers/auth_fakes.dart';
import '../helpers/fakes.dart';
import '../helpers/notification_ui_fakes.dart';
import '../helpers/pump_app.dart';
import '../helpers/sync_fakes.dart';

// Everything from the overview button to the token storage is the production
// code: AuthorizationRequest, OAuthTokenClient, AccountApi,
// createAuthenticatedDio with its auth interceptor, the session manager and
// the providers. Only the HTTP transport (a Vikunja 2.7.0 imitation built from
// captured responses), the browser sheet and the platform storage are faked.

final Uri _root = Uri.parse('https://vikunja.example.com');
const _userId = 5;
const _username = 'taskuna-e2e';
const _name = 'Rurana Tester';

Map<String, Object?> _fixture(String path) => jsonDecode(
  File('../packages/vikunja_api/test/fixtures/$path').readAsStringSync(),
) as Map<String, Object?>;

String _base64Url(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

final class _Captured {
  const new(this.status, this.contentType, this.body);

  factory error(String name) {
    final capture = _fixture('errors/$name');
    final headers = capture['headers']! as Map<String, Object?>;
    return _Captured(
      capture['status']! as int,
      headers['content-type']! as String,
      capture['body']! as String,
    );
  }

  factory json(Object? body) =>
      _Captured(200, 'application/json', jsonEncode(body));

  final int status;
  final String contentType;
  final String body;
}

final class _Seen {
  const new({
    required this.method,
    required this.path,
    required this.status,
    this.bearer,
    this.body,
    this.storedRefreshToken,
  });

  final String method;
  final String path;
  final int status;
  final String? bearer;
  final Object? body;

  /// What the device had stored when the request arrived.
  final String? storedRefreshToken;

  @override
  String toString() => '$method $path $status';
}

final class _PendingCode {
  const new({
    required this.challenge,
    required this.clientId,
    required this.redirectUri,
  });

  final String challenge;
  final String clientId;
  final String redirectUri;
}

/// One user and at most one session, with the 2.7.0 rules for codes, PKCE,
/// refresh token rotation and bearer checks.
final class _FakeVikunja implements HttpClientAdapter {
  new({required this.storedRefreshToken});

  final String? Function() storedRefreshToken;
  final List<_Seen> seen = [];
  final _codes = <String, _PendingCode>{};
  final _acceptedAccessTokens = <String>{};
  final _hmac = Hmac(sha256, utf8.encode('jwt-secret-of-the-fake-server'));
  var _counter = 0;
  String? _sessionId;
  String? currentRefreshToken;
  String? currentAccessToken;

  bool get hasSession => _sessionId != null;

  /// The server's answer to `POST /oauth/authorize`, which the web app makes
  /// for the signed-in user before it redirects.
  String authorize(Map<String, String> query) {
    final code = _base64Url(
      sha256.convert(utf8.encode('code-${++_counter}')).bytes,
    );
    _codes[code] = _PendingCode(
      challenge: query['code_challenge']!,
      clientId: query['client_id']!,
      redirectUri: query['redirect_uri']!,
    );
    return code;
  }

  /// What a server restart with a new JWT secret, or a clock far ahead of
  /// the device, looks like to the app.
  void rejectIssuedAccessTokens() => _acceptedAccessTokens.clear();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bytes = requestStream == null
        ? const <int>[]
        : await requestStream.expand((chunk) => chunk).toList();
    final body = bytes.isEmpty ? null : jsonDecode(utf8.decode(bytes));
    final uri = options.uri;
    final header = options.headers['Authorization'] as String?;
    final bearer = header != null && header.startsWith('Bearer ')
        ? header.substring(7)
        : null;
    final route = '${options.method} ${uri.path}';
    final _Captured response;
    // The own avatar the account shows; [seen] is the session's log.
    if (uri.path.startsWith('/api/v2/avatar/')) {
      return ResponseBody.fromString(
        '<svg xmlns="http://www.w3.org/2000/svg"/>',
        200,
        headers: {
          Headers.contentTypeHeader: ['image/svg+xml'],
        },
      );
    }
    if (uri.origin != _root.origin) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'Connection refused',
        error: const SocketException('Connection refused'),
      );
    }
    response = switch (route) {
      'GET /api/v2/info' => _info('info_v2_2.7.0.json'),
      'GET /api/v1/info' => _info('info_v1_2.7.0.json'),
      'POST /api/v2/oauth/token' => _token(body! as Map<String, Object?>),
      'GET /api/v2/user' => _authorized(bearer, _user),
      'POST /api/v2/logout' => _authorized(bearer, _logout),
      _ => _Captured.error('v2_404_route_2.7.0.json'),
    };
    seen.add(
      _Seen(
        method: options.method,
        path: uri.path,
        status: response.status,
        bearer: bearer,
        body: body,
        storedRefreshToken: storedRefreshToken(),
      ),
    );
    return ResponseBody.fromString(
      response.body,
      response.status,
      headers: {
        Headers.contentTypeHeader: [response.contentType],
        'cache-control': ['no-store'],
      },
    );
  }

  @override
  void close({bool force = false}) {}

  _Captured _info(String fixture) =>
      _Captured.json({..._fixture(fixture), 'frontend_url': '$_root/'});

  _Captured _token(Map<String, Object?> body) {
    switch (body['grant_type']) {
      case 'authorization_code':
        final pending = _codes.remove(body['code']);
        if (pending == null) {
          return _Captured.error('v2_oauth_17004_code_used_2.7.0.json');
        }
        if (body['client_id'] != pending.clientId) {
          return _Captured.error('v2_oauth_17001_client_mismatch_2.7.0.json');
        }
        if (body['redirect_uri'] != pending.redirectUri) {
          return _Captured.error('v2_oauth_17002_redirect_mismatch_2.7.0.json');
        }
        final verifier = body['code_verifier']! as String;
        final challenge = _base64Url(
          sha256.convert(ascii.encode(verifier)).bytes,
        );
        if (challenge != pending.challenge) {
          return _Captured.error('v2_oauth_17006_pkce_mismatch_2.7.0.json');
        }
        _sessionId = 'f3b1c2d4-0000-4000-8000-${'$_counter'.padLeft(12, '0')}';
        return _issueTokens();
      case 'refresh_token':
        if (_sessionId == null ||
            body['refresh_token'] != currentRefreshToken) {
          return _Captured.error('v2_refresh_invalid_2.7.0.json');
        }
        return _issueTokens();
      default:
        return _Captured.error('v2_oauth_17007_grant_2.7.0.json');
    }
  }

  _Captured _issueTokens() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final header = _base64Url(utf8.encode('{"alg":"HS256","typ":"JWT"}'));
    final payload = _base64Url(
      utf8.encode(
        jsonEncode({
          'type': 1,
          'id': _userId,
          'username': _username,
          'is_admin': false,
          'iat': now,
          'exp': now + 600,
          'sid': _sessionId,
          'jti': '0d9c6a52-1f0e-4c39-9b6e-${'$_counter'.padLeft(12, '0')}',
        }),
      ),
    );
    final signature = _base64Url(
      _hmac.convert(utf8.encode('$header.$payload')).bytes,
    );
    final accessToken = '$header.$payload.$signature';
    final refreshToken = _base64Url(
      sha256.convert(utf8.encode('refresh-${++_counter}')).bytes,
    );
    _acceptedAccessTokens
      ..clear()
      ..add(accessToken);
    currentAccessToken = accessToken;
    currentRefreshToken = refreshToken;
    return _Captured.json({
      'access_token': accessToken,
      'token_type': 'bearer',
      'expires_in': 600,
      'refresh_token': refreshToken,
    });
  }

  _Captured _authorized(String? bearer, _Captured Function() handler) =>
      bearer != null && _acceptedAccessTokens.contains(bearer)
      ? handler()
      : _Captured.error('v2_401_code11_garbage_2.7.0.json');

  _Captured _user() => _Captured.json({
    ..._fixture('user/v2_user_2.7.0.json'),
    'id': _userId,
    'username': _username,
    'name': _name,
  });

  _Captured _logout() {
    _sessionId = null;
    currentRefreshToken = null;
    _acceptedAccessTokens.clear();
    return _Captured.json({'message': 'Successfully logged out.'});
  }
}

/// The system browser sheet showing Vikunja's `/oauth/authorize` page for a
/// user who signs in there.
final class _VikunjaWebApp implements WebAuthenticator {
  new(this._server);

  final _FakeVikunja _server;
  final List<Uri> opened = [];

  @override
  Future<Uri?> authenticate(
    Uri url, {
    required String callbackUrlScheme,
  }) async {
    opened.add(url);
    final query = url.queryParameters;
    final redirect = Uri.parse(query['redirect_uri']!);
    expect(callbackUrlScheme, redirect.scheme);
    final code = _server.authorize(query);
    return redirect.replace(
      queryParameters: {'code': code, 'state': query['state']},
    );
  }
}

/// Dio hops through zero-length timers, which only fire while a widget test
/// advances its fake clock.
Future<T> _whilePumping<T>(WidgetTester tester, Future<T> future) async {
  var done = false;
  unawaited(
    future.then<void>((_) => done = true, onError: (Object _) => done = true),
  );
  for (var round = 0; round < 100 && !done; round++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  if (!done) fail('call did not complete within 5 s of fake time');
  return await future;
}

void main() {
  testWidgets(
    'browser sign-in, refresh after rejected tokens, restart, sign-out',
    (tester) async {
      usePhoneSurface(tester, logicalSize: const Size(400, 1600));
      final secureStore = MemorySecureStore();
      // The notification setup is not this test's story either.
      final preferences = MemoryPreferencesStore()
        ..values[notificationsOnboardedKey] = 'true';
      final accountId = accountIdFor(_root, _userId);
      final refreshTokenKey = 'account.$accountId.refresh_token';
      final accessTokenKey = 'account.$accountId.access_token';
      final server = _FakeVikunja(
        storedRefreshToken: () => secureStore.values[refreshTokenKey],
      );
      final webApp = _VikunjaWebApp(server);

      Future<void> launch() async {
        final dio = createDio(
          userAgent: 'Rurana/0.1.0 test',
          httpClientAdapter: server,
          logRequests: false,
        );
        addTearDown(dio.close);
        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [
              appVersionProvider.overrideWithValue(testAppVersion),
              dioProvider.overrideWithValue(dio),
              authDioProvider.overrideWithValue(dio),
              secureStoreProvider.overrideWithValue(secureStore),
              preferencesStoreProvider.overrideWithValue(preferences),
              webAuthenticatorProvider.overrideWithValue(webApp),
              externalLinkOpenerProvider.overrideWithValue(
                FakeExternalLinkOpener(),
              ),
              // The task screens are not this test's story.
              ...SyncFakes().overrides,
              ...NotificationFakes().overrides,
            ],
            child: const VikunjaApp(),
          ),
        );
        await tester.pumpAndSettle();
      }

      List<String> routesSince(int index) => [
        for (final request in server.seen.skip(index)) '$request',
      ];

      await launch();
      await tester.enterText(find.byType(TextFormField), _root.host);
      await tester.tap(find.widgetWithText(FilledButton, en.connectContinue));
      await tester.pumpAndSettle();
      expect(find.byType(ServerOverviewScreen), findsOneWidget);

      final beforeSignIn = server.seen.length;
      await tester.tap(find.widgetWithText(FilledButton, en.continueToSignIn));
      await tester.pumpAndSettle();

      expect(find.byType(HomeShell), findsOneWidget);
      await openTab(tester, en.tabAccount);
      expect(find.text(_name), findsOneWidget);
      expect(
        find.text(en.accountSubtitle(_username, _root.host)),
        findsOneWidget,
      );

      final authorizeUrl = webApp.opened.single;
      expect(
        authorizeUrl.replace(query: '').toString(),
        '$_root/oauth/authorize?',
      );
      expect(authorizeUrl.queryParameters, {
        'response_type': 'code',
        'client_id': 'dev.coderoftime.vikunja',
        'redirect_uri': 'vikunja-dev.coderoftime.vikunja://oauth/callback',
        'state': hasLength(22),
        'code_challenge': hasLength(43),
        'code_challenge_method': 'S256',
      });
      expect(routesSince(beforeSignIn), [
        'POST /api/v2/oauth/token 200',
        'GET /api/v2/user 200',
      ]);
      final signInTokens = server.currentAccessToken;
      expect(server.seen.last.bearer, signInTokens);
      // GET /user ran before anything was stored: an account is only kept
      // once the server confirmed who it is.
      expect(server.seen.last.storedRefreshToken, isNull);
      expect(secureStore.values, {
        refreshTokenKey: server.currentRefreshToken,
        accessTokenKey: signInTokens,
      });

      final container = containerOf(tester);
      final entry = (await container.read(accountsProvider.future))
          .activeAccount!;
      final signInRefreshToken = server.currentRefreshToken;
      server.rejectIssuedAccessTokens();
      final beforeRefresh = server.seen.length;
      // A later feature screen fetches through the same gateway and session.
      final user = await _whilePumping(
        tester,
        container
            .read(accountGatewayProvider)
            .currentUser(
              entry.connection,
              container.read(sessionManagersProvider).forAccount(entry.id),
            ),
      );

      expect(user.name, _name);
      expect(routesSince(beforeRefresh), [
        'GET /api/v2/user 401',
        'POST /api/v2/oauth/token 200',
        'GET /api/v2/user 200',
      ]);
      final [rejected, refresh, repeated] = server.seen
          .skip(beforeRefresh)
          .toList();
      expect(rejected.bearer, signInTokens);
      expect(refresh.body, {
        'grant_type': 'refresh_token',
        'refresh_token': signInRefreshToken,
      });
      expect(repeated.bearer, server.currentAccessToken);
      expect(repeated.bearer, isNot(signInTokens));
      // Write-ahead: the rotated refresh token was stored before the new
      // access token was used.
      expect(repeated.storedRefreshToken, server.currentRefreshToken);
      expect(secureStore.values, {
        refreshTokenKey: server.currentRefreshToken,
        accessTokenKey: server.currentAccessToken,
      });

      final beforeRestart = server.seen.length;
      await launch();
      expect(find.byType(HomeShell), findsOneWidget);
      await openTab(tester, en.tabAccount);
      expect(find.text(_name), findsOneWidget);
      // Home is shown from storage; the session check follows it.
      expect(routesSince(beforeRestart), ['GET /api/v2/user 200']);

      // After the restart the stored access token is rejected as well, so
      // logging out needs the interceptor's refresh and repeat.
      final storedBeforeSignOut = server.currentAccessToken;
      final refreshTokenBeforeSignOut = server.currentRefreshToken;
      server.rejectIssuedAccessTokens();
      final beforeSignOut = server.seen.length;
      await tester.tap(find.widgetWithText(OutlinedButton, en.homeSignOut));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(TextButton, en.signOutDialogConfirm),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ConnectServerScreen), findsOneWidget);
      expect(routesSince(beforeSignOut), [
        'POST /api/v2/logout 401',
        'POST /api/v2/oauth/token 200',
        'POST /api/v2/logout 200',
      ]);
      final [rejectedLogout, signOutRefresh, repeatedLogout] = server.seen
          .skip(beforeSignOut)
          .toList();
      expect(rejectedLogout.bearer, storedBeforeSignOut);
      expect(signOutRefresh.body, {
        'grant_type': 'refresh_token',
        'refresh_token': refreshTokenBeforeSignOut,
      });
      expect(repeatedLogout.bearer, isNot(storedBeforeSignOut));
      expect(server.hasSession, isFalse);
      expect(secureStore.values, isEmpty);
      expect((await AccountRegistry(preferences).load()).accounts, isEmpty);
    },
  );
}
