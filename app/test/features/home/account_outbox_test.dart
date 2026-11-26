import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/widgets/status_card.dart';
import 'package:vikunja_mobile/core/attachments/attachment_downloads.dart';
import 'package:vikunja_mobile/core/attachments/upload_policy.dart';
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
    usePhoneSurface(tester, logicalSize: const Size(360, 2000));
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
    TaskChanges? changes,
  }) => SyncProblem(
    operationId: id,
    kind: kind,
    taskId: taskId,
    taskTitle: title,
    failure: failure,
    failedAt: now.subtract(ago),
    changes: changes,
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

  testWidgets('pending changes and sync problems show with the sync, not '
      "under the device's own settings", (tester) async {
    data.tasks.pendingChanges = 2;
    data.tasks.syncProblems = [
      problem(
        id: 'op-1',
        title: 'Pay the bill',
        failure: const Forbidden(code: 7003),
        ago: const Duration(minutes: 5),
      ),
    ];
    await pumpAccountTab(tester);

    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    final sync = top(en.accountSyncHeading);
    // The first of the device's own sections.
    final deviceOnly = top(en.widgetsHeading);
    expect(
      tester.getCenter(find.text(en.onThisDeviceHeading).first).dy,
      closeTo(tester.getCenter(find.text(en.widgetsHeading)).dy, 1),
    );
    for (final text in [en.accountPendingChanges(2), en.accountSyncProblems]) {
      expect(top(text), allOf(greaterThan(sync), lessThan(deviceOnly)));
    }
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

  testWidgets("a failed change of a label shows the label's title and what "
      'failed, with Retry and Discard', (tester) async {
    data.tasks.pendingChanges = 1;
    final deleted = SyncProblem(
      operationId: 'op-label',
      kind: OutboxOperationKind.deleteLabel,
      taskId: 0,
      taskTitle: 'Errand',
      labelId: 50,
      failure: const Forbidden(),
      failedAt: now.subtract(const Duration(minutes: 5)),
    );
    data.tasks.syncProblems = [deleted];
    await pumpAccountTab(tester);

    final card = find.widgetWithText(StatusCard, 'Errand');
    expect(card, findsOneWidget);
    expect(
      find.descendant(
        of: card,
        matching: find.text(
          '${en.syncProblemLabelDeleteFailed} ${en.labelsNotCreator}',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text(en.retry)),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(of: card, matching: find.text(en.syncProblemDiscard)),
    );
    await tester.pumpAndSettle();

    expect(data.tasks.writes, ['discard op-label']);
    expect(find.text('Errand'), findsNothing);
  });

  testWidgets('an unconfirmed upload can be saved without changing the queue', (
    tester,
  ) async {
    final cache = Directory.systemTemp.createTempSync('outbox_export_test');
    addTearDown(() => cache.deleteSync(recursive: true));
    final source = File('${cache.path}/queued')..writeAsBytesSync([8, 9]);
    data.tasks.failedUploadCopies['upload'] = (
      file: source,
      fileName: 'photo.png',
      mimeType: 'image/png',
    );
    data.tasks.syncProblems = [
      problem(
        id: 'upload',
        title: 'Photos',
        failure: unconfirmedWrite,
        ago: Duration.zero,
        kind: OutboxOperationKind.uploadAttachment,
      ),
    ];
    List<int>? exported;
    data.fileActions.beforeCall = (call) async {
      exported = File(call.split(' ')[1]).readAsBytesSync();
    };
    data.attachmentDownloads = AttachmentDownloads(() async => cache);
    await pumpAccountTab(tester);

    final save = find.text(en.attachmentSaveToDevice);
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
    for (var attempt = 0; attempt < 100 && exported == null; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(exported, [8, 9]);
    for (
      var attempt = 0;
      attempt < 100 && find.text(en.attachmentSaved).evaluate().isEmpty;
      attempt++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(find.text(en.attachmentSaved), findsOneWidget);
    expect(data.fileActions.calls.single, endsWith(' photo.png image/png'));
    expect(data.fileActions.origins.single, isNotNull);
    expect(source.readAsBytesSync(), [8, 9]);
    expect(data.tasks.writes, isEmpty);
    expect(find.text('Photos'), findsOneWidget);
  });

  testWidgets('two or more problems with Retry get Retry all beside the '
      'heading, which sends them in one go', (tester) async {
    final semantics = tester.ensureSemantics();
    data.tasks.syncProblems = [
      problem(
        id: 'op-1',
        title: 'Pay the bill',
        failure: const Forbidden(code: 7003),
        ago: const Duration(minutes: 5),
      ),
      problem(
        id: 'op-2',
        title: 'Call mum',
        failure: const DescriptionConflict(),
        ago: const Duration(minutes: 4),
        taskId: 2,
      ),
      problem(
        id: 'op-3',
        title: 'Water the plants',
        failure: const ServerFailure(502),
        ago: const Duration(minutes: 3),
        taskId: 3,
      ),
    ];
    await pumpAccountTab(tester);

    final retryAll = find.widgetWithText(TextButton, en.syncProblemsRetryAll);
    expect(retryAll, findsOneWidget);
    expect(
      tester.getSemantics(find.text(en.accountSyncProblems)),
      matchesSemantics(label: en.accountSyncProblems, isHeader: true),
    );
    // With the test's wide square font it goes below the heading.
    expect(
      tester.getTopLeft(retryAll).dy,
      lessThan(tester.getTopLeft(find.byType(StatusCard).first).dy),
    );

    await tester.tap(retryAll);
    await tester.pumpAndSettle();

    // The description conflict is resolved by choosing a version.
    expect(data.tasks.writes, ['retryAll op-1,op-3']);
    expect(find.text('Call mum'), findsOneWidget);
    expect(find.byType(StatusCard), findsOneWidget);
    expect(retryAll, findsNothing);
    semantics.dispose();
  });

  testWidgets('a recurring schedule notice offers discard or keeping the '
      'held changes, not replay', (tester) async {
    data.tasks.syncProblems = [
      problem(
        id: 'held',
        title: 'Weekly review',
        failure: recurringScheduleConflict,
        ago: Duration.zero,
        changes: const TaskChanges(title: 'Weekly retro'),
      ),
      problem(
        id: 'dates',
        title: 'Water plants',
        failure: recurringScheduleConflict,
        ago: Duration.zero,
        taskId: 2,
        changes: TaskChanges(dueDate: DateChange.set(now)),
      ),
    ];
    await pumpAccountTab(tester);

    expect(
      find.textContaining(en.syncProblemRecurringScheduleConflict),
      findsNWidgets(2),
    );
    expect(find.text(en.retry), findsNothing);
    expect(find.text(en.syncProblemDiscard), findsNWidgets(2));
    // Dates alone belong to the previous occurrence: nothing to keep.
    expect(find.text(en.syncProblemKeepMine), findsOneWidget);

    await tester.tap(find.text(en.syncProblemKeepMine));
    await tester.pumpAndSettle();

    expect(data.tasks.writes, ['keepHeld held']);
    expect(find.text('Weekly review'), findsNothing);
    expect(find.text('Water plants'), findsOneWidget);
  });

  testWidgets('one problem with Retry needs no Retry all', (tester) async {
    data.tasks.syncProblems = [
      problem(
        id: 'op-1',
        title: 'Pay the bill',
        failure: const Forbidden(code: 7003),
        ago: const Duration(minutes: 5),
      ),
      problem(
        id: 'op-2',
        title: 'photo.png',
        failure: const UnexpectedResponse(
          null,
          message: uploadFileMissingMessage,
        ),
        ago: const Duration(minutes: 5),
        kind: OutboxOperationKind.uploadAttachment,
        taskId: 2,
      ),
    ];
    await pumpAccountTab(tester);

    expect(find.text(en.syncProblemsRetryAll), findsNothing);
  });

  for (final (what, label) in [
    ('Retry', en.retry),
    ('Retry all', en.syncProblemsRetryAll),
    ('Send now', en.accountSendNow),
  ]) {
    testWidgets('$what that the device cannot store says so and can be '
        'tapped again', (tester) async {
      data.tasks.pendingChanges = 3;
      data.tasks.syncProblems = [
        for (final id in ['op-1', 'op-2'])
          problem(
            id: id,
            title: 'Task $id',
            failure: const Forbidden(code: 7003),
            ago: const Duration(minutes: 5),
          ),
      ];
      data.tasks.beforeWrite = () async =>
          throw const FileSystemException('No space left on device');
      await pumpAccountTab(tester);

      await tester.tap(find.text(label).first);
      await tester.pumpAndSettle();

      expect(find.text(en.localChangeFailed), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, label).first)
            .onPressed,
        isNotNull,
      );
      expect(find.byType(StatusCard), findsNWidgets(2));
    });
  }

  testWidgets('an upload whose stored copy is gone offers only Discard', (
    tester,
  ) async {
    data.tasks.syncProblems = [
      problem(
        id: 'op-1',
        title: 'Pay the bill',
        failure: const UnexpectedResponse(
          null,
          message: uploadFileMissingMessage,
        ),
        ago: const Duration(minutes: 5),
        kind: OutboxOperationKind.uploadAttachment,
      ),
      problem(
        id: 'op-2',
        title: 'Call mum',
        failure: const FileTooLarge(code: 4012),
        ago: const Duration(minutes: 5),
        kind: OutboxOperationKind.uploadAttachment,
      ),
    ];
    await pumpAccountTab(tester);

    Finder inCard(String title, String label) => find.descendant(
      of: find.widgetWithText(StatusCard, title),
      matching: find.text(label),
    );
    expect(inCard('Pay the bill', en.syncProblemDiscard), findsOneWidget);
    expect(inCard('Pay the bill', en.retry), findsNothing);
    expect(inCard('Call mum', en.retry), findsOneWidget);
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
