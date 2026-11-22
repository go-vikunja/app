import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sentry/sentry.dart'
    show
        Breadcrumb,
        EventProcessor,
        Sentry,
        SentryEnvelope,
        SentryEvent,
        SentryException,
        SentryId,
        SentryMessage,
        SentryOptions,
        Transport;
import 'package:sentry_flutter/sentry_flutter.dart' show SentryFlutterOptions;
// The processors SentryFlutter.init adds, which a test runs as it does.
import 'package:sentry_flutter/src/exception/android_platform_exception_event_processor.dart';
import 'package:sentry_flutter/src/exception/platform_exception_event_processor.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/link_share_gateway.dart';
import 'package:vikunja_mobile/core/auth/link_share_providers.dart';
import 'package:vikunja_mobile/core/auth/session_manager.dart';
import 'package:vikunja_mobile/core/auth/token_store.dart';
import 'package:vikunja_mobile/core/crash_reports/crash_report_consent.dart';
import 'package:vikunja_mobile/core/crash_reports/crash_report_scrubber.dart';
import 'package:vikunja_mobile/core/crash_reports/crash_reporter.dart';
import 'package:vikunja_mobile/core/crash_reports/sentry_crash_report_sdk.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/links/widget_link.dart';
import 'package:vikunja_mobile/core/links/widget_link_key.dart';
import 'package:vikunja_mobile/core/logging/diagnostics_log.dart';
import 'package:vikunja_mobile/core/logging/logging_setup.dart';
import 'package:vikunja_mobile/core/network/client_identity.dart';
import 'package:vikunja_mobile/core/network/dio_factory.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/core/network/request_log_interceptor.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/notifications/notification_actions.dart';
import 'package:vikunja_mobile/core/outbox/failure_json.dart';
import 'package:vikunja_mobile/core/platform/app_part.dart';
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
const _uncaughtText = 'Unexpected UNCAUGHT-TEXT-MARKER';

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
  late Directory diagnosticsFolder;

  void capture({required bool printToConsole}) {
    final debugPrintBefore = debugPrint;
    final flutterErrorBefore = FlutterError.onError;
    final uncaughtBefore = PlatformDispatcher.instance.onError;
    final levelBefore = Logger.root.level;
    records = [];
    lines = [];
    debugPrint = (message, {wrapWidth}) => lines.add(message ?? '');
    final subscription = Logger.root.onRecord.listen(records.add);
    diagnosticsFolder = Directory.systemTemp.createTempSync('diagnostics');
    configureLogging(
      part: AppPart.app,
      printToConsole: printToConsole,
      diagnosticsDirectory: () async => diagnosticsFolder,
    );
    addTearDown(() async {
      resetLoggingForTest();
      await subscription.cancel();
      debugPrint = debugPrintBefore;
      FlutterError.onError = flutterErrorBefore;
      PlatformDispatcher.instance.onError = uncaughtBefore;
      Logger.root.level = levelBefore;
      await diagnosticsFolder.delete(recursive: true);
    });
  }

  // What the diagnostics log keeps, in memory and on disk: the export reads
  // both.
  Future<String> diagnosticsBytes() async {
    final log = currentDiagnosticsLog!;
    await log.idle;
    return [
      for (final entry in log.entries) jsonEncode(entry.toJson()),
      for (final file in diagnosticsFolder.listSync().whereType<File>())
        file.readAsStringSync(),
    ].join('\n');
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
    final kept = currentDiagnosticsLog!.entries
        .map((e) => jsonEncode(e.toJson()))
        .join('\n');
    for (final piece in pieces) {
      expect(output, isNot(contains(piece)));
      expect(kept, isNot(contains(piece)));
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
            // Not 16002: after a server error that is a race, which ends
            // nothing (decision log: Sessions).
            throw SessionEnded(
              SessionEndReason.expired,
              code: 16003,
              message: 'refresh token $refreshToken has expired',
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
      expect(ended.map((e) => e.reason), [SessionEndReason.expired]);
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
    // What the log calls name, and uncaught errors quoting everything.
    Logger('Probe')
      ..warning('Could not read the tokens of account ${user.id}: StateError')
      ..warning('Session of guest ${guest.id} ended: SessionEnded(expired)');
    // Its text reaches only the debug console, the rest by type.
    reportUncaught(
      FormatException(
        _uncaughtText,
        '{"access_token":"${tokens.accessToken}","host":"https://$host/vik",'
        '"email":"$_email"}',
      ),
    );

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
    expect(hidden, contains('tokens of account <account-1>: StateError\n'));
    expect(hidden, contains('Session of guest <account-2> ended'));
    expect(hidden, contains('Uncaught error (Flutter framework)\n'));
    expect(hidden, contains('  error: FormatException\n'));
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
    ];
    // The log keeps accounts by id (threat model, section 10, rule 3); the
    // export names them by number.
    final ids = [user.id, guest.id];
    final stored = await diagnosticsBytes();
    for (final text in [hidden, shown]) {
      for (final piece in piecesOf([...secrets, ...ids, _uncaughtText])) {
        expect(text, isNot(contains(piece)), reason: piece);
      }
    }
    for (final piece in piecesOf([...secrets, host, _uncaughtText])) {
      expect(stored, isNot(contains(piece)), reason: piece);
    }
    expectNowhere(secrets);
  });

  test('a release build prints nothing for an uncaught error, whatever it '
      'quotes, and its diagnostics log, file and export keep only its '
      'type', () async {
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
    final export = await copyableSupportDetails(null, appLanguage: 'en');
    final stored = await diagnosticsBytes();

    expect(lines, isEmpty);
    expect(records.map((r) => r.level).toSet(), {Level.SEVERE});
    expect(
      currentDiagnosticsLog!.entries.map((e) => (e.message, e.error)).toSet(),
      {
        ('Uncaught error (Flutter framework)', 'FormatException'),
        ('Uncaught error (Flutter framework)', '_Exception'),
        ('Uncaught error', 'FormatException'),
        ('Uncaught error', '_Exception'),
      },
    );
    expect(export, contains('  error: FormatException\n'));
    expect(stored, contains('"error":"FormatException"'));
    for (final piece in piecesOf([...quoted, 'Unexpected character'])) {
      expect(export, isNot(contains(piece)), reason: piece);
      expect(stored, isNot(contains(piece)), reason: piece);
    }
  });

  test('crash reports, while allowed, hold no secret, title, e-mail '
      'address, server or IP address, whatever the errors and records '
      'quote', () async {
    capture(printToConsole: false);
    final tokens = issueTokens(issuedAt: _now, refreshToken: _refreshMarker(6));
    const host = 'tasks.example.org';
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
    final sdk = _ScrubbingCrashReportSdk(hosts: const {host});
    // No volume limit, which would drop all but the first value's reports.
    final reporter = CrashReporter(
      dsn: 'https://0123456789abcdef@o1.ingest.example.invalid/1',
      part: AppPart.app,
      sdk: sdk,
      reportLimit: 1 << 30,
      repeatWindow: Duration.zero,
    )..hosts = const {host};
    addTearDown(reporter.dispose);
    await reporter.follow(CrashReportConsent.allowed);
    final log = Logger('CrashProbe');

    final errors = <Object>[];
    for (final value in quoted) {
      final quoting = [
        FormatException('Unexpected character', value),
        Exception('failed with $value'),
        ArgumentError.value(value, 'name'),
        DioException.connectionError(
          requestOptions: RequestOptions(path: '${_base}api/v1/tasks?q=$value'),
          reason: 'failed for $_base',
          error: SocketException(
            "Failed host lookup: '$host'",
            address: InternetAddress('192.168.20.7'),
          ),
        ),
      ];
      errors.addAll(quoting);
      quoting.forEach(reportUncaught);
      log
        ..warning('Retrying ${_base}api/v1/tasks?token=$value')
        ..severe('Gave up on 192.168.20.7: ${value.runtimeType}');
    }
    await Future<void>.delayed(Duration.zero);
    final sent = sdk.sent.join('\n');

    // Each error from FlutterError and from PlatformDispatcher, 1 record
    // per value, and every warning in the last report.
    expect(sdk.sent, hasLength(errors.length * 2 + quoted.length));
    for (final (index, error) in errors.indexed) {
      expect(
        [
          for (final (handed, flutter) in sdk.uncaught)
            if (identical(handed, error)) flutter,
        ],
        unorderedEquals([true, false]),
        reason: 'error $index',
      );
    }
    expect(
      (jsonDecode(sdk.sent.last) as Map<String, Object?>)['breadcrumbs'],
      hasLength(quoted.length),
    );
    expect(sent, contains('FormatException: Unexpected character'));
    expect(sent, contains('<server>'));
    for (final piece in piecesOf([
      ...quoted,
      host,
      '192.168.20.7',
      'failed with',
    ])) {
      expect(sent, isNot(contains(piece)), reason: piece);
    }
  });

  test("a PlatformException quoting a file's name in its message and in "
      'the Java cause it carries leaves through the real event processors '
      'with neither', () async {
    const host = 'tasks.example.org';
    const file =
        '/storage/emulated/0/Download/Bewerbung Max Mustermann.pdf: open '
        'failed';
    PackageInfo.setMockInitialValues(
      appName: 'Vikunja',
      packageName: 'io.vikunja.app',
      version: '1.0.0',
      buildNumber: '7',
      buildSignature: '',
    );
    late _EnvelopeTransport transport;
    await Sentry.init((options) {
      configureCrashReportOptions(
        options,
        start: (
          dsn: 'https://0123456789abcdef@o1.ingest.example.invalid/1',
          part: AppPart.app,
          hosts: () => const {host},
        ),
        release: 'io.vikunja.app@1.0.0+7',
        dist: '7',
      );
      transport = _EnvelopeTransport(options);
      options.transport = transport;
      // Before the exception grouping, as in SentryFlutter.init.
      final grouping = [
        for (final processor in options.eventProcessors)
          if ('${processor.runtimeType}' == 'ExceptionGroupEventProcessor')
            processor,
      ]..forEach(options.removeEventProcessor);
      <EventProcessor>[
        AndroidPlatformExceptionEventProcessor(SentryFlutterOptions(), null),
        PlatformExceptionEventProcessor(),
        ...grouping,
      ].forEach(options.addEventProcessor);
    });
    addTearDown(Sentry.close);

    await SentryCrashReportSdk(native: false).captureUncaught(
      PlatformException(
        code: 'copy_failed',
        message: 'FileNotFoundException: $file',
        stacktrace:
            'java.lang.RuntimeException: Could not copy from $host\n'
            '\tat io.vikunja.app.ShareInbox.copy(ShareInbox.kt:42)\n'
            'Caused by: java.io.FileNotFoundException: $file: ENOENT (No such '
            'file or directory)\n'
            '\tat libcore.io.IoBridge.open(IoBridge.java:574)\n'
            '\tat io.vikunja.app.ShareInbox.copy(ShareInbox.kt:40)\n',
      ),
      StackTrace.current,
      flutter: false,
    );
    final sent = transport.sent.join('\n');

    expect(sent, contains('PlatformException(copy_failed)'));
    expect(sent, contains('FileNotFoundException'), reason: 'the cause');
    expect(sent, contains('"module":"java.io"'));
    for (final piece in ['Mustermann', 'Bewerbung', host, 'Could not copy']) {
      expect(sent, isNot(contains(piece)), reason: piece);
    }
  });
}

