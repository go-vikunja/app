import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/sync/presentation/offline_notice.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

const _anna = User(id: 9, username: 'anna', name: 'Anna');
const _offline = NetworkFailure(NetworkProblem.unreachable);

void main() {
  final now = DateTime(2026, 10, 12, 12);
  final loadedAt = now.subtract(const Duration(hours: 2)).toUtc();
  late SyncFakes data;

  final pass = sampleAttachment(
    id: 5,
    taskId: 4,
    name: 'boarding-pass.pdf',
    mime: 'application/pdf',
  );
  final ticket = sampleAttachment(
    id: 6,
    taskId: 4,
    name: 'ticket.pdf',
    mime: 'application/pdf',
  );

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [sampleProject(id: 1, title: 'Travel')];
    data.tasks.all = [sampleTask(id: 4, title: 'Fly to Lisbon')];
    data.details
      ..storedDetailsByTask[4] = (
        value: TaskDetails(
          attachments: [pass, ticket],
          reactions: const {
            '👍': [_anna],
          },
          commentCount: 2,
        ),
        readAt: loadedAt,
      )
      ..storedCommentsByTask[4] = (
        value: [
          sampleComment(id: 1, html: '<p>Gate B12</p>'),
          sampleComment(id: 2, html: '<p>Seat 14A</p>'),
        ],
        readAt: loadedAt,
      );
  });

  Finder sheet() => find.byType(TaskDetailSheet).last;

  Finder inSheet(Finder matching) =>
      find.descendant(of: sheet(), matching: matching);

  Future<void> openDetail(WidgetTester tester) async {
    usePhoneSurface(tester, logicalSize: const Size(360, 2400));
    final auth = AuthFakes();
    await auth.seedAccount(
      fullServer270(),
      tokens: issueTokens(issuedAt: DateTime.now().toUtc()),
    );
    await pumpVikunjaApp(
      tester,
      auth: auth,
      sync: data,
      overrides: [clockProvider.overrideWithValue(() => now)],
    );
    final context = containerOf(tester)
        .read(appRouterProvider)
        .routerDelegate
        .navigatorKey
        .currentContext!;
    unawaited(showTaskDetail(context, task: data.tasks.find(4)!));
    await tester.pumpAndSettle();
  }

  group('offline', () {
    setUp(() {
      data.details
        ..detailsFailure = _offline
        ..commentsFailure = _offline;
      data.attachments
        ..failure = _offline
        ..cached.add(pass.id);
    });

    testWidgets('the detail shows the stored attachments, reactions and '
        'comments, as of when they were loaded', (tester) async {
      final asOf = en.relativeHoursAgo(2);
      await openDetail(tester);

      expect(
        inSheet(find.text(en.taskDetailDetailsStored(asOf))),
        findsOneWidget,
      );
      // The comments have a time and a note of their own.
      expect(en.taskDetailDetailsStored(asOf), isNot(contains('omments')));
      expect(inSheet(find.text(en.taskDetailDetailsOffline)), findsNothing);
      expect(inSheet(find.text('boarding-pass.pdf')), findsOneWidget);
      expect(inSheet(find.text('ticket.pdf')), findsOneWidget);
      expect(inSheet(find.text('👍 1')), findsOneWidget);
      expect(inSheet(find.text(en.taskDetailComments(2))), findsOneWidget);

      await tester.tap(inSheet(find.text(en.taskDetailShowComments)));
      await tester.pumpAndSettle();

      expect(inSheet(find.text(en.commentsStored(asOf))), findsOneWidget);
      expect(inSheet(find.text(en.commentsNeedConnection)), findsNothing);
      expect(inSheet(find.textContaining('Gate B12')), findsOneWidget);
      await tester.scrollUntilVisible(
        inSheet(find.textContaining('Seat 14A')),
        200,
        scrollable: inSheet(find.byType(Scrollable)).first,
      );
      expect(inSheet(find.textContaining('Seat 14A')), findsOneWidget);
      expect(data.details.calls, ['details 4', 'comments 4 page 1 oldest']);
    });

    testWidgets('an attachment in the download cache opens; one that is not '
        'needs a connection', (tester) async {
      await openDetail(tester);

      await tester.tap(inSheet(find.text('boarding-pass.pdf')));
      await tester.pumpAndSettle();
      expect(data.fileActions.calls, [
        'openWith /cache/attachments/4/5/boarding-pass.pdf application/pdf',
      ]);
      expect(find.byType(SnackBar), findsNothing);

      await tester.tap(inSheet(find.text('ticket.pdf')));
      await tester.pumpAndSettle();
      expect(find.text(en.attachmentNeedsConnection), findsOneWidget);
      expect(data.fileActions.calls, hasLength(1));
      expect(data.attachments.calls, ['download 4 5 cached', 'download 4 6']);
    });

    testWidgets('with the app offline, Delete and the cover are off and say '
        'why; open, share and save stay', (tester) async {
      final stored = data.details.storedDetailsByTask[4]!;
      data.details.storedDetailsByTask[4] = (
        value: stored.value.copyWith(coverImageAttachmentId: pass.id),
        readAt: stored.readAt,
      );
      await openDetail(tester);
      data.engine.emit(SyncFailed(failure: _offline, lastSyncedAt: now));
      await tester.pumpAndSettle();
      final semantics = tester.ensureSemantics();

      await tester.tap(
        inSheet(find.byTooltip(en.attachmentOptions('boarding-pass.pdf'))),
      );
      await tester.pumpAndSettle();
      PopupMenuItem<Object?> item(String label) =>
          tester.widget<PopupMenuItem<Object?>>(
            find.ancestor(
              of: find.text(label),
              matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
            ),
          );
      for (final action in [en.attachmentRemoveCover, en.attachmentDelete]) {
        expect(item(action).enabled, isFalse, reason: action);
        expect(
          tester.getSemantics(find.text(action)),
          matchesSemantics(
            label: action,
            hint: en.attachmentNeedsConnection,
            isButton: true,
            hasEnabledState: true,
          ),
          reason: action,
        );
      }
      for (final action in [
        en.attachmentOpen,
        en.attachmentShare,
        en.attachmentSaveToDevice,
      ]) {
        expect(item(action).enabled, isTrue, reason: action);
      }
      final error = Theme.of(tester.element(find.text(en.attachmentDelete)))
          .colorScheme
          .error;
      expect(
        tester.widget<Text>(find.text(en.attachmentDelete)).style?.color,
        isNot(error),
      );
      await tester.tap(find.text(en.attachmentDelete), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text(en.attachmentDeleteTitle), findsNothing);
      expect(data.attachments.calls, isEmpty);
      semantics.dispose();
    });

    testWidgets('with the app offline, a note at the top says so, and Try '
        'again syncs and reads the details again', (tester) async {
      await openDetail(tester);
      expect(
        find.descendant(of: sheet(), matching: find.byType(OfflineNotice)),
        findsNothing,
      );

      data.engine.emit(SyncFailed(failure: _offline, lastSyncedAt: now));
      await tester.pumpAndSettle();
      final note = inSheet(find.byType(OfflineNotice));
      expect(note, findsOneWidget);
      expect(
        tester.getTopLeft(note).dy,
        lessThan(tester.getTopLeft(inSheet(find.text('👍 1'))).dy),
      );
      final runs = data.engine.refreshInNewRunCalls;
      final reads = data.details.calls.where((c) => c == 'details 4').length;

      await tester.tap(
        find.descendant(of: note, matching: find.text(en.retry)),
      );
      await tester.pumpAndSettle();

      expect(data.engine.refreshInNewRunCalls, runs + 1);
      expect(
        data.details.calls.where((c) => c == 'details 4').length,
        reads + 1,
      );
    });

    testWidgets("Retry brings the server's once it answers", (tester) async {
      await openDetail(tester);

      data.details
        ..detailsFailure = null
        ..detailsByTask[4] = TaskDetails(attachments: [ticket]);
      await tester.tap(
        find.descendant(
          of: inSheet(
            find.ancestor(
              of: find.text(en.taskDetailDetailsStored(en.relativeHoursAgo(2))),
              matching: find.byType(Row),
            ),
          ),
          matching: find.text(en.retry),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        inSheet(find.text(en.taskDetailDetailsStored(en.relativeHoursAgo(2)))),
        findsNothing,
      );
      expect(inSheet(find.text('boarding-pass.pdf')), findsNothing);
      expect(inSheet(find.text('ticket.pdf')), findsOneWidget);
      expect(inSheet(find.text('👍 1')), findsNothing);
    });

    testWidgets('with nothing stored it says they need a connection, as '
        'before', (tester) async {
      data.details
        ..storedDetailsByTask.clear()
        ..storedCommentsByTask.clear();
      await openDetail(tester);

      expect(inSheet(find.text(en.taskDetailDetailsOffline)), findsOneWidget);
      expect(inSheet(find.text('boarding-pass.pdf')), findsNothing);
    });
  });

  group('a server that fails for a reason that may pass', () {
    for (final failure in const <VikunjaFailure>[
      ServerFailure(502),
      NotJsonResponse(200, message: 'text/html'),
    ]) {
      testWidgets('$failure: the stored ones stay with a note that does not '
          'ask for a connection', (tester) async {
        final asOf = en.relativeHoursAgo(2);
        data.details
          ..detailsFailure = failure
          ..commentsFailure = failure;
        await openDetail(tester);

        expect(
          inSheet(find.text(en.taskDetailDetailsStoredFailed(asOf))),
          findsOneWidget,
        );
        expect(
          inSheet(find.text(en.taskDetailDetailsStored(asOf))),
          findsNothing,
        );
        expect(inSheet(find.text(en.taskDetailDetailsFailed)), findsNothing);
        expect(inSheet(find.text('boarding-pass.pdf')), findsOneWidget);
        expect(inSheet(find.text('👍 1')), findsOneWidget);

        await tester.tap(inSheet(find.text(en.taskDetailShowComments)));
        await tester.pumpAndSettle();

        expect(
          inSheet(find.text(en.commentsStoredFailed(asOf))),
          findsOneWidget,
        );
        expect(inSheet(find.text(en.commentsStored(asOf))), findsNothing);
        expect(inSheet(find.textContaining('Gate B12')), findsOneWidget);
      });
    }

    testWidgets('a task that is gone shows as such, without the stored '
        'ones', (tester) async {
      data.details.detailsFailure = const NotFound(code: 4002);
      await openDetail(tester);

      expect(inSheet(find.text(en.taskDetailDetailsFailed)), findsOneWidget);
      expect(inSheet(find.text('boarding-pass.pdf')), findsNothing);
    });
  });

  testWidgets("online the stored ones stand in until the server's answer "
      'replaces them, without a note', (tester) async {
    final answer = Completer<void>();
    data.details
      ..detailsByTask[4] = TaskDetails(attachments: [ticket])
      ..beforeCall = (call) async {
        if (call.startsWith('details')) await answer.future;
      };
    await openDetail(tester);

    expect(inSheet(find.text('boarding-pass.pdf')), findsOneWidget);
    expect(
      inSheet(find.text(en.taskDetailDetailsStored(en.relativeHoursAgo(2)))),
      findsNothing,
    );

    answer.complete();
    await tester.pumpAndSettle();

    expect(inSheet(find.text('boarding-pass.pdf')), findsNothing);
    expect(inSheet(find.text('ticket.pdf')), findsOneWidget);
  });
}
