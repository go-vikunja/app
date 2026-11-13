import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/bootstrap/logging_setup.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/link_share_gateway.dart';
import 'package:vikunja_mobile/core/auth/link_share_providers.dart';
import 'package:vikunja_mobile/core/auth/session_manager.dart';
import 'package:vikunja_mobile/core/auth/token_store.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/links/widget_link.dart';
import 'package:vikunja_mobile/core/links/widget_link_key.dart';
import 'package:vikunja_mobile/core/network/client_identity.dart';
import 'package:vikunja_mobile/core/network/dio_factory.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/core/network/request_log_interceptor.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/notifications/notification_actions.dart';
import 'package:vikunja_mobile/core/outbox/failure_json.dart';
import 'package:vikunja_mobile/core/platform/background_permissions.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/about/application/support_details.dart';
import 'package:vikunja_mobile/features/onboarding/application/connect_server_controller.dart';

import '../helpers/auth_fakes.dart';
import '../helpers/fakes.dart';
import '../helpers/guest_entry_fakes.dart';
import '../helpers/guest_fakes.dart';
import '../helpers/notification_fakes.dart';
import '../helpers/sample_data.dart';
import '../helpers/server_connections.dart';
import '../helpers/sync_fakes.dart';
import '../helpers/test_database.dart';
import '../helpers/tls_fixtures.dart';

// Every secret shaped like the real one, and personal data that must not
// reach a printed line. The paths run with every logger on and the debug
// console sink installed; the release build prints nothing at all.
final _now = DateTime.utc(2026, 10, 27, 12);
final ServerConnection _server = fullServer270();
const _base = 'https://tasks.example.org/vikunja/';

String _refreshMarker(int n) => '${n}e' * 128;

final _hash = '${'sHaReHaSh' * 4}Mk01';
const _sharePassword = 'Pw-MARKER_PW-1';
final _inviteToken = '${'Inv1te' * 10}Tokn';
final _apiToken = 'tk_${'feed' * 10}';
final String _caldavToken = 'Cd4v' * 16;
const _title = 'Garden TITLE-MARKER plan';
const _email = 'marker.user@example.com';

final class _StubServer implements HttpClientAdapter {
  new(this.handle);

