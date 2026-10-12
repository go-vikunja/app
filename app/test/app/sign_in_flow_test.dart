import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/vikunja_app.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/oauth_client.dart';
import 'package:vikunja_mobile/core/links/external_link_opener.dart';
import 'package:vikunja_mobile/core/network/client_identity.dart';
import 'package:vikunja_mobile/core/network/dio_factory.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/home/presentation/home_shell.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_server_screen.dart';

import '../helpers/auth_fakes.dart';
import '../helpers/fakes.dart';
import '../helpers/notification_ui_fakes.dart';
import '../helpers/pump_app.dart';
import '../helpers/sync_fakes.dart';

// Runs sign-in and sign-out through the real gateways, OAuthTokenClient,
// AccountApi and auth interceptor; only the HTTP transport, the browser
// sheet and the platform storage are faked.

const _identity = ClientIdentity(
  appVersion: '0.1.0',
  buildNumber: '1',
  platform: 'ios',
  osVersion: '26.5',
);

const _root = 'https://vikunja.example.com';

String _fixture(String name) =>
    File('../packages/vikunja_api/test/fixtures/$name').readAsStringSync();

typedef _Handler = (int, Object?) Function(
  RequestOptions options,
  Object? body,
);

final class _ServerAdapter implements HttpClientAdapter {
  new(this.routes);

  final Map<String, _Handler> routes;
  final List<(RequestOptions, Object?)> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bytes = requestStream == null
        ? null
        : await requestStream.expand((chunk) => chunk).toList();
    final body = bytes == null || bytes.isEmpty
        ? null
        : jsonDecode(utf8.decode(bytes));
    requests.add((options, body));
    final handler = routes['${options.method} ${options.uri}'];
    if (handler == null) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'Connection refused',
        error: const SocketException('Connection refused'),
      );
    }
    final (status, json) = handler(options, body);
    return ResponseBody.fromBytes(
      utf8.encode(json is String ? json : jsonEncode(json)),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  testWidgets('connect, sign in, restart signed in, sign out', (tester) async {
    usePhoneSurface(tester, logicalSize: const Size(400, 1600));
    final now = DateTime.now().toUtc();
    final tokens = issueTokens(issuedAt: now, refreshToken: 'a1' * 128);
    String? bearer(RequestOptions options) =>
        options.headers['Authorization'] as String?;

    final adapter = _ServerAdapter({
      'GET $_root/api/v2/info': (_, _) => (200, _fixture('info_v2_2.7.0.json')),
      'GET $_root/api/v1/info': (_, _) => (200, _fixture('info_v1_2.7.0.json')),
      'POST $_root/api/v2/oauth/token': (options, body) => (
        200,
        {
          'access_token': tokens.accessToken,
          'token_type': 'bearer',
          'expires_in': 600,
          'refresh_token': tokens.refreshToken,
        },
      ),
      'GET $_root/api/v2/user': (options, _) =>
          bearer(options) == 'Bearer ${tokens.accessToken}'
          ? (200, {'id': 7, 'username': 'alice', 'name': 'Alice Example'})
          : (401, {'code': 11, 'message': 'invalid token'}),
      'POST $_root/api/v2/logout': (options, _) =>
          bearer(options) == 'Bearer ${tokens.accessToken}'
          ? (200, {'message': 'Successfully logged out.'})
          : (401, {'code': 11, 'message': 'invalid token'}),
    });
    final auth = AuthFakes();
    // A new account: the first full sync runs before home shows.
    final sync = SyncFakes(status: const SyncNeverRun());

    Future<void> launch() async {
      final dio = createDio(
        userAgent: _identity.userAgent,
        httpClientAdapter: adapter,
        logRequests: false,
      );
      addTearDown(dio.close);
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            dioProvider.overrideWithValue(dio),
            authDioProvider.overrideWithValue(dio),
            externalLinkOpenerProvider.overrideWithValue(
              FakeExternalLinkOpener(),
            ),
            secureStoreProvider.overrideWithValue(auth.secureStore),
            preferencesStoreProvider.overrideWithValue(auth.preferences),
            webAuthenticatorProvider.overrideWithValue(auth.webAuthenticator),
            ...sync.overrides,
            ...NotificationFakes().overrides,
          ],
          child: const VikunjaApp(),
        ),
      );
      await tester.pumpAndSettle();
    }

    await launch();
    await tester.enterText(find.byType(TextFormField), 'vikunja.example.com');
    await tester.tap(find.widgetWithText(FilledButton, en.connectContinue));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, en.continueToSignIn));
    await tester.pumpAndSettle();

    expect(find.byType(HomeShell), findsOneWidget);
    expect(sync.engine.ensureInitialSyncCalls, 1);
    await openTab(tester, en.tabAccount);
    expect(find.text('Alice Example'), findsOneWidget);
    final authorizeUrl = auth.webAuthenticator.urls.single;
    // The captured /info fixture advertises the Docker test server's http
    // frontend_url, which an https server's sign-in never downgrades to.
    expect(authorizeUrl.origin, _root);
    expect(authorizeUrl.path, '/oauth/authorize');
    final (_, exchange) = adapter.requests.firstWhere(
      (request) => request.$1.uri.path == '/api/v2/oauth/token',
    );
    expect(exchange, {
      'grant_type': 'authorization_code',
      'code': 'auth-code',
      'client_id': appOAuthClient.clientId,
      'redirect_uri': appOAuthClient.redirectUri.toString(),
      'code_verifier': isNotEmpty,
    });
    final accountId = accountIdFor(Uri.parse(_root), 7);
    expect(
      auth.secureStore.values['account.$accountId.refresh_token'],
      tokens.refreshToken,
    );

    // A cold start restores the account before any request; once home is
    // shown, the session is checked in the background.
    adapter.requests.clear();
    await launch();
    expect(find.byType(HomeShell), findsOneWidget);
    await openTab(tester, en.tabAccount);
    expect(find.text('Alice Example'), findsOneWidget);
    expect(adapter.requests.map((r) => '${r.$1.method} ${r.$1.uri.path}'), [
      'GET /api/v2/user',
    ]);

    adapter.requests.clear();
    await tester.tap(find.widgetWithText(OutlinedButton, en.homeSignOut));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, en.signOutDialogConfirm));
    await tester.pumpAndSettle();

    expect(find.byType(ConnectServerScreen), findsOneWidget);
    expect(adapter.requests.map((r) => '${r.$1.method} ${r.$1.uri.path}'), [
      'POST /api/v2/logout',
    ]);
    expect(auth.secureStore.values, isEmpty);
    expect((await auth.registry.load()).accounts, isEmpty);
    expect(sync.files.deleted, [accountId]);
    expect(sync.engine.disposed, isTrue);
  });
}
