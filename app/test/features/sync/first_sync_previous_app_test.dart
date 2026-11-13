import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/auth/oauth_client.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/onboarding/application/previous_app.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/previous_app_note.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

final class _Fixed extends PreviousApp {
  new(this._state);

  final PreviousAppState _state;

  @override
  Future<PreviousAppState> build() async => _state;
}

void main() {
  final now = DateTime(2026, 11, 13, 9);
  // pumpSignedInApp's account.
  final activeId = accountIdFor(fullServer270().rootUri, 7);
  const note = PreviousAppNote(serverFilledIn: true, placedWidgets: 0);

  /// On the first-sync screen, with the run held open; the completer is
  /// created here, in the test's zone.
  Future<void> pumpFirstSync(
    WidgetTester tester,
    PreviousAppState previous,
  ) async {
    final data = SyncFakes(now: now, status: const SyncNeverRun());
    data.engine.onEnsureInitialSync = () => Completer<void>().future;
    await pumpSignedInApp(
      tester,
      sync: data,
      now: now,
      settle: false,
      overrides: [previousAppProvider.overrideWith(() => _Fixed(previous))],
    );
    await pumpUntil(tester, find.text(en.syncPhaseAccount));
  }

  testWidgets('a kept session of the previous app shows the note, that the '
      'user is still signed in', (tester) async {
    await pumpFirstSync(
      tester,
      PreviousAppState(note: note, session: PreviousAppSessionKept(activeId)),
    );

    expect(find.byType(PreviousAppNoteCard), findsOneWidget);
    expect(find.text(en.previousAppNoteTitle), findsOneWidget);
    expect(find.text(en.previousAppNoteSignedIn), findsOneWidget);
    expect(find.text(en.previousAppNoteSignInAgain), findsNothing);
    expect(find.text(en.previousAppNoteWidgets), findsNothing);
  });

  testWidgets('with widgets of the previous app placed, says how to set them '
      'up', (tester) async {
    await pumpFirstSync(
      tester,
      PreviousAppState(
        note: const PreviousAppNote(serverFilledIn: true, placedWidgets: 1),
        session: PreviousAppSessionKept(activeId),
      ),
    );

    expect(find.text(en.previousAppNoteWidgets), findsOneWidget);
    expect(find.text(en.previousAppNoteWidgetsAfterSignIn), findsNothing);
  });

  for (final (name, previous) in [
    (
      'for another account',
      const PreviousAppState(
        note: note,
        session: PreviousAppSessionKept('another'),
      ),
    ),
    (
      'without a note',
      PreviousAppState(session: PreviousAppSessionKept(activeId)),
    ),
    (
      'for a lost session',
      const PreviousAppState(note: note, session: PreviousAppSessionLost()),
    ),
    ('for an untried session', const PreviousAppState(note: note)),
  ]) {
    testWidgets('no note $name', (tester) async {
      await pumpFirstSync(tester, previous);

      expect(find.byType(PreviousAppNoteCard), findsNothing);
    });
  }
}