/// What the Sentry SDK would send, as text.
final class _EnvelopeTransport implements Transport {
  new(this._options);

  final SentryOptions _options;
  final sent = <String>[];

  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    final bytes = <int>[];
    await envelope.envelopeStream(_options).forEach(bytes.addAll);
    sent.add(utf8.decode(bytes));
    return SentryId.newId();
  }
}

/// Builds each report as the Sentry SDK hands it to its `beforeSend`, and
/// keeps what the scrubber lets through, as JSON.
final class _ScrubbingCrashReportSdk implements CrashReportSdk {
  new({required this.hosts});

  final Set<String> hosts;
  final sent = <String>[];
  final uncaught = <(Object, bool)>[];
  final _breadcrumbs = <Breadcrumb>[];

  void _send(SentryEvent event) {
    final scrubbed = scrubCrashReport(
      event..breadcrumbs = List.of(_breadcrumbs),
      part: AppPart.app.name,
      hosts: hosts,
    );
    sent.add(jsonEncode(scrubbed.toJson()));
  }

  @override
  Future<void> start(CrashReportStart start) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> deleteUnsent() async {}

  @override
  Future<void> captureUncaught(
    Object error,
    StackTrace? stack, {
    required bool flutter,
    String? library,
  }) async {
    uncaught.add((error, flutter));
    _send(
      SentryEvent(
        exceptions: [
          SentryException(
            type: '${error.runtimeType}',
            value: '$error',
            throwable: error,
          ),
        ],
      ),
    );
  }

  @override
  Future<void> captureError(DiagnosticsEntry entry, StackTrace? stack) async =>
      _send(SentryEvent(message: SentryMessage(entry.message)));

  @override
  Future<void> addWarning(DiagnosticsEntry entry) async =>
      _breadcrumbs.add(crashReportBreadcrumb(entry, hosts: hosts));
}
