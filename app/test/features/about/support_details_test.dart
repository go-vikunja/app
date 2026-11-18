import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/background/background_run_log.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/logging/diagnostics_log.dart';
import 'package:vikunja_mobile/core/network/client_identity.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/core/notifications/local_notification_gateway_provider.dart';
import 'package:vikunja_mobile/core/notifications/notification_gateway.dart';
import 'package:vikunja_mobile/core/notifications/notification_preferences.dart';
import 'package:vikunja_mobile/core/notifications/notification_preferences_store.dart';
import 'package:vikunja_mobile/core/outbox/failure_json.dart';
import 'package:vikunja_mobile/core/platform/app_part.dart';
import 'package:vikunja_mobile/core/platform/background_permissions.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/support/session_end_log.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/about/application/support_details.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/guest_fakes.dart';
import '../../helpers/notification_fakes.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/test_database.dart';

final _created = DateTime.utc(2026, 11, 12, 14, 3);

DeviceSupport _android({
  BackgroundState background = const BackgroundState(
    ignoresBatteryOptimizations: true,
    powerSaveMode: false,
    backgroundRestricted: false,
    standbyBucket: 'active',
  ),
}) => DeviceSupport(
  platform: 'android',
  app: const Collected((version: '1.0.0', build: '42')),
  osVersion: const Collected('14'),
  deviceLocale: const Collected('de_DE'),
  notifications: const Collected(
    NotificationCapabilities(
      permission: NotificationPermission.granted,
      exactAlarms: true,
    ),
  ),
  background: Collected(background),
  lastBackgroundRun: Collected((
    outcome: BackgroundRunOutcome.completed,
    at: DateTime.utc(2026, 11, 12, 13, 50),
  )),
);

AccountSupport _account({
  String id = 'a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1',
  String server = 'https://tasks.example.org/vikunja',
  bool guest = false,
  bool active = true,
  bool needsSignIn = false,
  String version = '2.8.0',
  Collected<QueueSummary>? queue,
  Collected<String> syncInSession = const Collected('idle'),
  Collected<String> sendingInSession = const Collected('idle'),
  Collected<SessionEndRecord>? lastSessionEnd,
}) => AccountSupport(
  id: id,
  isGuest: guest,
  active: active,
  needsSignIn: needsSignIn,
  server: Uri.parse(server),
  serverVersion: version,
  tier: SupportTier.full,
  apiVersions: const {ApiVersion.v1, ApiVersion.v2},
  apiV2Missing: false,
  features: const {Capability.taskComments, Capability.apiV2},
  syncTimes: Collected((
    last: DateTime.utc(2026, 11, 12, 13, 49),
    full: DateTime.utc(2026, 11, 12, 8),
  )),
  syncInSession: syncInSession,
  sendingInSession: sendingInSession,
  backgroundTurn: Collected((
    started: DateTime.utc(2026, 11, 12, 13, 49),
    synced: DateTime.utc(2026, 11, 12, 13, 49),
  )),
  queue: queue ?? const Collected(QueueSummary()),
  notifications: const Collected(NotificationPreferences(activity: false)),
  lastSessionEnd: lastSessionEnd ?? const Collected(null),
);

String _render(
  List<AccountSupport>? accounts, {
  DeviceSupport? device,
  bool showServers = false,
  Collected<List<DiagnosticsEntry>> log = const Collected([]),
}) => renderSupportDetails(
  SupportSnapshot(
    createdAt: _created,
    device: device ?? _android(),
    accounts: accounts == null
        ? const Collected.unknown()
        : Collected(accounts),
    log: log,
  ),
  showServers: showServers,
  appLanguage: 'de',
);

const _noLog = 'Log: warnings and errors of the last 7 days: none\n';
const _rowFrame =
    'package:vikunja_mobile/features/tasks/task_row.dart:120:7 '
    '_TaskRowState.build';

