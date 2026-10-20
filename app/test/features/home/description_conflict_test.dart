import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/widgets/status_card.dart';
import 'package:vikunja_mobile/core/outbox/sync_problem.dart';
import 'package:vikunja_mobile/core/time/clock_provider.dart';
import 'package:vikunja_mobile/features/home/presentation/description_conflict_sheet.dart';
import 'package:vikunja_mobile/features/home/presentation/sync_problem_message.dart';

import '../../helpers/auth_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  late AuthFakes auth;
  late SyncFakes data;
  late DateTime now;
  late SyncProblem conflict;

  setUp(() {
    auth = AuthFakes();
    now = DateTime.now().toUtc();
    data = SyncFakes(now: now);
    data.tasks.all = [
      sampleTask(id: 1, title: 'Pay the bill', description: '<p>Mine</p>'),
    ];
    conflict = SyncProblem(
      operationId: 'op-1',
      kind: OutboxOperationKind.updateTask,
      taskId: 1,
      taskTitle: 'Pay the bill',
      failure: const DescriptionConflict(),
      failedAt: now.subtract(const Duration(minutes: 5)),
      changes: const TaskChanges(
        description: '<p>Mine</p>',
        descriptionBase: '<p>Before</p>',
      ),
    );
    data.tasks
      ..syncProblems = [conflict]
      ..pendingChanges = 1;
  });

  Future<void> pumpAccountTab(WidgetTester tester) async {
    await auth.seedAccount(fullServer270(), tokens: issueTokens(issuedAt: now));
    usePhoneSurface(tester, logicalSize: const Size(360, 1800));
    await pumpVikunjaApp(
      tester,
      auth: auth,
      sync: data,
      overrides: [clockProvider.overrideWithValue(() => now)],
    );
    await openTab(tester, en.tabAccount);
  }

  Future<void> compare(WidgetTester tester) async {
    await tester.tap(find.text(en.syncProblemCompare));
    await tester.pumpAndSettle();
  }

  Finder inSheet(Finder finder) => find.descendant(
    of: find.byType(DescriptionConflictSheet),
    matching: finder,
  );

  testWidgets('a description also changed on the web offers to compare the '
      'versions instead of Retry and Discard', (tester) async {
    await pumpAccountTab(tester);

    expect(find.byType(StatusCard), findsOneWidget);
    expect(find.text(describeSyncProblem(en, conflict)), findsOneWidget);
    expect(find.text(en.syncProblemCompare), findsOneWidget);
    expect(find.text(en.retry), findsNothing);
    expect(find.text(en.syncProblemDiscard), findsNothing);
  });

  testWidgets('the comparison shows both versions; Keep my version '
      'overwrites exactly the web version shown', (tester) async {
    data.tasks.webDescriptions[1] = '<p>From the web</p>';
    await pumpAccountTab(tester);

    await compare(tester);

    expect(inSheet(find.text(en.syncProblemYourVersion)), findsOneWidget);
    expect(inSheet(find.text('Mine')), findsOneWidget);
    expect(inSheet(find.text(en.syncProblemWebVersion)), findsOneWidget);
    expect(inSheet(find.text('From the web')), findsOneWidget);
    expect(data.tasks.writes, isEmpty);

    await tester.tap(inSheet(find.text(en.syncProblemKeepMine)));
    await tester.pumpAndSettle();

    expect(data.tasks.writes, ['keepMine op-1 over <p>From the web</p>']);
    expect(find.byType(StatusCard), findsNothing);
  });

  testWidgets("Use the web version takes the server's description", (
    tester,
  ) async {
    data.tasks.webDescriptions[1] = '<p>From the web</p>';
    await pumpAccountTab(tester);

    await compare(tester);
    await tester.tap(inSheet(find.text(en.syncProblemUseWebs)));
    await tester.pumpAndSettle();

    expect(data.tasks.writes, ['useWebs op-1']);
    expect(find.byType(StatusCard), findsNothing);
    expect(data.tasks.find(1)!.description, '<p>From the web</p>');
  });

  testWidgets('closing the comparison changes nothing', (tester) async {
    data.tasks.webDescriptions[1] = '<p>From the web</p>';
    await pumpAccountTab(tester);

    await compare(tester);
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    expect(find.byType(DescriptionConflictSheet), findsNothing);
    expect(data.tasks.writes, isEmpty);
    expect(find.byType(StatusCard), findsOneWidget);
  });

  testWidgets('a task the server no longer has offers only to discard the '
      'change', (tester) async {
    await pumpAccountTab(tester);

    await compare(tester);

    expect(inSheet(find.text(en.syncProblemWebTaskGone)), findsOneWidget);
    expect(inSheet(find.text(en.syncProblemKeepMine)), findsNothing);
    await tester.tap(inSheet(find.text(en.syncProblemDiscard)));
    await tester.pumpAndSettle();
    expect(data.tasks.writes, ['useWebs op-1']);
  });

  testWidgets('a comparison that cannot read the server keeps the card and '
      'says why', (tester) async {
    data.tasks.webDescriptionFailure = const NetworkFailure(
      NetworkProblem.unreachable,
    );
    await pumpAccountTab(tester);

    await compare(tester);

    expect(find.byType(DescriptionConflictSheet), findsNothing);
    expect(
      find.text(en.failureUnreachableExplanation('tasks.example.org')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextButton>(
            find.ancestor(
              of: find.text(en.syncProblemCompare),
              matching: find.byWidgetPredicate((w) => w is TextButton),
            ),
          )
          .onPressed,
      isNotNull,
    );
    expect(data.tasks.writes, isEmpty);
  });

  testWidgets('Use the web version that cannot read the server keeps the '
      'card and says why', (tester) async {
    data.tasks
      ..webDescriptions[1] = '<p>From the web</p>'
      ..useWebDescriptionFailure = const NetworkFailure(
        NetworkProblem.unreachable,
      );
    await pumpAccountTab(tester);

    await compare(tester);
    await tester.tap(inSheet(find.text(en.syncProblemUseWebs)));
    await tester.pumpAndSettle();

    expect(find.text('Pay the bill'), findsOneWidget);
    expect(
      find.text(en.failureUnreachableExplanation('tasks.example.org')),
      findsOneWidget,
    );
    expect(data.tasks.find(1)!.description, '<p>Mine</p>');
  });
}