  FutureOr<ResponseBody> Function(RequestOptions options) handle;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => Future.sync(() => handle(options));

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object body) => ResponseBody.fromString(
  body is String ? body : jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

String? _bearerOf(RequestOptions options) =>
    switch (options.headers['Authorization']) {
      final String header when header.startsWith('Bearer ') => header.substring(
        7,
      ),
      _ => null,
    };

final class _NoBackgroundState implements BackgroundPermissions {
  @override
  Future<BackgroundState> read() async => const BackgroundState();
}

final class _FixedToken implements AccessTokenSource {
  new(this.token);

  final String token;

  @override
  Future<String> validAccessToken() async => token;

  @override
  Future<String?> refreshAfterRejection(String rejectedToken) async => null;
}

void main() {
  late List<LogRecord> records;
  late List<String> lines;

  void capture({required bool printToConsole}) {
    final debugPrintBefore = debugPrint;
    final flutterErrorBefore = FlutterError.onError;
    final uncaughtBefore = PlatformDispatcher.instance.onError;
    final levelBefore = Logger.root.level;
    records = [];
    lines = [];
    debugPrint = (message, {wrapWidth}) => lines.add(message ?? '');
    final subscription = Logger.root.onRecord.listen(records.add);
    configureLogging(printToConsole: printToConsole);
    addTearDown(() async {
      resetLoggingForTest();
      await subscription.cancel();
      debugPrint = debugPrintBefore;
      FlutterError.onError = flutterErrorBefore;
      PlatformDispatcher.instance.onError = uncaughtBefore;
      Logger.root.level = levelBefore;
    });
  }

  // Also what goes through `print` instead of `debugPrint`.
  Future<T> printing<T>(Future<T> Function() body) => runZoned(
    body,
    zoneSpecification: ZoneSpecification(
      print: (_, _, _, line) => lines.add(line),
    ),
  );

  // As if no caller caught it: the worst case for an error's text.
  void reportUncaught(Object error, [StackTrace? stack]) {
    final trace = stack ?? StackTrace.current;
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: trace),
    );
    expect(PlatformDispatcher.instance.onError!(error, trace), isTrue);
  }

  // Every 20 characters of a value too: an excerpt can cut it off.
  Iterable<String> piecesOf(Iterable<String> values) => {
    for (final value in values) ...[
      value,
      for (var i = 0; i + 20 <= value.length; i += 10)
        value.substring(i, i + 20),
    ],
  };

  void expectNowhere(Iterable<String> secrets) {
    final pieces = piecesOf(secrets);
    for (final record in records) {
      for (final piece in pieces) {
        expect(record.message, isNot(contains(piece)));
        expect('${record.error}', isNot(contains(piece)));
      }
    }
    final output = lines.join('\n');
    for (final piece in pieces) {
      expect(output, isNot(contains(piece)));
    }
  }

  void expectNotPrinted(Iterable<String> personal) {
    final output = lines.join('\n');
    for (final piece in piecesOf(personal)) {
      expect(output, isNot(contains(piece)));
    }
  }

  group('with the debug console sink', () {
    setUp(() => capture(printToConsole: true));

    test('the transport and the token refresh never log a token, also when '
        'what they throw is never caught', () async {
      final secureStore = MemorySecureStore();
      final tokenStore = TokenStore(secureStore);
      final first = issueTokens(
        issuedAt: _now,
        refreshToken: _refreshMarker(0),
      );
      final rotated = issueTokens(
        issuedAt: _now,
        refreshToken: _refreshMarker(1),
      );
      final failing = issueTokens(
        issuedAt: _now.subtract(const Duration(hours: 1)),
        refreshToken: _refreshMarker(2),
      );
      final throwing = issueTokens(
        issuedAt: _now.subtract(const Duration(hours: 1)),
        refreshToken: _refreshMarker(3),
      );
      final guest = issueLinkShareToken(issuedAt: _now).jwt;
      final access = tlsAccessValues().values;
      await tokenStore.write('a1', first);
      await tokenStore.write('a2', failing);
      await tokenStore.write('a3', throwing);

      final ended = <SessionEnded>[];
      var failingRefreshes = 0;
      SessionManager manager(String accountId) => SessionManager(
        accountId: accountId,
        tokenStore: tokenStore,
        refresh: (refreshToken) async {
          if (refreshToken == first.refreshToken) return rotated;
          if (refreshToken == failing.refreshToken) {
            if (failingRefreshes++ == 0) {
              throw ServerFailure(500, message: 'cannot use $refreshToken');
            }
            throw SessionEnded(
              SessionEndReason.invalidRefreshToken,
              code: 16002,
              message: 'refresh token $refreshToken is unknown',
            );
          }
          throw Exception(
            'refresh failed for {"refresh_token":"$refreshToken"} with '
            'Authorization: Bearer ${throwing.accessToken}',
          );
        },
        onSessionEnded: (failure) async => ended.add(failure),
        clock: () => _now,
        sleep: (_) async {},
      );

      final server = _StubServer((options) {
        final path = options.uri.path;
        final bearer = _bearerOf(options);
        if (path.endsWith('/tasks/1')) {
          return bearer == first.accessToken
              ? _json(401, {'code': 11, 'message': 'invalid token $bearer'})
              : _json(200, {'id': 1, 'title': _title});
        }
        if (path.endsWith('/tasks/2')) {
          return _json(500, {
            'message': 'echo',
            'authorization': 'Bearer $bearer',
            'refresh_token': rotated.refreshToken,
            'hash': _hash,
            'password': _sharePassword,
            'email': _email,
            'title': _title,
            'tokens': [_apiToken, _caldavToken, _inviteToken],
            'access': [...access, tlsFixturePassword],
          });
        }
        if (path.endsWith('/tasks/3')) {
          throw SocketException(
            'Connection reset for $_base/api/v2/tasks/3?token=$bearer, '
            'Authorization: Bearer $bearer',
          );
        }
        if (path.endsWith('/tasks/4')) {
          return _json(
            200,
            '{"access_token":"$bearer","refresh_token":'
            '"${rotated.refreshToken}","token":"$_apiToken","caldav":',
          );
        }
        if (path.endsWith('/tasks/8')) {
          return _json(401, {'message': 'Unauthorized'});
        }
        return _json(200, {'ok': true, 'email': _email});
      });
      final base = createDio(
        userAgent: 'Vikunja-App/test',
        httpClientAdapter: server,
      );
      addTearDown(base.close);
      final gone = <LinkShareGone>[];
      Dio clientFor(AccessTokenSource tokens) => createAuthenticatedDio(
        base: base,
        connection: _server,
        tokens: tokens,
        retry: (dio) => RetryInterceptor(dio, delay: (_) async {}),
        interceptors: [
          LinkShareGoneInterceptor(onGone: gone.add),
          RequestLogInterceptor(),
        ],
      );
      final user = clientFor(manager('a1'));
      final errors = <(Object, StackTrace)>[];
      Future<void> request(Dio dio, String path) async {
        try {
          await dio.get<Object?>(path);
        } on DioException catch (error, stack) {
          errors.add((error, stack));
        }
      }

      await printing(() async {
        await request(user, 'tasks/1');
        await request(user, 'tasks/2');
        await request(user, 'tasks/3');
        await request(user, 'tasks/4');
        await request(
          user,
          'tasks/5?token=${rotated.accessToken}&hash=$_hash&email=$_email',
        );
        await request(clientFor(manager('a2')), 'tasks/6');
        await request(clientFor(manager('a3')), 'tasks/7');
        await request(clientFor(_FixedToken(guest)), 'tasks/8');

        for (final (error, stack) in errors) {
          reportUncaught(error, stack);
          reportUncaught(normalizeError(error), stack);
        }
        const task = Task(id: 1, title: _title, projectId: 2);
        final account = Account(
          id: 'a1',
          serverRoot: _server.rootUri,
          userId: 7,
          username: _email,
          displayName: 'Marker User',
          addedAt: _now,
        );
        reportUncaught(StateError('unexpected $task of $account'));
      });

      expect(errors, hasLength(6));
      expect(ended.map((e) => e.reason), [
        SessionEndReason.invalidRefreshToken,
      ]);
      expect(gone, hasLength(1));
      expect(
        records.map((r) => r.loggerName).toSet(),
        containsAll(<String>{'http', 'SessionManager', 'Flutter', 'Uncaught'}),
      );
      expectNowhere([
        for (final tokens in [first, rotated, failing, throwing]) ...[
          tokens.accessToken,
          tokens.refreshToken,
        ],
        guest,
        _hash,
        _sharePassword,
        _inviteToken,
        _apiToken,
        _caldavToken,
        ...access,
        tlsFixturePassword,
      ]);
      expectNotPrinted([_title, _email]);
    });

    test('a pasted share link with a password, and an invite, never log '
        'the hash, the guest token, the password or the invite', () async {
      final guest = issueLinkShareToken(issuedAt: _now);
      final passwords = <String?>[];
      final server = _StubServer((options) {
        final body = options.data;
        final password = body is Map ? body['password'] as String? : null;
        passwords.add(password);
        return switch (password) {
          null => _json(412, {'code': 13001, 'message': 'needs a password'}),
          _sharePassword => _json(200, {
            'token': guest.jwt,
            'project_id': 1378,
            'id': 84,
            'hash': _hash,
            'permission': 0,
          }),
          _ => _json(403, {
            'code': 13002,
            'message': 'wrong password $password for $_hash',
          }),
        };
      });
      final authDio = createDio(
        userAgent: 'Vikunja-App/test',
        httpClientAdapter: server,
      );
      addTearDown(authDio.close);
      final auth = AuthFakes();
      final invites = FakeInviteLinksPort()
        ..onCheck = (token) async => throw FormatException(
          'Unexpected token',
          '{"invite":"$token","email":"$_email"}',
        );
      final container = ProviderContainer.test(
        overrides: [
          secureStoreProvider.overrideWithValue(auth.secureStore),
          preferencesStoreProvider.overrideWithValue(auth.preferences),
          webAuthenticatorProvider.overrideWithValue(auth.webAuthenticator),
          tokenGatewayProvider.overrideWithValue(auth.tokenGateway),
          accountGatewayProvider.overrideWithValue(auth.accountGateway),
          linkShareGatewayProvider.overrideWithValue(
            ApiLinkShareGateway(authDio),
          ),
          ...SyncFakes().overrides,
          serverConnectorProvider.overrideWithValue(
            FakeServerConnector.succeeding(_server),
          ),
          ...guestEntryOverrides(invites: invites),
        ],
      )..listen(connectServerControllerProvider, (_, _) {});
      final controller = container.read(
        connectServerControllerProvider.notifier,
      );

      await printing(() async {
        await controller.connect(
          'Our plan: ${_base}share/$_hash/auth?view=12 – enjoy',
        );
        expect(
          container.read(connectServerControllerProvider),
          isA<ConnectServerSharePasswordNeeded>(),
        );
        expect(
          await controller.submitSharePassword('$_sharePassword-wrong'),
          SharePasswordOutcome.wrong,
        );
        expect(
          await controller.submitSharePassword(_sharePassword),
          SharePasswordOutcome.accepted,
        );
        await controller.connect('${_base}register#invite-link=$_inviteToken');
        reportUncaught(
          Exception(
            'could not open ${_base}register#invite-link=$_inviteToken',
          ),
        );
        reportUncaught(
          Exception(
            'could not open ${_base}share/x/auth#share-auth-token=$_hash',
          ),
        );
      });

      expect(passwords, [null, '$_sharePassword-wrong', _sharePassword]);
      expect(invites.checkedTokens, [_inviteToken]);
      expect(records, isNotEmpty);
      expectNowhere([_hash, _sharePassword, _inviteToken, guest.jwt]);
      expectNotPrinted([_email]);
    });

    test('the widget-link key of widget links and notification taps is '
        'never printed', () async {
      final key = newWidgetLinkKey();
      final link = WidgetTaskLink(
        accountId: 'a1',
        taskId: 3,
        linkKey: key,
      ).toUri();
      final payload = NotificationPayload(
        accountId: 'a1',
        taskId: 3,
        key: 'task:3',
        linkKey: key,
      ).toJson();

      await printing(() async {
        Object? unreadable;
        try {
          NotificationPayload.fromJson(
            payload.replaceFirst('"task":3', '"task":"3"'),
          );
        } on FormatException catch (error) {
          unreadable = error;
        }
        reportUncaught(unreadable!);
        reportUncaught(Exception('could not open $link'));
        reportUncaught(StateError('no task for $payload'));
      });

      expect(records, hasLength(6));
      expect(WidgetLink.parse(link)?.linkKey, key);
      expectNowhere([key]);
    });

    test('an uncaught FormatException quoting a token is printed '
        'redacted', () async {
      final tokens = issueTokens(
        issuedAt: _now,
        refreshToken: _refreshMarker(4),
      );

      await printing(() async {
        reportUncaught(
          FormatException(
            'Unexpected character',
            '{"access_token":"${tokens.accessToken}",'
                '"refresh_token":"${tokens.refreshToken}"}',
          ),
        );
        reportUncaught(
          FormatException(
            'Bad refresh',
            'grant_type=refresh_token&refresh_token=${tokens.refreshToken}',
            20,
          ),
        );
      });

      expect(lines, isNotEmpty);
      expect(lines.join('\n'), contains('[redacted]'));
      expectNowhere([tokens.accessToken, tokens.refreshToken]);
    });
  });

  test('the support details hold no secret, name, title, message or '
      'setting, and a server address only when asked for', () async {
    capture(printToConsole: true);
    final auth = AuthFakes();
    const host = 'tasks.leak-host.example';
    final info = ServerInfo(
      version: ServerVersion.tryParse('v2.8.0'),
      rawVersion: 'v2.8.0',
      motd: 'MOTD-MARKER maintenance tonight',
      frontendUrl: Uri.parse('https://frontend-marker.example/web'),
      linkSharingEnabled: true,
    );
    const apis = {ApiVersion.v1, ApiVersion.v2};
    final connection = ServerConnection(
      rootUri: Uri.parse(
        'https://HOSTUSER:HOSTPASSWORD@$host/vik?q=QUERY-MARKER#FRAGMENT',
      ),
      apiVersions: apis,
      info: info,
      capabilities: ServerCapabilities.derive(info: info, apiVersions: apis),
    );
    final tokens = issueTokens(
      issuedAt: _now,
      username: _email,
      refreshToken: _refreshMarker(6),
    );
    final user = await auth.seedAccount(
      connection,
      tokens: tokens,
      displayName: 'DISPLAY-NAME-MARKER',
    );
    final guestToken = issueLinkShareToken(issuedAt: _now);
    final guest = await auth.seedGuest(
      connection,
      token: guestToken,
      displayName: 'GUEST-NAME-MARKER',
      shareName: 'SHARE-NAME-MARKER',
      activate: false,
    );
    final databases = <String, AppDatabase>{};
    for (final entry in [user, guest]) {
      final db = databases[entry.id] = testDatabase();
      await db.projectsDao.upsertAll([
        sampleProject(id: 1, title: 'PROJECT-MARKER'),
      ]);
      await db.tasksDao.upsertAll([
        sampleTask(id: 1, title: _title),
      ], syncRunId: 'run');
      await db.syncStateDao.write({
        SyncStateKeys.lastSyncedAt: _now.toIso8601String(),
        SyncStateKeys.userSettings: jsonEncode({
          'name': 'SETTINGS-NAME-MARKER',
          'email': _email,
        }),
      });
      await db
          .into(db.outbox)
          .insert(
            OutboxCompanion.insert(
              id: 'op-1',
              sequence: 1,
              kind: 'updateTask',
              taskId: 1,
              payload: jsonEncode({'title': 'PAYLOAD-MARKER $_title'}),
              createdAt: _now,
              attempts: 1,
              state: 'failed',
              lastError: Value(
                encodeFailure(
                  const ValidationFailed(
                    code: 2002,
                    message: 'LAST-ERROR-MARKER',
                    fieldErrors: {
                      'title': ['FIELD-ERROR-MARKER'],
                    },
                  ),
                ),
              ),
            ),
          );
    }
    final container = ProviderContainer(
      overrides: [
        ...auth.overrides,
        clockProvider.overrideWithValue(() => _now),
        clientIdentityProvider.overrideWithValue(
          const ClientIdentity(
            appVersion: '1.0.0',
            buildNumber: '42',
            platform: 'android',
            osVersion: '14',
          ),
        ),
        notificationGatewayProvider.overrideWithValue(
          FakeNotificationGateway(),
        ),
        backgroundPermissionsProvider.overrideWithValue(_NoBackgroundState()),
        appDatabaseProvider.overrideWith(
          (ref, accountId) => databases[accountId]!,
        ),
      ],
    );
    addTearDown(container.dispose);

    final snapshot = await container.read(supportSnapshotProvider.future);
    final hidden = renderSupportDetails(
      snapshot,
      showServers: false,
      appLanguage: 'en',
    );
    final shown = renderSupportDetails(
      snapshot,
      showServers: true,
      appLanguage: 'en',
    );

    expect(hidden, contains('Kind: guest'));
    expect(hidden, contains('validation_failed code 2002'));
    expect(hidden, isNot(contains(host)));
    expect(shown, contains('Server: https://$host/vik\n'));
    final secrets = [
      tokens.accessToken,
      tokens.refreshToken,
      guestToken.jwt,
      fakeShareHash,
      _email,
      'marker.user',
      'DISPLAY-NAME-MARKER',
      'GUEST-NAME-MARKER',
      'SHARE-NAME-MARKER',
      'link-share-',
      _title,
      'PROJECT-MARKER',
      'PAYLOAD-MARKER',
      'LAST-ERROR-MARKER',
      'FIELD-ERROR-MARKER',
      'SETTINGS-NAME-MARKER',
      'MOTD-MARKER',
      'frontend-marker',
      'HOSTUSER',
      'HOSTPASSWORD',
      'QUERY-MARKER',
      'FRAGMENT',
      'Keycloak',
      user.id,
      guest.id,
    ];
    for (final text in [hidden, shown]) {
      for (final piece in piecesOf(secrets)) {
        expect(text, isNot(contains(piece)), reason: piece);
      }
    }
    expectNowhere(secrets);
  });

  test('a release build prints nothing for an uncaught error, whatever it '
      'quotes', () async {
    capture(printToConsole: false);
    final tokens = issueTokens(issuedAt: _now, refreshToken: _refreshMarker(5));
    final quoted = [
      tokens.accessToken,
      tokens.refreshToken,
      ...tlsAccessValues().values,
      tlsFixturePassword,
      _hash,
      _sharePassword,
      newWidgetLinkKey(),
      _title,
      _email,
    ];

    await printing(() async {
      for (final value in quoted) {
        reportUncaught(FormatException('Unexpected character', value));
        reportUncaught(Exception('failed with $value'));
      }
    });

    expect(lines, isEmpty);
    expect(records, isEmpty);
  });
}