DiagnosticsEntry _entry(
  String message, {
  DateTime? at,
  String part = 'app',
  String level = 'WARNING',
  String logger = 'Probe',
  String? error,
  List<String> frames = const [],
  int count = 1,
}) => DiagnosticsEntry(
  at: at ?? DateTime.utc(2026, 11, 12, 13, 59, 7),
  part: part,
  level: level,
  logger: logger,
  message: message,
  error: error,
  frames: frames,
  count: count,
);

String _failure(VikunjaFailure failure) => encodeFailure(failure);

final class _Background implements BackgroundPermissions {
  new(this.state);

  final BackgroundState? state;

  @override
  Future<BackgroundState> read() async => state ?? (throw StateError('gone'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const deviceLines = '''
Support details
Created: 2026-11-12 14:03 UTC
App: 1.0.0 (42)
Platform: android 14
Language: app de, device de_DE
Notifications: allowed
Exact alarms: allowed
Battery optimisation: off
Background restricted: no
Standby bucket: active
Power saving: off
Last background run: completed, 2026-11-12 13:50 UTC
''';

  final sampleQueue = QueueSummary.of([
    QueuedOp(
      kind: 'updateTask',
      state: 'pending',
      createdAt: DateTime.utc(2026, 11, 12, 12),
    ),
    QueuedOp(
      kind: 'updateTask',
      state: 'pending',
      createdAt: DateTime.utc(2026, 11, 12, 12, 30),
      attempts: 3,
      nextAttemptAt: DateTime.utc(2026, 11, 12, 14, 10),
      lastError: _failure(const NetworkFailure(NetworkProblem.timeout)),
    ),
    QueuedOp(
      kind: 'createTask',
      state: 'failed',
      createdAt: DateTime.utc(2026, 11, 12, 13),
      attempts: 1,
      lastError: _failure(
        const ValidationFailed(code: 2002, message: 'MARKER-MESSAGE'),
      ),
      sentAt: DateTime.utc(2026, 11, 12, 13, 1),
    ),
  ]);

  group('renderSupportDetails', () {
    test('signed out: the device, no accounts and an empty log', () {
      expect(_render(const []), '$deviceLines\nAccounts: none\n\n$_noLog');
    });

    test('without accounts, or with them unknown, the log still hides '
        'addresses unless they are shown', () {
      final log = Collected([_entry('Opened https://gone.example.org/x')]);

      expect(_render(const [], log: log), contains('https://<server>/x'));
      expect(_render(null, log: log), contains('https://<server>/x'));
      expect(
        _render(const [], log: log, showServers: true),
        contains('https://gone.example.org/x'),
      );
    });

    test('one user, line by line', () {
      final text = _render([
        _account(
          queue: Collected(sampleQueue),
          lastSessionEnd: Collected(
            SessionEndRecord(
              reason: 'expired',
              part: 'backgroundRun',
              at: DateTime.utc(2026, 11, 10, 8, 12),
            ),
          ),
        ),
      ]);

      expect(text, '''
$deviceLines
Account 1 (active)
Kind: user
Sign-in: signed in
Server: <server-1>
Server version: 2.8.0
Server support: full, API v1 and v2
Features: apiV2, taskComments
Last sync: 2026-11-12 13:49 UTC
Last full sync: 2026-11-12 08:00 UTC
Sync in this session: idle
Sending in this session: idle
Background turn: started 2026-11-12 13:49 UTC, synced 2026-11-12 13:49 UTC
Unsent changes: 3 (updateTask 2, createTask 1)
  new 1, waiting 1, held for sign-in 0, in flight 0, failed 1
  last errors: 1 network/timeout, 1 validation_failed code 2002
  may have reached the server: 1
  most attempts: 3
  oldest: 2026-11-12 12:00 UTC
Notifications: reminders on, due dates on, activity off
Last session end: expired, background run, 2026-11-10 08:12 UTC

$_noLog''');
      expect(text, isNot(contains('MARKER')));
    });

    test('a guest who has to open the link again', () {
      final text = _render([
        _account(guest: true, needsSignIn: true, active: false),
      ]);

      expect(
        text,
        contains('\nAccount 1\nKind: guest\nSign-in: needs sign-in\n'),
      );
      expect(text, contains('Last session end: none recorded\n'));
      expect(text, contains('Unsent changes: 0\nNotifications:'));
    });

    test('accounts on one server share its number; another server gets the '
        'next', () {
      final text = _render([
        _account(server: 'https://one.example.org'),
        _account(server: 'https://two.example.org', active: false),
        _account(server: 'https://one.example.org', active: false),
      ]);

      expect(
        RegExp('Server: (.*)').allMatches(text).map((m) => m[1]).toList(),
        ['<server-1>', '<server-2>', '<server-1>'],
      );
      expect(text, isNot(contains('example.org')));
    });

    test('with the addresses on, a server shows without user info, query, '
        'fragment or share hash', () {
      const hash = 'SHAREHASHMARKER0123456789';
      final text = _render([
        _account(
          server:
              'https://someone:PASSWORDMARKER@tasks.example.org:8443/vik'
              '/share/$hash/auth?q=QUERYMARKER#FRAGMENTMARKER',
        ),
      ], showServers: true);

      expect(
        text,
        contains(
          'Server: https://tasks.example.org:8443/vik/share/[redacted]/auth\n',
        ),
      );
      for (final marker in [
        'someone',
        'PASSWORDMARKER',
        hash,
        'QUERYMARKER',
        'FRAGMENTMARKER',
        '<server-',
      ]) {
        expect(text, isNot(contains(marker)), reason: marker);
      }
    });

    test('a server version keeps only version characters, 40 at most', () {
      final text = _render([
        _account(version: 'v2.8.0-dev <script>alert(1)</script> ${'9' * 60}'),
      ]);

      final version = RegExp('Server version: (.*)').firstMatch(text)![1]!;
      expect(version, matches(RegExp(r'^[A-Za-z0-9.+_-]{1,40}$')));
      expect(version, startsWith('v2.8.0-devscriptalert1script'));
    });

    test('Android: a Reminders channel turned off in the system settings is '
        'named after the permission', () {
      final text = _render(
        [],
        device: const DeviceSupport(
          platform: 'android',
          app: Collected((version: '1.0.0', build: '42')),
          osVersion: Collected('14'),
          deviceLocale: Collected('de_DE'),
          notifications: Collected(
            NotificationCapabilities(
              permission: NotificationPermission.granted,
              exactAlarms: true,
              remindersChannelOff: true,
            ),
          ),
          background: Collected(BackgroundState()),
          lastBackgroundRun: Collected(null),
        ),
      );

      expect(text, contains('Notifications: allowed, reminders channel off\n'));
    });

    test('iOS: Background App Refresh and Low Power Mode instead of the '
        "Android lines, and exact alarms don't apply", () {
      final text = _render(
        [],
        device: const DeviceSupport(
          platform: 'ios',
          app: Collected((version: '1.0.0', build: '42')),
          osVersion: Collected('18.1'),
          deviceLocale: Collected('en_GB'),
          notifications: Collected(
            NotificationCapabilities(
              permission: NotificationPermission.notAsked,
              exactAlarms: true,
            ),
          ),
          background: Collected(
            BackgroundState(backgroundRefresh: 'denied', lowPowerMode: true),
          ),
          lastBackgroundRun: Collected(null),
        ),
      );

      expect(text, contains('Platform: ios 18.1\n'));
      expect(text, contains('Notifications: not asked yet\n'));
      expect(text, contains('Exact alarms: n/a\n'));
      expect(text, contains('Background App Refresh: denied\n'));
      expect(text, contains('Low Power Mode: on\n'));
      expect(text, contains('Last background run: none recorded\n'));
      for (final android in [
        'Battery optimisation',
        'Background restricted',
        'Standby bucket',
        'Power saving',
      ]) {
        expect(text, isNot(contains(android)));
      }
    });

    test('below Android 9 the restriction and the bucket are left out; a '
        'state that could not be read is unknown', () {
      final old = _render(
        [],
        device: _android(
          background: const BackgroundState(
            ignoresBatteryOptimizations: false,
            powerSaveMode: true,
          ),
        ),
      );
      expect(old, contains('Battery optimisation: on\nPower saving: on\n'));

      final unread = _render(
        [],
        device: _android(background: const BackgroundState()),
      );
      expect(
        unread,
        contains('Battery optimisation: unknown\nPower saving: unknown\n'),
      );
      expect(unread, isNot(contains('Standby bucket')));
    });

    test('a part that could not be read is unknown; one this session does '
        'not have is left out', () {
      final text = _render([
        _account(
          queue: const Collected.unknown(),
          syncInSession: const Collected(null),
          sendingInSession: const Collected.unknown(),
          lastSessionEnd: const Collected.unknown(),
        ),
      ]);

      expect(text, contains('Unsent changes: unknown\n'));
      expect(text, contains('Sending in this session: unknown\n'));
      expect(text, isNot(contains('Sync in this session')));
      expect(text, contains('Last session end: unknown\n'));
      expect(_render(null), endsWith('\nAccounts: unknown\n\n$_noLog'));
      expect(
        _render([], log: const Collected.unknown()),
        endsWith('\nLog: warnings and errors of the last 7 days: unknown\n'),
      );
    });

    test('the log comes last: a record a line, its error type and frames '
        'indented, a repeat counted', () {
      final text = _render(
        [],
        log: Collected([
          _entry(
            'Sync run 3 failed at tasks: NetworkFailure',
            logger: 'SyncEngine',
            part: 'backgroundRun',
            count: 4,
          ),
          _entry(
            'Uncaught error (widgets library)',
            at: DateTime.utc(2026, 11, 12, 14, 0, 1),
            level: 'SEVERE',
            logger: 'Flutter',
            error: 'StateError',
            frames: const [_rowFrame],
          ),
        ]),
      );

      expect(
        text,
        endsWith('''
Accounts: none

Log: warnings and errors of the last 7 days: 2
2026-11-12 13:59:07 UTC [background run] WARNING SyncEngine: Sync run 3 failed at tasks: NetworkFailure (4 times)
2026-11-12 14:00:01 UTC [app] SEVERE Flutter: Uncaught error (widgets library)
  error: StateError
  at package:vikunja_mobile/features/tasks/task_row.dart:120:7 _TaskRowState.build
'''),
      );
    });

    test('the log names accounts by their number and, unless the addresses '
        'are shown, servers by theirs', () {
      const alice = 'd4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4';
      const bob = 'b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2';
      const gone = 'c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3';
      final accounts = [
        _account(id: alice),
        _account(id: bob, server: 'https://other.example.net', active: false),
      ];
      final log = Collected([
        _entry('Session of account $alice ended: SessionEnded(expired)'),
        _entry('Could not flag account $bob'),
        _entry('Account $gone has no tokens'),
        _entry('Reached tasks.example.org and other.example.net:8443'),
        _entry('Opened https://unknown.example.com/x and ftp://files.local'),
      ]);

      final hidden = _render(accounts, log: log);
      final shown = _render(accounts, log: log, showServers: true);

      final logPart = hidden.substring(hidden.indexOf('Log:'));
      expect(logPart, contains('account <account-1> ended'));
      expect(logPart, contains('flag account <account-2>\n'));
      expect(logPart, contains('Account <account> has no tokens'));
      expect(logPart, contains('Reached <server-1> and <server-2>:8443'));
      expect(
        logPart,
        contains('Opened https://<server>/x and ftp://<server>\n'),
      );
      for (final marker in [alice, bob, gone, 'example', 'files.local']) {
        expect(hidden, isNot(contains(marker)), reason: marker);
      }
      final shownLog = shown.substring(shown.indexOf('Log:'));
      expect(shownLog, contains('account <account-1> ended'));
      expect(
        shownLog,
        contains('Reached tasks.example.org and other.example.net:8443'),
      );
      expect(shownLog, contains('Opened https://unknown.example.com/x'));
      expect(shown, isNot(contains(alice)));
    });

    test("a server's host is replaced only where it stands as a host, not "
        "inside a longer one or the app's own frames", () {
      final text = _render(
        [_account(server: 'http://vikunja:3456')],
        log: Collected([
          _entry(
            'Reached vikunja, vikunja:3456 and vikunja.example.org for '
            'vikunja_mobile',
            logger: 'vikunja-sync',
            frames: const [_rowFrame],
          ),
        ]),
      );

      final logPart = text.substring(text.indexOf('Log:'));
      expect(
        logPart,
        contains(
          'vikunja-sync: Reached <server-1>, <server-1>:3456 and '
          'vikunja.example.org for vikunja_mobile',
        ),
      );
      expect(logPart, contains('  at $_rowFrame\n'));
    });
  });

  group('QueueSummary', () {
    test('splits the pending ops and counts the failure kinds, never their '
        'messages', () {
      final summary = QueueSummary.of([
        for (final (state, next, error) in [
          ('pending', null, null),
          ('pending', DateTime.utc(2026), _failure(const ServerFailure(502))),
          (
            'pending',
            null,
            _failure(
              const SessionEnded(
                SessionEndReason.expired,
                code: 16003,
                message: 'MARKER',
              ),
            ),
          ),
          ('pending', null, _failure(const NetworkFailure(NetworkProblem.tls))),
          ('sending', null, null),
          ('failed', null, _failure(const Forbidden(message: 'MARKER'))),
          ('failed', null, 'not json MARKER'),
          ('archived', null, null),
        ])
          QueuedOp(
            kind: 'updateTask',
            state: state,
            createdAt: DateTime.utc(2026, 11, 12),
            nextAttemptAt: next,
            lastError: error,
          ),
      ]);

      expect(summary.total, 8);
      expect(
        (
          summary.fresh,
          summary.waiting,
          summary.heldForSignIn,
          summary.dueAgain,
          summary.inFlight,
          summary.failed,
          summary.otherState,
        ),
        (1, 1, 1, 1, 1, 2, 1),
      );
      expect(summary.lastErrors, {
        'server_failure HTTP 502': 1,
        'session_ended/expired code 16003': 1,
        'network/tls': 1,
        'forbidden': 1,
        'unreadable': 1,
      });
      expect(summary.lastErrors.keys.join(), isNot(contains('MARKER')));
    });

    test('reads the queue and the sync times from the database, not the '
        "ops' content or the account's settings", () async {
      final db = testDatabase();
      await db.syncStateDao.write({
        SyncStateKeys.lastSyncedAt: '2026-11-12T13:49:00.000Z',
        SyncStateKeys.userSettings: '{"email": "MARKER@example.com"}',
      });
      await db
          .into(db.outbox)
          .insert(
            OutboxCompanion.insert(
              id: 'op-1',
              sequence: 1,
              kind: 'updateTask',
              taskId: 7,
              payload: '{"title": "MARKER"}',
              createdAt: DateTime.utc(2026, 11, 12, 12),
              attempts: 2,
              state: 'pending',
              nextAttemptAt: Value(DateTime.utc(2026, 11, 12, 14)),
              lastError: Value(
                _failure(const NetworkFailure(NetworkProblem.unreachable)),
              ),
              sentAt: Value(DateTime.utc(2026, 11, 12, 12, 1)),
            ),
          );

      final times = await readSyncTimes(db);
      final queue = await readQueueSummary(db);

      expect(times, (last: DateTime.utc(2026, 11, 12, 13, 49), full: null));
      expect(queue.byKind, {'updateTask': 1});
      expect(queue.waiting, 1);
      expect(queue.mostAttempts, 2);
      expect(queue.mayHaveReachedServer, 1);
      expect(queue.lastErrors, {'network/unreachable': 1});
      expect(queue.oldest, DateTime.utc(2026, 11, 12, 12));
    });
  });

  group('supportSnapshotProvider', () {
    late AuthFakes auth;
    late Map<String, AppDatabase> databases;

    setUp(() {
      auth = AuthFakes();
      databases = {};
    });

    ProviderContainer container({
      BackgroundState? background,
      NotificationGateway? gateway,
      DiagnosticsLog? log,
    }) {
      final container = ProviderContainer(
        overrides: [
          ...auth.overrides,
          diagnosticsLogProvider.overrideWithValue(log),
          clockProvider.overrideWithValue(() => _created),
          clientIdentityProvider.overrideWithValue(
            const ClientIdentity(
              appVersion: '1.0.0',
              buildNumber: '42',
              platform: 'android',
              osVersion: '14',
            ),
          ),
          notificationGatewayProvider.overrideWithValue(
            gateway ?? FakeNotificationGateway(),
          ),
          backgroundPermissionsProvider.overrideWithValue(
            _Background(background),
          ),
          appDatabaseProvider.overrideWith(
            (ref, accountId) =>
                databases[accountId] ??
                (throw StateError('No database for this account')),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('collects the device and every account in registry order', () async {
      final alice = await auth.seedAccount(
        fullServer280(),
        tokens: issueTokens(issuedAt: _created),
      );
      final guest = await auth.seedGuest(
        fullServer280(),
        token: null,
        needsReauth: true,
        activate: false,
      );
      databases[alice.id] = testDatabase();
      databases[guest.id] = testDatabase();
      await databases[alice.id]!.syncStateDao.write({
        SyncStateKeys.lastFullSyncAt: '2026-11-12T08:00:00.000Z',
      });
      await BackgroundRunLog(auth.preferences)
          .recordResult(BackgroundRunOutcome.partial, _created);
      await StoredNotificationPreferences(auth.preferences)
          .write(guest.id, const NotificationPreferences(reminders: false));
      await SessionEndLog(auth.preferences, now: () => _created).record(
        guest.id,
        SessionEndReason.linkShareGone,
        part: AppPart.widgetAction,
      );

      final snapshot = await container(
        background: const BackgroundState(powerSaveMode: true),
      ).read(supportSnapshotProvider.future);
      final text = renderSupportDetails(
        snapshot,
        showServers: false,
        appLanguage: 'en',
      );

      expect(text, contains('App: 1.0.0 (42)\nPlatform: android 14\n'));
      expect(text, contains('Notifications: allowed\nExact alarms: allowed\n'));
      expect(text, contains('Power saving: on\n'));
      expect(text, contains('Last background run: partial, 2026-11-12 14:03'));
      expect(text, contains('Account 1 (active)\nKind: user\n'));
      expect(text, contains('Last sync: never\nLast full sync: 2026-11-12'));
      expect(text, contains('Account 2\nKind: guest\nSign-in: needs sign-in'));
      expect(text, contains('Server: <server-1>\nServer version: 2.8.0\n'));
      expect(RegExp('Server: (.*)').allMatches(text).map((m) => m[1]).toSet(), {
        '<server-1>',
      });
      expect(
        text,
        contains('Notifications: reminders off, due dates on, activity on\n'),
      );
      expect(
        text,
        contains(
          'Last session end: linkShareGone, widget action, '
          '2026-11-12 14:03 UTC\n',
        ),
      );
      expect(text, isNot(contains('Sync in this session')));
    });

    test(
      'a part that fails reads as unknown; the rest is still collected',
      () async {
        await auth.seedAccount(
          fullServer280(),
          tokens: issueTokens(issuedAt: _created),
        );
        final gateway = FakeNotificationGateway()
          ..beforeCall = (call) async => throw StateError(call);

        final snapshot = await container(gateway: gateway)
            .read(supportSnapshotProvider.future);
        final text = renderSupportDetails(
          snapshot,
          showServers: false,
          appLanguage: 'en',
        );

        expect(
          text,
          contains('Notifications: unknown\nExact alarms: unknown\n'),
        );
        expect(text, contains('Battery optimisation: unknown\n'));
        expect(text, contains('Last sync: unknown\nLast full sync: unknown\n'));
        expect(text, contains('Unsent changes: unknown\n'));
        expect(text, contains('Account 1 (active)\nKind: user\n'));
        expect(text, contains('Last session end: none recorded\n'));
      },
    );

    test('signed out, only the device', () async {
      final snapshot = await container().read(supportSnapshotProvider.future);

      expect(
        renderSupportDetails(snapshot, showServers: true, appLanguage: 'en'),
        endsWith('\nAccounts: none\n\n$_noLog'),
      );
    });

    test("collects this isolate's diagnostics log, the account by its "
        'number', () async {
      final alice = await auth.seedAccount(
        fullServer280(),
        tokens: issueTokens(issuedAt: _created),
      );
      databases[alice.id] = testDatabase();
      final log =
          DiagnosticsLog(
            part: AppPart.backgroundRun,
            directory: () async => null,
            now: () => _created,
          )..add(
            LogRecord(
              Level.WARNING,
              'Could not read the tokens of account ${alice.id}: StateError',
              'AccountsWithoutTokens',
            ),
          );

      final snapshot = await container(log: log)
          .read(supportSnapshotProvider.future);
      final text = renderSupportDetails(
        snapshot,
        showServers: false,
        appLanguage: 'en',
      );

      expect(
        text,
        endsWith(
          'Log: warnings and errors of the last 7 days: 1\n'
          '2026-11-12 14:03:00 UTC [background run] WARNING '
          'AccountsWithoutTokens: Could not read the tokens of account '
          '<account-1>: StateError\n',
        ),
      );
      expect(text, isNot(contains(alice.id)));
    });

    test('the copy of the release error widget is the text the page shows '
        'with the servers hidden', () async {
      await auth.seedAccount(
        fullServer280(),
        tokens: issueTokens(issuedAt: _created),
      );
      final log = DiagnosticsLog(
        part: AppPart.app,
        directory: () async => null,
        now: () => _created,
      )..add(LogRecord(Level.SEVERE, 'Probe failed', 'Probe'));
      final providers = container(log: log);

      final copied = await copyableSupportDetails(providers, appLanguage: 'en');

      expect(
        copied,
        renderSupportDetails(
          await providers.read(supportSnapshotProvider.future),
          showServers: false,
          appLanguage: 'en',
        ),
      );
      expect(copied, contains('Server: <server-1>\n'));
      expect(copied, contains('SEVERE Probe: Probe failed\n'));
    });
  });

  test('without a container, the copy holds the platform and the log of '
      'this isolate', () async {
    final log = DiagnosticsLog(
      part: AppPart.app,
      directory: () async => null,
      now: () => _created,
    )..add(LogRecord(Level.SEVERE, 'Probe failed', 'Probe'));
    useDiagnosticsLog(log);
    addTearDown(() => useDiagnosticsLog(null));

    final copied = await copyableSupportDetails(null, appLanguage: 'de');

    expect(copied, startsWith('Support details\nCreated: '));
    expect(copied, contains('\nApp: unknown\n'));
    expect(copied, contains('\nLanguage: app de, device unknown\n'));
    expect(copied, contains('\nAccounts: unknown\n'));
    expect(
      copied,
      endsWith(
        'Log: warnings and errors of the last 7 days: 1\n'
        '2026-11-12 14:03:00 UTC [app] SEVERE Probe: Probe failed\n',
      ),
    );
  });

  test('a failure label holds its kind, problem or reason, code and status, '
      'never its message', () {
    expect(
      failureLabel(
        jsonEncode({
          'kind': 'domain_error',
          'code': 3001,
          'status_code': 400,
          'message': 'MARKER',
          'field_errors': {
            'title': ['MARKER'],
          },
        }),
      ),
      'domain_error code 3001 HTTP 400',
    );
    expect(failureLabel(null), isNull);
  });
}
