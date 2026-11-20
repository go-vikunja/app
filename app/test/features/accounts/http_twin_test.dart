import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/oauth_client.dart';
import 'package:vikunja_mobile/features/accounts/application/https_twins.dart';
import 'package:vikunja_mobile/features/session/application/sign_out_providers.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

RegisteredAccount _account(
  String root, {
  int userId = 7,
  String username = 'alice',
}) {
  final connection = fullServer270(root: root);
  return RegisteredAccount(
    account: Account(
      id: '$root#$userId',
      serverRoot: connection.rootUri,
      userId: userId,
      username: username,
      displayName: 'Alice',
      addedAt: DateTime.utc(2026, 10),
    ),
    connection: connection,
  );
}

void main() {
  group('the http twin of an https account', () {
    final https = _account('https://nas.example/vikunja');
    final http = _account('http://nas.example:3456/vikunja/');

    test('is the same user on the same host and path', () {
      expect(httpTwinOf([https, http], https), http);
      expect(hasHttpsTwin([https, http], http), isTrue);
      expect(httpTwinOf([https, http], http), isNull);
      expect(hasHttpsTwin([https, http], https), isFalse);
    });

    for (final (name, other) in [
      (
        'another user id',
        _account('http://nas.example:3456/vikunja', userId: 8),
      ),
      (
        'another username',
        _account('http://nas.example/vikunja', username: 'bo'),
      ),
      ('another host', _account('http://nas2.example/vikunja')),
      ('another path', _account('http://nas.example/tasks')),
      ('another https account', _account('https://nas.example:3456/vikunja')),
    ]) {
      test('is not $name', () {
        expect(httpTwinOf([https, other], https), isNull);
        expect(hasHttpsTwin([https, other], other), isFalse);
      });
    }

    test('is never a guest, nor has one', () {
      RegisteredAccount guest(RegisteredAccount over) => RegisteredAccount(
        account: Account.linkShare(
          id: 'guest ${over.id}',
          serverRoot: over.connection.rootUri,
          shareId: 7,
          projectId: 1,
          displayName: 'Garden',
          addedAt: DateTime.utc(2026, 10),
        ),
        connection: over.connection,
      );
      final httpGuest = guest(http);
      final httpsGuest = guest(https);
      expect(httpTwinOf([https, httpGuest], https), isNull);
      expect(hasHttpsTwin([https, httpGuest], httpGuest), isFalse);
      expect(httpTwinOf([httpsGuest, httpGuest], httpsGuest), isNull);
      expect(hasHttpsTwin([httpsGuest, httpGuest], httpGuest), isFalse);
    });
  });

  group('the kept http accounts', () {
    test('forgetting one keeps the others, and the last takes the record '
        'with it', () async {
      final preferences = MemoryPreferencesStore();
      final kept = KeptHttpTwins(preferences);
      await kept.keep('a', unsent: 2, accountIds: {'a', 'b'});
      await kept.keep('b', unsent: 0, accountIds: {'a', 'b'});

      await kept.forget('a');
      await kept.forget('unknown');

      expect(await kept.unsentWhenKept('a'), isNull);
      expect(await kept.unsentWhenKept('b'), 0);
      await kept.forget('b');
      expect(preferences.values, isNot(contains(KeptHttpTwins.storageKey)));
    });

    test('signing out a kept http account forgets it, so a new session is '
        'asked again; the others stay kept', () async {
      final auth = AuthFakes();
      final container = ProviderContainer(
        overrides: [...auth.overrides, ...SyncFakes().overrides],
      );
      addTearDown(container.dispose);
      final tokens = issueTokens(issuedAt: DateTime.now().toUtc());
      final http = await auth.seedAccount(insecureServer(), tokens: tokens);
      final other = await auth.seedAccount(
        insecureServer(root: 'http://nas.example:3456'),
        tokens: tokens,
        activate: false,
      );
      await container.read(accountsProvider.future);
      final kept = KeptHttpTwins(auth.preferences);
      for (final entry in [http, other]) {
        await kept.keep(entry.id, unsent: 0, accountIds: {http.id, other.id});
      }

      await container.read(signOutProvider).call(http.id);

      expect(await kept.unsentWhenKept(http.id), isNull);
      expect(await kept.unsentWhenKept(other.id), 0);
    });
  });

  group('the offer to remove the http account', () {
    late AuthFakes auth;
    late SyncFakes data;
    late RegisteredAccount httpEntry;
    late RegisteredAccount httpsEntry;

    setUp(() => (auth, data) = (AuthFakes(), SyncFakes()));

    Future<void> pumpBoth(
      WidgetTester tester, {
      required bool httpsActive,
    }) async {
      usePhoneSurface(tester, logicalSize: const Size(360, 1400));
      final tokens = issueTokens(issuedAt: DateTime.now().toUtc());
      httpEntry = await auth.seedAccount(
        insecureServer(),
        tokens: tokens,
        activate: !httpsActive,
      );
      httpsEntry = await auth.seedAccount(
        fullServer270(root: 'https://192.168.1.20'),
        tokens: tokens,
        activate: httpsActive,
      );
      await pumpVikunjaApp(tester, auth: auth, sync: data);
    }

    /// The app started again over what the last run stored.
    Future<void> restart(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await pumpVikunjaApp(tester, auth: auth, sync: data);
    }

    List<String> accountIds(WidgetTester tester) => [
      for (final entry in containerOf(
        tester,
      ).read(accountsProvider).value!.accounts)
        entry.id,
    ];

    testWidgets('says how many unsent changes would be lost; Cancel keeps '
        'the account', (tester) async {
      final httpId = accountIdFor(insecureServer().rootUri, 7);
      data.accounts[httpId] = AccountDataFakes(now: DateTime.now())
        ..tasks.pendingChanges = 2;
      await pumpBoth(tester, httpsActive: true);

      expect(find.text(en.httpAccountRemoveTitle), findsOneWidget);
      expect(
        find.textContaining(en.removeAccountDialogPendingChanges(2)),
        findsOneWidget,
      );
      await tester.tap(find.text(en.signOutDialogCancel));
      await tester.pumpAndSettle();

      expect(find.text(en.httpAccountRemoveTitle), findsNothing);
      expect(accountIds(tester), [httpEntry.id, httpsEntry.id]);
    });

    testWidgets('kept, it is not asked again at the next start', (
      tester,
    ) async {
      await pumpBoth(tester, httpsActive: true);
      await tester.tap(find.text(en.signOutDialogCancel));
      await tester.pumpAndSettle();

      await restart(tester);

      expect(find.text(en.httpAccountRemoveTitle), findsNothing);
      expect(accountIds(tester), [httpEntry.id, httpsEntry.id]);
    });

    testWidgets('kept with unsent changes, it is asked again once they are '
        'sent', (tester) async {
      final httpId = accountIdFor(insecureServer().rootUri, 7);
      final httpData = data.accounts[httpId] = AccountDataFakes(
        now: DateTime.now(),
      )..tasks.pendingChanges = 2;
      await pumpBoth(tester, httpsActive: true);
      await tester.tap(find.text(en.signOutDialogCancel));
      await tester.pumpAndSettle();

      await restart(tester);
      expect(find.text(en.httpAccountRemoveTitle), findsNothing);

      httpData.tasks.pendingChanges = 0;
      await restart(tester);
      expect(find.text(en.httpAccountRemoveTitle), findsOneWidget);
      expect(
        find.textContaining(en.removeAccountDialogPendingChanges(2)),
        findsNothing,
      );
    });

    testWidgets('is not made while the http account is the active one', (
      tester,
    ) async {
      await pumpBoth(tester, httpsActive: false);

      expect(find.text(en.httpAccountRemoveTitle), findsNothing);
      expect(accountIds(tester), [httpEntry.id, httpsEntry.id]);
    });
  });
}
