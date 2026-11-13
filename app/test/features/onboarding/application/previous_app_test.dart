import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/oauth_client.dart';
import 'package:vikunja_mobile/core/network/network_providers.dart';
import 'package:vikunja_mobile/core/previous_app/previous_app_import.dart';
import 'package:vikunja_mobile/core/previous_app/previous_app_record.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';
import 'package:vikunja_mobile/features/onboarding/application/previous_app.dart';
import 'package:vikunja_mobile/features/session/application/session_check.dart';

import '../../../helpers/auth_fakes.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/server_connections.dart';

const _alice = User(id: 7, username: 'alice', name: 'Alice Example');
const _oldToken = 'previous-refresh-token';

void main() {
  late AuthFakes auth;
  late FakeServerConnector connector;
  late ProviderContainer container;
  final connection = fullServer270(root: 'https://vikunja.example.com');
  final accountId = accountIdFor(connection.rootUri, _alice.id);
  final record = PreviousAppRecord(
    server: Uri.parse('https://vikunja.example.com'),
    recentServers: [Uri.parse('https://old.example.com')],
    placedWidgets: 2,
  );

  setUp(() {
    auth = AuthFakes();
    connector = FakeServerConnector.succeeding(connection);
    container = ProviderContainer(
      overrides: [
        ...auth.overrides,
        serverConnectorProvider.overrideWithValue(connector),
      ],
    );
    addTearDown(container.dispose);
  });

  void serveAlice() {
    final now = DateTime.now().toUtc();
    auth.tokenGateway.onRefresh = (_) async =>
        issueTokens(issuedAt: now, userId: _alice.id);
    auth.accountGateway.onCurrentUser = (_) async => _alice;
  }

  /// Like bootstrap: the registry first.
  Future<void> load({PreviousAppRecord? stored}) async {
    await stored?.write(auth.preferences);
    await container.read(accountsProvider.future);
    await container.read(previousAppProvider.future);
  }

  PreviousApp notifier() => container.read(previousAppProvider.notifier);

  PreviousAppState current() => container.read(previousAppProvider).value!;

  test('loads the stored record, without a note on a later start', () async {
    await load(stored: record);

    expect(current().record, record);
    expect(current().note, isNull);
    expect(current().session, isA<PreviousAppSessionUntried>());
  });

  test('the import of this start brings the note', () async {
    await load();

    notifier().noteImported(PreviousAppFindings(record: record));

    expect(current().record, record);
    expect(current().note?.serverFilledIn, isTrue);
    expect(current().note?.placedWidgets, 2);

    notifier().noteImported(
      const PreviousAppFindings(record: PreviousAppRecord()),
    );
    expect(current().note?.serverFilledIn, isFalse);
    expect(current().note?.placedWidgets, 0);
  });

  test('keeping the session shows at once, then the kept account, whose '
      'session counts as just checked', () async {
    serveAlice();
    await load(stored: record);

    final keeping = notifier().keepSession(_oldToken);

    expect(
      current().session,
      isA<PreviousAppSessionKeeping>().having(
        (session) => session.server,
        'server',
        record.server,
      ),
    );
    await keeping;
    expect(
      current().session,
      isA<PreviousAppSessionKept>().having(
        (session) => session.accountId,
        'accountId',
        accountId,
      ),
    );
    expect(auth.tokenGateway.refreshedTokens, [_oldToken]);
    expect(connector.inputs, ['https://vikunja.example.com']);
    await pumpEventQueue();
    final accounts = container.read(accountsProvider).value!;
    expect(accounts.activeAccountId, accountId);

    await container.read(sessionCheckProvider).check(accounts.activeAccount!);
    expect(
      auth.accountGateway.currentUserTokens,
      hasLength(1),
      reason: 'the check right after the sign-in asks the server nothing',
    );
  });

  test('the session is tried once per process', () async {
    serveAlice();
    await load(stored: record);

    await Future.wait([
      notifier().keepSession(_oldToken),
      notifier().keepSession(_oldToken),
    ]);
    await notifier().keepSession(_oldToken);

    expect(auth.tokenGateway.refreshedTokens, hasLength(1));
  });

  test('a failure loses the session and registers no account', () async {
    auth.tokenGateway.onRefresh = (_) async =>
        throw const SessionEnded(SessionEndReason.invalidRefreshToken);
    await load(stored: record);

    await notifier().keepSession(_oldToken);

    expect(current().session, isA<PreviousAppSessionLost>());
    expect(container.read(accountsProvider).value?.accounts, isEmpty);
    expect(current().record, record, reason: 'Connect still fills it in');
  });

  group('ending the try early', () {
    late Completer<TokenSet> refresh;
    late TokenSet lateTokens;

    // In the body: a completer from setUp would complete outside the fake
    // async zone of testWidgets.
    void holdRefresh() {
      refresh = Completer<TokenSet>();
      lateTokens = issueTokens(
        issuedAt: DateTime.now().toUtc(),
        userId: _alice.id,
      );
      auth.tokenGateway.onRefresh = (_) => refresh.future;
      auth.accountGateway.onCurrentUser = (_) async => _alice;
    }

    Future<void> expectNothingLeftBehind() async {
      expect(container.read(accountsProvider).value?.accounts, isEmpty);
      expect(auth.preferences.values[AccountRegistry.storageKey], isNull);
      expect(auth.secureStore.values, isEmpty);
      expect(auth.accountGateway.currentUserTokens, isEmpty);
      expect(auth.accountGateway.logoutTokens, [lateTokens.accessToken]);
      expect(await PreviousAppRecord.read(auth.preferences), record);
    }

    test('a cancel loses the session at once, like a failure, and a late '
        'answer changes nothing', () async {
      holdRefresh();
      await load(stored: record);
      notifier().noteImported(PreviousAppFindings(record: record));
      final keeping = notifier().keepSession(_oldToken);
      await pumpEventQueue();

      notifier().cancelKeepingSession();

      expect(current().session, isA<PreviousAppSessionLost>());
      expect(current().record, record, reason: 'Connect still fills it in');
      expect(current().note?.serverFilledIn, isTrue);
      final changes = <PreviousAppState?>[];
      container.listen(
        previousAppProvider,
        (_, next) => changes.add(next.value),
      );
      refresh.complete(lateTokens);
      await keeping;
      await pumpEventQueue();

      expect(changes, isEmpty);
      await expectNothingLeftBehind();
    });

    testWidgets('after the limit the session is lost the same way, and a '
        'late answer changes nothing', (tester) async {
      holdRefresh();
      await load(stored: record);
      final keeping = notifier().keepSession(_oldToken);

      await tester.pump(previousAppSessionLimit - const Duration(seconds: 1));
      expect(current().session, isA<PreviousAppSessionKeeping>());
      await tester.pump(const Duration(seconds: 1));
      expect(current().session, isA<PreviousAppSessionLost>());
      expect(current().record, record);

      refresh.complete(lateTokens);
      await keeping;
      await tester.pump();

      expect(current().session, isA<PreviousAppSessionLost>());
      await expectNothingLeftBehind();
    });

    testWidgets('a try that ends in time leaves no limit running', (
      tester,
    ) async {
      serveAlice();
      await load(stored: record);

      await notifier().keepSession(_oldToken);

      expect(current().session, isA<PreviousAppSessionKept>());
    });

    test('a cancel once the server has confirmed the account comes too '
        'late, and the account is kept', () async {
      serveAlice();
      final write = Completer<void>();
      auth.secureStore.beforeWrite = (_) => write.future;
      await load(stored: record);
      final keeping = notifier().keepSession(_oldToken);
      await pumpEventQueue();

      notifier().cancelKeepingSession();
      expect(current().session, isA<PreviousAppSessionKeeping>());
      write.complete();
      await keeping;

      expect(
        current().session,
        isA<PreviousAppSessionKept>().having(
          (session) => session.accountId,
          'accountId',
          accountId,
        ),
      );
      expect(auth.accountGateway.logoutTokens, isEmpty);
    });

    test('the session is not tried again after a cancel', () async {
      holdRefresh();
      await load(stored: record);
      unawaited(notifier().keepSession(_oldToken));
      await pumpEventQueue();
      notifier().cancelKeepingSession();

      await notifier().keepSession(_oldToken);
      notifier().cancelKeepingSession();

      expect(auth.tokenGateway.refreshedTokens, hasLength(1));
      expect(current().session, isA<PreviousAppSessionLost>());
    });

    test('a cancel without a try changes nothing', () async {
      await load(stored: record);

      notifier().cancelKeepingSession();

      expect(current().session, isA<PreviousAppSessionUntried>());
    });

    test('a late failure changes nothing either', () async {
      holdRefresh();
      await load(stored: record);
      final keeping = notifier().keepSession(_oldToken);
      await pumpEventQueue();
      notifier().cancelKeepingSession();
      final changes = <PreviousAppState?>[];
      container.listen(
        previousAppProvider,
        (_, next) => changes.add(next.value),
      );

      refresh.completeError(const NetworkFailure(NetworkProblem.unreachable));
      await keeping;
      await pumpEventQueue();

      expect(changes, isEmpty);
      expect(current().session, isA<PreviousAppSessionLost>());
    });

    test('a try still running when the app ends registers nothing', () async {
      holdRefresh();
      await load(stored: record);
      final keeping = notifier().keepSession(_oldToken);
      await pumpEventQueue();

      container.dispose();
      refresh.complete(lateTokens);
      await keeping;
      await pumpEventQueue();

      expect(auth.preferences.values[AccountRegistry.storageKey], isNull);
      expect(auth.secureStore.values, isEmpty);
      expect(auth.accountGateway.logoutTokens, [lateTokens.accessToken]);
    });
  });

  test('without a server nothing is tried', () async {
    await load(stored: const PreviousAppRecord(placedWidgets: 1));

    await notifier().keepSession(_oldToken);

    expect(current().session, isA<PreviousAppSessionUntried>());
    expect(connector.inputs, isEmpty);
    expect(auth.tokenGateway.refreshedTokens, isEmpty);
  });

  test('the record goes once an account is registered', () async {
    serveAlice();
    await load(stored: record);
    notifier().noteImported(PreviousAppFindings(record: record));

    await notifier().keepSession(_oldToken);
    await pumpEventQueue();

    expect(current().record, isNull);
    expect(current().note, isNotNull, reason: 'the first sync shows it');
    expect(await PreviousAppRecord.read(auth.preferences), isNull);
  });

  test('a record left from before an account was registered is dropped '
      'when loaded', () async {
    await record.write(auth.preferences);
    await auth.seedAccount(
      connection,
      tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
    );

    await load();
    await pumpEventQueue();

    expect(current().record, isNull);
    expect(await PreviousAppRecord.read(auth.preferences), isNull);
  });

  test(
    'a record that cannot be removed is still dropped from the state',
    () async {
      await record.write(auth.preferences);
      await auth.seedAccount(
        connection,
        tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
      );
      final sticky = ProviderContainer(
        overrides: [
          secureStoreProvider.overrideWithValue(auth.secureStore),
          preferencesStoreProvider.overrideWithValue(
            _UnremovableRecord(auth.preferences),
          ),
        ],
      );
      addTearDown(sticky.dispose);

      await sticky.read(accountsProvider.future);
      await sticky.read(previousAppProvider.future);
      await pumpEventQueue();

      expect(await PreviousAppRecord.read(auth.preferences), record);
      expect(sticky.read(previousAppProvider).value?.record, isNull);
    },
  );
}

final class _UnremovableRecord implements PreferencesStore {
  new(this._inner);

  final PreferencesStore _inner;

  @override
  Future<String?> getString(String key) => _inner.getString(key);

  @override
  Future<void> setString(String key, String value) =>
      _inner.setString(key, value);

  @override
  Future<void> remove(String key) async {
    if (key == PreviousAppRecord.storageKey) throw Exception('Unwritable');
    await _inner.remove(key);
  }
}
