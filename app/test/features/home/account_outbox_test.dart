import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/widgets/status_card.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/home/presentation/account_tab.dart';
import 'package:vikunja_mobile/features/home/presentation/sync_problem_message.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  late AuthFakes auth;
  late SyncFakes data;
  late DateTime now;

  setUp(() {
    auth = AuthFakes();
    now = DateTime.now().toUtc();
    data = SyncFakes(now: now);
  });

  Future<void> pumpAccountTab(
    WidgetTester tester, {
    bool needsReauth = false,
    String? tabLabel,
  }) async {
    await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: now),
      needsReauth: needsReauth,
    );
    // Tall enough for the whole tab, which the list builds lazily.
    usePhoneSurface(tester, logicalSize: const Size(360, 1800));
    await pumpVikunjaApp(
      tester,
      auth: auth,
      sync: data,
      overrides: [clockProvider.overrideWithValue(() => now)],
    );
    await openTab(tester, tabLabel ?? en.tabAccount);
  }

  SyncProblem problem({
    required String id,
    required String title,
    required VikunjaFailure failure,
    required Duration ago,
    OutboxOperationKind kind = OutboxOperationKind.updateTask,
    int taskId = 1,
  }) => SyncProblem(
    operationId: id,
    kind: kind,
    taskId: taskId,
    taskTitle: title,
    failure: failure,
    failedAt: now.subtract(ago),
  );

  testWidgets('nothing about the outbox shows while it is empty', (
    tester,
  ) async {
    await pumpAccountTab(tester);

    expect(find.text(en.accountPendingChanges(0)), findsNothing);
    expect(find.text(en.accountSendNow), findsNothing);
    expect(find.text(en.accountSyncProblems), findsNothing);
  });

  testWidgets('pending changes show with "Send now", which drains the outbox', (
    tester,
  ) async {
    data.tasks.pendingChanges = 2;
    final drain = Completer<void>();
    data.tasks.beforeWrite = () => drain.future;
    await pumpAccountTab(tester);

    expect(find.text(en.accountPendingChanges(2)), findsOneWidget);
    await tester.tap(find.text(en.accountSendNow));
    await tester.pump();

    expect(data.tasks.writes, ['sendPending']);
    expect(find.text(en.accountSending), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, en.accountSending),
          )
          .onPressed,
      isNull,
    );

    drain.complete();
    data.tasks.pendingChanges = 1;
    await tester.pumpAndSettle();
    expect(find.text(en.accountPendingChanges(1)), findsOneWidget);
    expect(find.text(en.accountSendNow), findsOneWidget);

    data.tasks.pendingChanges = 0;
    await tester.pumpAndSettle();
    expect(find.text(en.accountPendingChanges(1)), findsNothing);
    expect(find.text(en.accountSendNow), findsNothing);
  });

  testWidgets('"Send now" that cannot send says why', (tester) async {
    data.tasks.pendingChanges = 1;
    data.tasks.sendBlockedBy = const NetworkFailure(NetworkProblem.timeout);
    await pumpAccountTab(tester);

    await tester.tap(find.text(en.accountSendNow));
    await tester.pumpAndSettle();

    expect(data.tasks.writes, ['sendPending']);
    expect(
      find.text(
        en.accountSendNowFailed(
          en.failureTimeoutExplanation('tasks.example.org'),
        ),
      ),
      findsOneWidget,
    );
    expect(find.text(en.accountSendNow), findsOneWidget);
  });

  testWidgets('"Send now" is not offered while every queued change is a '
      'sync problem', (tester) async {
    data.tasks.pendingChanges = 1;
    data.tasks.syncProblems = [
      problem(
        id: 'op-1',
        title: 'Pay the bill',
        failure: const Forbidden(code: 7003),
        ago: const Duration(minutes: 5),
      ),
    ];
    await pumpAccountTab(tester);

    expect(find.text(en.accountPendingChanges(1)), findsOneWidget);
    expect(find.text(en.accountSendNow), findsNothing);

    data.tasks.pendingChanges = 2;
    await tester.pumpAndSettle();
    expect(find.text(en.accountSendNow), findsOneWidget);
  });

  testWidgets('"Send now" rests for a session that needs a new sign-in', (
    tester,
  ) async {
    data.tasks.pendingChanges = 3;
    await pumpAccountTab(tester, needsReauth: true);

    expect(find.text(en.accountPendingChanges(3)), findsOneWidget);
    final button = tester.widget<TextButton>(
      find.widgetWithText(TextButton, en.accountSendNow),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('sync problems list the task, what failed and when, with Retry '
      'and Discard', (tester) async {
    data.tasks.pendingChanges = 2;
    final forbidden = problem(
      id: 'op-1',
      title: 'Pay the bill',
      failure: const Forbidden(code: 7003),
      ago: const Duration(minutes: 5),
    );
    final projectGone = problem(
      id: 'op-2',
      title: 'Call mum',
      failure: const NotFound(code: 3001),
      ago: const Duration(hours: 2),
      kind: OutboxOperationKind.deleteTask,
      taskId: 2,
    );
    data.tasks.syncProblems = [forbidden, projectGone];
    await pumpAccountTab(tester);

    expect(find.text(en.accountSyncProblems), findsOneWidget);
    expect(find.byType(StatusCard), findsNWidgets(2));
    expect(find.text('Pay the bill'), findsOneWidget);
    expect(find.text(describeSyncProblem(en, forbidden)), findsOneWidget);
    expect(find.text(en.syncProblemFailedAt('5 minutes ago')), findsOneWidget);
    expect(find.text('Call mum'), findsOneWidget);
    expect(find.text(describeSyncProblem(en, projectGone)), findsOneWidget);
    expect(find.text(en.syncProblemFailedAt('2 hours ago')), findsOneWidget);

    Finder inCard(String title, String label) => find.descendant(
      of: find.widgetWithText(StatusCard, title),
      matching: find.text(label),
    );
    await tester.tap(inCard('Pay the bill', en.retry));
    await tester.pumpAndSettle();
    expect(data.tasks.writes, ['retry op-1']);
    expect(find.text('Pay the bill'), findsNothing);
    expect(find.byType(StatusCard), findsOneWidget);

    await tester.tap(inCard('Call mum', en.syncProblemDiscard));
    await tester.pumpAndSettle();
    expect(data.tasks.writes, ['retry op-1', 'discard op-2']);
    expect(find.byType(StatusCard), findsNothing);
    expect(find.text(en.accountSyncProblems), findsNothing);
    expect(find.text(en.accountPendingChanges(1)), findsOneWidget);
  });

  testWidgets('a discard that fails keeps the card and says why', (
    tester,
  ) async {
    data.tasks.syncProblems = [
      problem(
        id: 'op-1',
        title: 'Pay the bill',
        failure: const Forbidden(code: 7003),
        ago: const Duration(minutes: 5),
      ),
    ];
    final read = Completer<void>();
    data.tasks.beforeWrite = () => read.future;
    data.tasks.discardFailure = const NetworkFailure(
      NetworkProblem.unreachable,
    );
    await pumpAccountTab(tester);

    TextButton button(String label) =>
        tester.widget<TextButton>(find.widgetWithText(TextButton, label));
    await tester.tap(find.text(en.syncProblemDiscard));
    await tester.pump();

    // Both buttons rest while the server is read.
    expect(button(en.syncProblemDiscard).onPressed, isNull);
    expect(button(en.retry).onPressed, isNull);

    read.complete();
    await tester.pumpAndSettle();

    expect(data.tasks.writes, ['discard op-1']);
    expect(find.text('Pay the bill'), findsOneWidget);
    expect(
      find.text(en.failureUnreachableExplanation('tasks.example.org')),
      findsOneWidget,
    );
    expect(button(en.syncProblemDiscard).onPressed, isNotNull);
    expect(button(en.retry).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a fresh problem failed just now', (tester) async {
    data.tasks.syncProblems = [
      problem(
        id: 'op-1',
        title: 'Pay the bill',
        failure: const Forbidden(code: 7003),
        ago: const Duration(seconds: 10),
      ),
    ];
    await pumpAccountTab(tester);

    expect(find.text(en.syncProblemFailedJustNow), findsOneWidget);
    expect(find.text(en.syncProblemFailedAt(en.relativeNow)), findsNothing);
  });

  testWidgets('the problems heading is a header', (tester) async {
    final semantics = tester.ensureSemantics();
    data.tasks.syncProblems = [
      problem(
        id: 'op-1',
        title: 'Pay the bill',
        failure: const ValidationFailed(code: 4001),
        ago: const Duration(minutes: 1),
      ),
    ];
    await pumpAccountTab(tester);

    expect(
      tester.getSemantics(find.text(en.accountSyncProblems)),
      matchesSemantics(label: en.accountSyncProblems, isHeader: true),
    );
    semantics.dispose();
  });

  testWidgets('at 200 % text scale in dark mode everything still renders', (
    tester,
  ) async {
    useAccessibilityExtremes(tester);
    data.tasks.pendingChanges = 12;
    data.tasks.syncProblems = [
      problem(
        id: 'op-1',
        title: 'A task with a rather long title that wraps',
        failure: const Forbidden(code: 7003),
        ago: const Duration(minutes: 5),
      ),
    ];
    await pumpAccountTab(tester);

    // The list builds lazily; at this size the lines sit below the fold.
    for (final text in [
      en.accountPendingChanges(12),
      en.accountSendNow,
      en.syncProblemDiscard,
    ]) {
      await tester.scrollUntilVisible(
        find.text(text),
        100,
        scrollable: find
            .descendant(
              of: find.byType(AccountTab),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text(text), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('is in German', (tester) async {
    useLocale(tester, const Locale('de'));
    data.tasks.pendingChanges = 2;
    final archived = problem(
      id: 'op-1',
      title: 'Pay the bill',
      failure: const DomainError(412, code: 3008),
      ago: const Duration(minutes: 5),
    );
    final fresh = problem(
      id: 'op-2',
      title: 'Call mum',
      failure: const NotFound(code: 3001),
      ago: Duration.zero,
      taskId: 2,
    );
    data.tasks.syncProblems = [archived, fresh];
    await pumpAccountTab(tester, tabLabel: de.tabAccount);

    expect(find.text(de.accountPendingChanges(2)), findsOneWidget);
    expect(find.text(de.accountSendNow), findsNothing);
    expect(find.text(de.accountSyncProblems), findsOneWidget);
    expect(find.text(describeSyncProblem(de, archived)), findsOneWidget);
    expect(find.text(describeSyncProblem(de, fresh)), findsOneWidget);
    expect(find.text(de.syncProblemFailedAt('vor 5 Minuten')), findsOneWidget);
    expect(find.text(de.syncProblemFailedJustNow), findsOneWidget);
    expect(find.text(de.syncProblemDiscard), findsNWidgets(2));
    expect(find.text(de.retry), findsNWidgets(2));
  });
}
