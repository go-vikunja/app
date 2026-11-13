import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/app/vikunja_app.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/oauth_client.dart';
import 'package:vikunja_mobile/core/previous_app/previous_app_import.dart';
import 'package:vikunja_mobile/core/previous_app/previous_app_record.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/onboarding/application/previous_app.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_server_screen.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connection_options_button.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/previous_app_note.dart';
import 'package:vikunja_mobile/features/sync/presentation/first_sync_screen.dart';

import '../../../helpers/auth_fakes.dart';
import '../../../helpers/fakes.dart';
import '../../../helpers/pump_app.dart';
import '../../../helpers/server_connections.dart';
import '../../../helpers/sync_fakes.dart';

const _alice = User(id: 7, username: 'alice', name: 'Alice Example');
const _oldToken = 'previous-refresh-token';

final _record = PreviousAppRecord(
  server: Uri.parse('https://vikunja.example.com'),
  recentServers: [Uri.parse('https://old.example.com')],
);

final Finder _note = find.byType(PreviousAppNoteCard);

void main() {
  late AuthFakes auth;
  late FakeServerConnector connector;
  late SyncFakes sync;
  final connection = fullServer270(root: 'https://vikunja.example.com');

  setUp(() {
    auth = AuthFakes();
    connector = FakeServerConnector.succeeding(connection);
    sync = SyncFakes(now: DateTime.now(), status: const SyncNeverRun());
  });

  /// Like bootstrap: the registry and this provider are loaded before the
  /// first frame; [prepare] runs in between, as `startPreviousApp` does.
  Future<ProviderContainer> pumpApp(
    WidgetTester tester, {
    PreviousAppRecord? stored,
    void Function(PreviousApp notifier)? prepare,
    List<Override> overrides = const [],
    bool settle = true,
  }) async {
    await stored?.write(auth.preferences);
    final container = ProviderContainer(
      overrides: [
        ...appOverrides(connector: connector, auth: auth, sync: sync),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    await container.read(accountsProvider.future);
    await container.read(previousAppProvider.future);
    prepare?.call(container.read(previousAppProvider.notifier));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const VikunjaApp(),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await pumpFrames(tester, 3);
    }
    return container;
  }

  /// Bootstrap's container outlives the tree; the test's must not, or the
  /// signed-in app's timers outlive the test.
  Future<void> unmount(WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }

  void noteImported(PreviousApp notifier, {PreviousAppRecord? record}) =>
      notifier.noteImported(PreviousAppFindings(record: record ?? _record));

  String fieldText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  testWidgets("a later start fills in the previous app's server and offers "
      'its recent servers, without the note', (tester) async {
    await pumpApp(tester, stored: _record);

    expect(find.byType(ConnectServerScreen), findsOneWidget);
    expect(fieldText(tester), 'https://vikunja.example.com');
    expect(find.text(en.addAccountYourServers), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'old.example.com'), findsOneWidget);
    expect(_note, findsNothing);

    await tester.tap(find.widgetWithText(ActionChip, 'old.example.com'));
    await tester.pump();
    expect(connector.inputs, ['https://old.example.com']);
  });

  testWidgets('a fresh install shows an empty field and no servers', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(fieldText(tester), isEmpty);
    expect(find.text(en.addAccountYourServers), findsNothing);
    expect(_note, findsNothing);
  });

  testWidgets('adding another account shows nothing of the previous app', (
    tester,
  ) async {
    await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
    );
    sync = SyncFakes(now: DateTime.now());
    final container = await pumpApp(tester, prepare: noteImported);
    expect(container.read(previousAppProvider).value?.record, _record);

    container.read(appRouterProvider).go(AppRoutes.addAccount);
    await tester.pumpAndSettle();

    expect(find.byType(ConnectServerScreen), findsOneWidget);
    expect(fieldText(tester), isEmpty);
    expect(find.widgetWithText(ActionChip, 'old.example.com'), findsNothing);
    expect(
      find.widgetWithText(ActionChip, 'tasks.example.org/vikunja'),
      findsOneWidget,
    );
    expect(_note, findsNothing);
    await unmount(tester, container);
  });

  group('the note on the start that found the previous app', () {
    testWidgets('with the server filled in, asks to sign in again', (
      tester,
    ) async {
      await pumpApp(tester, prepare: noteImported);

      expect(_note, findsOneWidget);
      expect(find.text(en.previousAppNoteTitle), findsOneWidget);
      expect(find.text(en.previousAppNoteSignInAgain), findsOneWidget);
      expect(find.text(en.previousAppNoteWidgets), findsNothing);
      expect(fieldText(tester), 'https://vikunja.example.com');
    });

    testWidgets('without a server, asks to sign in', (tester) async {
      await pumpApp(
        tester,
        prepare: (notifier) =>
            noteImported(notifier, record: const PreviousAppRecord()),
      );

      expect(find.text(en.previousAppNoteSignIn), findsOneWidget);
      expect(find.text(en.previousAppNoteSignInAgain), findsNothing);
      expect(fieldText(tester), isEmpty);
    });

    testWidgets('with widgets of the previous app placed, says to set them '
        'up after the sign-in, before which a tap on one opens only this '
        'screen', (tester) async {
      await pumpApp(
        tester,
        prepare: (notifier) => noteImported(
          notifier,
          record: const PreviousAppRecord(placedWidgets: 2),
        ),
      );

      expect(find.text(en.previousAppNoteWidgetsAfterSignIn), findsOneWidget);
      expect(find.text(en.previousAppNoteWidgets), findsNothing);
    });

    testWidgets('no longer once an account was registered: the address is '
        'not filled in then', (tester) async {
      sync.engine.onEnsureInitialSync = () => Completer<void>().future;
      final container = await pumpApp(tester, prepare: noteImported);
      expect(_note, findsOneWidget);

      final entry = await auth.seedAccount(
        connection,
        tokens: issueTokens(
          issuedAt: DateTime.now().toUtc(),
          userId: _alice.id,
        ),
      );
      final registry = container.read(accountRegistryProvider);
      await registry.upsert(entry, activate: true);
      container.read(appRouterProvider).go(AppRoutes.home);
      await pumpUntil(tester, find.byType(FirstSyncScreen));
      await registry.remove(entry.id);
      await pumpUntil(tester, find.byType(ConnectServerScreen));
      await pumpFrames(tester, 3);

      expect(find.byType(ConnectServerScreen), findsOneWidget);
      expect(fieldText(tester), isEmpty);
      expect(_note, findsNothing);
      await unmount(tester, container);
    });

    testWidgets('in German', (tester) async {
      useLocale(tester, const Locale('de'));
      await pumpApp(tester, prepare: noteImported);

      expect(find.text(de.previousAppNoteTitle), findsOneWidget);
      expect(find.text(de.previousAppNoteSignInAgain), findsOneWidget);
    });
  });

  testWidgets('while the session is kept, the screen says so and nothing '
      'else can start a sign-in', (tester) async {
    final refresh = Completer<TokenSet>();
    auth.tokenGateway.onRefresh = (_) => refresh.future;
    await pumpApp(
      tester,
      prepare: (notifier) {
        noteImported(notifier);
        unawaited(notifier.keepSession(_oldToken));
      },
      settle: false,
    );

    expect(
      find.text(en.previousAppSigningIn('vikunja.example.com')),
      findsOneWidget,
    );
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    expect(find.text(en.connectContinue), findsNothing);
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, en.connectTryDemo),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<ActionChip>(
            find.widgetWithText(ActionChip, 'old.example.com'),
          )
          .onPressed,
      isNull,
    );
    for (final label in [en.guestOpenSharedLink, en.aboutTitle]) {
      expect(
        tester
            .widget<TextButton>(
              find.ancestor(
                of: find.text(label),
                matching: find.byWidgetPredicate((w) => w is TextButton),
              ),
            )
            .onPressed,
        isNull,
        reason: label,
      );
    }
    expect(
      tester
          .widget<ConnectionOptionsButton>(find.byType(ConnectionOptionsButton))
          .onPressed,
      isNull,
    );
    expect(find.text(en.connectCancel), findsNothing);
    expect(_note, findsNothing);
  });

  // The completers are created in the test bodies: one from setUp would
  // complete outside the test's fake async zone.
  group('a kept session goes on to the first sync', () {
    Future<ProviderContainer> keepOnConnect(WidgetTester tester) async {
      final refresh = Completer<TokenSet>();
      auth.tokenGateway.onRefresh = (_) => refresh.future;
      auth.accountGateway.onCurrentUser = (_) async => _alice;
      sync.engine.onEnsureInitialSync = () => Completer<void>().future;
      final container = await pumpApp(
        tester,
        prepare: (notifier) {
          noteImported(notifier);
          unawaited(notifier.keepSession(_oldToken));
        },
        settle: false,
      );
      expect(find.byType(ConnectServerScreen), findsOneWidget);
      refresh.complete(
        issueTokens(issuedAt: DateTime.now().toUtc(), userId: _alice.id),
      );
      await pumpUntil(tester, find.byType(FirstSyncScreen));
      return container;
    }

    testWidgets('when it is kept while Connect is shown, and the first sync '
        'shows the note', (tester) async {
      final container = await keepOnConnect(tester);

      expect(find.byType(ConnectServerScreen), findsNothing);
      expect(find.text(en.previousAppNoteSignedIn), findsOneWidget);
      await unmount(tester, container);
    });

    testWidgets('when Connect is built after it was kept', (tester) async {
      final container = await keepOnConnect(tester);

      container.read(appRouterProvider).go(AppRoutes.connect);
      await pumpFrames(tester, 3);

      expect(find.byType(FirstSyncScreen), findsOneWidget);
      expect(find.byType(ConnectServerScreen), findsNothing);
      await unmount(tester, container);
    });

    // The session and the registry each may report last.
    group('whichever of session and account comes last', () {
      late _Driven previousApp;

      Future<ProviderContainer> pumpKeeping(WidgetTester tester) async {
        sync.engine.onEnsureInitialSync = () => Completer<void>().future;
        previousApp = _Driven(
          PreviousAppState(
            record: _record,
            session: PreviousAppSessionKeeping(_record.server!),
          ),
        );
        final container = await pumpApp(
          tester,
          overrides: [previousAppProvider.overrideWith(() => previousApp)],
          settle: false,
        );
        expect(find.byType(ConnectServerScreen), findsOneWidget);
        return container;
      }

      Future<String> register(ProviderContainer container) async {
        final entry = await auth.seedAccount(
          connection,
          tokens: issueTokens(
            issuedAt: DateTime.now().toUtc(),
            userId: _alice.id,
          ),
        );
        await container
            .read(accountRegistryProvider)
            .upsert(entry, activate: true);
        return entry.id;
      }

      void kept(String accountId) => previousApp.set(
        PreviousAppState(
          record: _record,
          session: PreviousAppSessionKept(accountId),
        ),
      );

      testWidgets('the session', (tester) async {
        final container = await pumpKeeping(tester);
        final accountId = await register(container);
        await pumpFrames(tester, 3);
        expect(find.byType(ConnectServerScreen), findsOneWidget);

        kept(accountId);
        await pumpUntil(tester, find.byType(FirstSyncScreen));

        await unmount(tester, container);
      });

      testWidgets('the account', (tester) async {
        final container = await pumpKeeping(tester);
        kept(accountIdFor(connection.rootUri, _alice.id));
        await pumpFrames(tester, 3);
        expect(find.byType(ConnectServerScreen), findsOneWidget);

        await register(container);
        await pumpUntil(tester, find.byType(FirstSyncScreen));

        await unmount(tester, container);
      });
    });
  });

  testWidgets('a lost session leaves the address filled in and shows the '
      'note', (tester) async {
    auth.tokenGateway.onRefresh = (_) async =>
        throw const SessionEnded(SessionEndReason.invalidRefreshToken);
    await pumpApp(
      tester,
      prepare: (notifier) {
        noteImported(notifier);
        unawaited(notifier.keepSession(_oldToken));
      },
    );

    expect(find.byType(ConnectServerScreen), findsOneWidget);
    expect(find.text(en.previousAppNoteSignInAgain), findsOneWidget);
    expect(
      find.text(en.previousAppSigningIn('vikunja.example.com')),
      findsNothing,
    );
    expect(fieldText(tester), 'https://vikunja.example.com');
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
  });
}

final class _Driven extends PreviousApp {
  new(this._initial);

  final PreviousAppState _initial;

  @override
  Future<PreviousAppState> build() async => _initial;

  void set(PreviousAppState next) => state = AsyncData(next);
}
