/// The kanban board, driven end to end: the board widget, its bucket columns,
/// the column header menu and the task list inside each column.
///
/// They are exercised together because that is how a user meets them — the
/// board builds the columns, and the columns build the lists.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vikunja_app/domain/entities/bucket.dart';
import 'package:vikunja_app/domain/entities/project.dart';
import 'package:vikunja_app/domain/entities/view_kind.dart';
import 'package:vikunja_app/presentation/pages/error_widget.dart';
import 'package:vikunja_app/presentation/pages/loading_widget.dart';
import 'package:vikunja_app/presentation/pages/task/task_edit_page.dart';
import 'package:vikunja_app/presentation/widgets/bucket_limit_dialog.dart';
import 'package:vikunja_app/presentation/widgets/project/kanban/add_bucket_dialog.dart';
import 'package:vikunja_app/presentation/widgets/project/kanban/bucket_column.dart';
import 'package:vikunja_app/presentation/widgets/project/kanban/bucket_delete_dialog.dart'
    as kanban;
import 'package:vikunja_app/presentation/widgets/project/kanban/bucket_header.dart';
import 'package:vikunja_app/presentation/widgets/project/kanban/change_title_dialog.dart';
import 'package:vikunja_app/presentation/widgets/project/kanban/kanban_task_item.dart';
import 'package:vikunja_app/presentation/widgets/project/kanban/kanban_widget.dart';
import 'package:vikunja_app/presentation/widgets/task/add_task_dialog.dart';

import '../../../../helpers/builders.dart';
import '../../../../helpers/fake_controllers.dart';
import '../../../../helpers/plugin_mocks.dart';
import '../../../../helpers/test_app.dart';

void main() {
  setUpAll(loadL10n);

  late ControllerCalls calls;
  late FakeOutcome outcome;
  late TestRepositories repos;
  late Project project;

  setUp(() {
    mockPlatformPlugins();
    calls = ControllerCalls();
    outcome = FakeOutcome();
    repos = TestRepositories();
    project = buildProject(
      id: 1,
      title: 'Board',
      views: [
        buildView(
          id: 20,
          projectId: 1,
          kind: ViewKind.kanban,
          title: 'Kanban',
          doneBucketId: 0,
          defaultBucketId: 0,
        ),
      ],
    );
  });

  /// Rebuilds the project so its single kanban view carries the given
  /// done/default bucket ids.
  void withMarkedColumns({int doneBucketId = 0, int defaultBucketId = 0}) {
    project = buildProject(
      id: 1,
      title: 'Board',
      views: [
        buildView(
          id: 20,
          projectId: 1,
          kind: ViewKind.kanban,
          title: 'Kanban',
          doneBucketId: doneBucketId,
          defaultBucketId: defaultBucketId,
        ),
      ],
    );
  }

  Future<ProviderContainer> pumpBoard(
    WidgetTester tester, {
    List<Bucket>? buckets,
    bool signedIn = true,
    bool loadingNextPage = false,
    Size surfaceSize = phoneSurface,
  }) async {
    final container = await pumpApp(
      tester,
      KanbanWidget(project: project),
      inScaffold: true,
      surfaceSize: surfaceSize,
      overrides: [
        ...repos.overrides,
        if (signedIn) currentUserOverride(buildUser()),
        projectOverride(
          project,
          buildProjectPageModel(
            project,
            buckets: buckets ?? [buildBucket(id: 50, title: 'Todo')],
            isLoadingNextPage: loadingNextPage,
          ),
          calls,
          outcome,
        ),
      ],
    );
    await tester.pumpAndSettle();
    return container;
  }

  /// Opens the overflow menu of the first bucket column.
  Future<void> openColumnMenu(WidgetTester tester) async {
    await tapAndSettle(
      tester,
      find.descendant(
        of: find.byType(BucketHeader).first,
        matching: find.byIcon(Icons.more_vert),
      ),
    );
  }

  group('the board', () {
    testWidgets('renders a column per bucket', (tester) async {
      await pumpBoard(
        tester,
        buckets: [
          buildBucket(id: 50, title: 'Todo'),
          buildBucket(id: 51, title: 'Doing'),
        ],
      );

      expect(find.byType(BucketColumn), findsNWidgets(2));
      expect(find.text('Todo'), findsOneWidget);
      expect(find.text('Doing'), findsOneWidget);
    });

    testWidgets('renders the tasks inside a column', (tester) async {
      await pumpBoard(
        tester,
        buckets: [
          buildBucket(
            id: 50,
            tasks: [
              buildTask(id: 1, title: 'First'),
              buildTask(id: 2, title: 'Second'),
            ],
          ),
        ],
      );

      expect(find.byType(TaskTile), findsNWidgets(2));
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
    });

    testWidgets('offers an add-bucket button', (tester) async {
      await pumpBoard(tester);

      expect(find.text(l10n.kanbanAddBucket), findsOneWidget);
    });

    testWidgets('shows a loader while the controller is still building', (
      tester,
    ) async {
      await pumpApp(
        tester,
        KanbanWidget(project: project),
        inScaffold: true,
        overrides: [
          ...repos.overrides,
          projectControllerProviderOverridePending(project),
        ],
      );
      await tester.pump();

      expect(find.byType(LoadingWidget), findsOneWidget);
    });

    testWidgets('shows an error view when the load fails', (tester) async {
      await pumpApp(
        tester,
        KanbanWidget(project: project),
        inScaffold: true,
        overrides: [
          ...repos.overrides,
          projectControllerProviderOverrideFailing(project),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byType(VikunjaErrorWidget), findsOneWidget);
    });

    testWidgets('shows a spinner in a column while the next page loads', (
      tester,
    ) async {
      await pumpApp(
        tester,
        KanbanWidget(project: project),
        inScaffold: true,
        overrides: [
          ...repos.overrides,
          currentUserOverride(buildUser()),
          projectOverride(
            project,
            buildProjectPageModel(
              project,
              buckets: [buildBucket(id: 50)],
              isLoadingNextPage: true,
            ),
            calls,
            outcome,
          ),
        ],
      );
      await tester.pump();

      expect(find.byType(BucketColumn), findsOneWidget);
    });
  });

  group('adding a bucket', () {
    testWidgets('the add button opens the add dialog', (tester) async {
      await pumpBoard(tester);

      await tapAndSettle(tester, find.text(l10n.kanbanAddBucket));

      expect(find.byType(AddBucketDialog), findsOneWidget);
    });

    testWidgets('confirming the dialog creates the bucket in this view', (
      tester,
    ) async {
      await pumpBoard(tester);

      await tapAndSettle(tester, find.text(l10n.kanbanAddBucket));
      await enterTextAndSettle(tester, find.byType(TextField), 'In review');
      await tapAndSettle(tester, find.text(l10n.add));

      expect(calls.addedBuckets.single.title, 'In review');
      expect(calls.addedBuckets.single.projectViewId, 20);
      expect(calls.addedBuckets.single.limit, 0);
    });

    testWidgets('a successful add confirms with a snackbar', (tester) async {
      await pumpBoard(tester);

      await tapAndSettle(tester, find.text(l10n.kanbanAddBucket));
      await enterTextAndSettle(tester, find.byType(TextField), 'In review');
      await tapAndSettle(tester, find.text(l10n.add));

      expect(find.text(l10n.bucketAddedSuccess), findsOneWidget);
    });

    testWidgets('a failed add reports the error', (tester) async {
      outcome.succeeds = false;
      await pumpBoard(tester);

      await tapAndSettle(tester, find.text(l10n.kanbanAddBucket));
      await enterTextAndSettle(tester, find.byType(TextField), 'In review');
      await tapAndSettle(tester, find.text(l10n.add));

      expect(find.text(l10n.bucketAddError), findsOneWidget);
    });

    testWidgets('adding is skipped when nobody is signed in', (tester) async {
      await pumpBoard(tester, signedIn: false);

      await tapAndSettle(tester, find.text(l10n.kanbanAddBucket));
      await enterTextAndSettle(tester, find.byType(TextField), 'In review');
      await tapAndSettle(tester, find.text(l10n.add));

      expect(calls.addedBuckets, isEmpty);
    });
  });

  group('the column header', () {
    testWidgets('shows the bucket title', (tester) async {
      await pumpBoard(tester, buckets: [buildBucket(title: 'Doing')]);

      expect(find.text('Doing'), findsOneWidget);
    });

    testWidgets('shows the task count against the limit', (tester) async {
      await pumpBoard(
        tester,
        buckets: [
          buildBucket(limit: 5, tasks: [buildTask(id: 1), buildTask(id: 2)]),
        ],
      );

      expect(find.text('2/5'), findsOneWidget);
    });

    testWidgets('hides the count when there is no limit', (tester) async {
      await pumpBoard(
        tester,
        buckets: [
          buildBucket(limit: 0, tasks: [buildTask(id: 1)]),
        ],
      );

      expect(find.textContaining('/'), findsNothing);
    });

    testWidgets('marks the done column with a tick', (tester) async {
      withMarkedColumns(doneBucketId: 50);

      await pumpBoard(tester, buckets: [buildBucket(id: 50)]);

      expect(find.byIcon(Icons.done_all), findsOneWidget);
    });

    testWidgets('does not mark an ordinary column', (tester) async {
      await pumpBoard(tester, buckets: [buildBucket(id: 50)]);

      expect(find.byIcon(Icons.done_all), findsNothing);
    });

    testWidgets('the menu lists every column action', (tester) async {
      await pumpBoard(tester);

      await openColumnMenu(tester);

      expect(find.text('Change name'), findsOneWidget);
      expect(find.text('Limit: Not set'), findsOneWidget);
      expect(find.text('Done Column'), findsOneWidget);
      expect(find.text('Default Column'), findsOneWidget);
      expect(find.text('Collapse column'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('the menu shows the current limit', (tester) async {
      await pumpBoard(tester, buckets: [buildBucket(limit: 7)]);

      await openColumnMenu(tester);

      expect(find.text('Limit: 7'), findsOneWidget);
    });
  });

  group('adding a task to a column', () {
    testWidgets('the column add button opens the add dialog', (tester) async {
      await pumpBoard(tester);

      await tapAndSettle(
        tester,
        find.descendant(
          of: find.byType(BucketHeader).first,
          matching: find.byIcon(Icons.add),
        ),
      );

      expect(find.byType(AddTaskDialog), findsOneWidget);
    });

    testWidgets('confirming the dialog creates the task in that bucket', (
      tester,
    ) async {
      await pumpBoard(tester, buckets: [buildBucket(id: 55)]);

      await tapAndSettle(
        tester,
        find.descendant(
          of: find.byType(BucketHeader).first,
          matching: find.byIcon(Icons.add),
        ),
      );
      await enterTextAndSettle(tester, find.byType(TextField), 'New card');
      await tapAndSettle(tester, find.text(l10n.add));

      expect(calls.addedTasks.single.title, 'New card');
      expect(calls.addedTasks.single.bucketId, 55);
      expect(calls.addedTasks.single.projectId, 1);
    });

    testWidgets('a successful add confirms with a snackbar', (tester) async {
      await pumpBoard(tester);

      await tapAndSettle(
        tester,
        find.descendant(
          of: find.byType(BucketHeader).first,
          matching: find.byIcon(Icons.add),
        ),
      );
      await enterTextAndSettle(tester, find.byType(TextField), 'New card');
      await tapAndSettle(tester, find.text(l10n.add));

      expect(find.text(l10n.taskAddedSuccess), findsOneWidget);
    });

    testWidgets('a failed add reports the error', (tester) async {
      outcome.succeeds = false;
      await pumpBoard(tester);

      await tapAndSettle(
        tester,
        find.descendant(
          of: find.byType(BucketHeader).first,
          matching: find.byIcon(Icons.add),
        ),
      );
      await enterTextAndSettle(tester, find.byType(TextField), 'New card');
      await tapAndSettle(tester, find.text(l10n.add));

      expect(find.text(l10n.taskAddError), findsOneWidget);
    });

    testWidgets('adding is skipped when nobody is signed in', (tester) async {
      await pumpBoard(tester, signedIn: false);

      await tapAndSettle(
        tester,
        find.descendant(
          of: find.byType(BucketHeader).first,
          matching: find.byIcon(Icons.add),
        ),
      );
      await enterTextAndSettle(tester, find.byType(TextField), 'New card');
      await tapAndSettle(tester, find.text(l10n.add));

      expect(calls.addedTasks, isEmpty);
    });
  });

  group('renaming a column', () {
    testWidgets('the menu action opens the rename dialog', (tester) async {
      await pumpBoard(tester);

      await openColumnMenu(tester);
      await tapAndSettle(tester, find.text('Change name'));

      expect(find.byType(ChangeTitleDialog), findsOneWidget);
    });

    testWidgets('confirming the dialog saves the new title', (tester) async {
      await pumpBoard(tester, buckets: [buildBucket(id: 50, title: 'Todo')]);

      await openColumnMenu(tester);
      await tapAndSettle(tester, find.text('Change name'));
      await enterTextAndSettle(tester, find.byType(TextField), 'Doing');
      await tapAndSettle(tester, find.text(l10n.done));

      expect(calls.updatedBuckets.single.title, 'Doing');
    });

    testWidgets('cancelling the dialog saves nothing', (tester) async {
      await pumpBoard(tester);

      await openColumnMenu(tester);
      await tapAndSettle(tester, find.text('Change name'));
      await tapAndSettle(tester, find.text(l10n.cancel));

      expect(calls.updatedBuckets, isEmpty);
    });

    testWidgets('a failed rename reports the error', (tester) async {
      outcome.succeeds = false;
      await pumpBoard(tester);

      await openColumnMenu(tester);
      await tapAndSettle(tester, find.text('Change name'));
      await enterTextAndSettle(tester, find.byType(TextField), 'Doing');
      await tapAndSettle(tester, find.text(l10n.done));

      expect(find.text(l10n.bucketUpdateError), findsOneWidget);
    });
  });

  group('setting a column limit', () {
    testWidgets('the menu action opens the limit dialog', (tester) async {
      await pumpBoard(tester);

      await openColumnMenu(tester);
      await tapAndSettle(tester, find.text('Limit: Not set'));

      expect(find.byType(BucketLimitDialog), findsOneWidget);
    });

    testWidgets('confirming the dialog saves the new limit', (tester) async {
      await pumpBoard(tester, buckets: [buildBucket(id: 50, limit: 3)]);

      await openColumnMenu(tester);
      await tapAndSettle(tester, find.text('Limit: 3'));
      await tapAndSettle(tester, find.byIcon(Icons.expand_less));
      await tapAndSettle(tester, find.text(l10n.done));

      expect(calls.updatedBuckets.single.limit, 4);
    });

    testWidgets('removing the limit saves zero', (tester) async {
      await pumpBoard(tester, buckets: [buildBucket(id: 50, limit: 3)]);

      await openColumnMenu(tester);
      await tapAndSettle(tester, find.text('Limit: 3'));
      await tapAndSettle(tester, find.text(l10n.removeLimit));

      expect(calls.updatedBuckets.single.limit, 0);
    });

    testWidgets('cancelling the dialog saves nothing', (tester) async {
      await pumpBoard(tester);

      await openColumnMenu(tester);
      await tapAndSettle(tester, find.text('Limit: Not set'));
      await tapAndSettle(tester, find.text(l10n.cancel));

      expect(calls.updatedBuckets, isEmpty);
    });

    testWidgets('a failed save reports the error', (tester) async {
      outcome.succeeds = false;
      await pumpBoard(tester, buckets: [buildBucket(id: 50, limit: 3)]);

      await openColumnMenu(tester);
      await tapAndSettle(tester, find.text('Limit: 3'));
      await tapAndSettle(tester, find.text(l10n.done));

      expect(find.text(l10n.bucketUpdateError), findsOneWidget);
    });
  });

  group('marking the done and default columns', () {
    testWidgets('Done Column marks the column', (tester) async {
      await pumpBoard(tester);

      await openColumnMenu(tester);
      await tapAndSettle(tester, find.text('Done Column'));

      expect(calls.called('updateDoneBucket'), isTrue);
    });

    testWidgets('a failed done-column change reports the error', (
      tester,
    ) async {
      outcome.succeeds = false;
      await pumpBoard(tester);

      await openColumnMenu(tester);
      await tapAndSettle(tester, find.text('Done Column'));

      expect(find.text(l10n.bucketUpdateError), findsOneWidget);
    });

    testWidgets('Default Column marks the column', (tester) async {
      await pumpBoard(tester);

      await openColumnMenu(tester);
      await tapAndSettle(tester, find.text('Default Column'));

      expect(calls.called('selectDefaultBucket'), isTrue);
    });

    testWidgets('a failed default-column change reports the error', (
      tester,
    ) async {
      outcome.succeeds = false;
      await pumpBoard(tester);

      await openColumnMenu(tester);
      await tapAndSettle(tester, find.text('Default Column'));

      expect(find.text(l10n.bucketUpdateError), findsOneWidget);
    });
  });

  group('collapsing a column', () {
    testWidgets('Collapse column hides the column body', (tester) async {
      await pumpBoard(
        tester,
        buckets: [
          buildBucket(
            id: 50,
            title: 'Todo',
            tasks: [buildTask(title: 'Card')],
          ),
        ],
      );

      await openColumnMenu(tester);
      await tapAndSettle(tester, find.text('Collapse column'));

      expect(find.byType(BucketHeader), findsNothing);
      expect(find.text('Card'), findsNothing);
      expect(find.text('Todo'), findsOneWidget);
    });

    testWidgets('tapping a collapsed column expands it again', (tester) async {
      await pumpBoard(
        tester,
        buckets: [
          buildBucket(
            id: 50,
            title: 'Todo',
            tasks: [buildTask(title: 'Card')],
          ),
        ],
      );

      await openColumnMenu(tester);
      await tapAndSettle(tester, find.text('Collapse column'));
      await tapAndSettle(tester, find.text('Todo'));

      expect(find.byType(BucketHeader), findsOneWidget);
      expect(find.text('Card'), findsOneWidget);
    });
  });

  group('deleting a column', () {
    testWidgets('the menu action asks for confirmation', (tester) async {
      await pumpBoard(tester);

      await openColumnMenu(tester);
      await tapAndSettle(tester, find.text('Delete'));

      expect(find.byType(kanban.TaskDeleteDialog), findsOneWidget);
      expect(find.text(l10n.deleteBucketMessage), findsOneWidget);
    });

    testWidgets('confirming deletes the bucket', (tester) async {
      await pumpBoard(tester, buckets: [buildBucket(id: 50)]);

      await openColumnMenu(tester);
      await tapAndSettle(tester, find.text('Delete'));
      await tapAndSettle(tester, find.text(l10n.delete));

      expect(calls.deletedBuckets.single.id, 50);
    });

    testWidgets('cancelling deletes nothing', (tester) async {
      await pumpBoard(tester);

      await openColumnMenu(tester);
      await tapAndSettle(tester, find.text('Delete'));
      await tapAndSettle(tester, find.text(l10n.cancel));

      expect(calls.deletedBuckets, isEmpty);
    });

    testWidgets('a failed delete reports the error', (tester) async {
      outcome.succeeds = false;
      await pumpBoard(tester);

      await openColumnMenu(tester);
      await tapAndSettle(tester, find.text('Delete'));
      await tapAndSettle(tester, find.text(l10n.delete));

      expect(find.text(l10n.bucketDeleteError), findsOneWidget);
    });
  });

  group('opening a card', () {
    testWidgets('tapping a card opens the task editor', (tester) async {
      await pumpBoard(
        tester,
        buckets: [
          buildBucket(tasks: [buildTask(id: 1, title: 'Card', priority: 0)]),
        ],
      );

      await tapAndSettle(tester, find.text('Card'));

      expect(find.byType(TaskEditPage), findsOneWidget);
    });
  });

  group('dragging', () {
    // The board lays out fixed 300px columns side by side, and a drag needs the
    // source and destination on screen together. Everything else on the board
    // renders at phone width, where its dialogs have to fit.
    const roomForTwoColumns = Size(1000, 800);

    testWidgets('long-pressing a card lifts it', (tester) async {
      await pumpBoard(
        tester,
        surfaceSize: roomForTwoColumns,
        buckets: [
          buildBucket(
            id: 50,
            tasks: [buildTask(id: 1, title: 'Card', priority: 0)],
          ),
          buildBucket(id: 51, title: 'Doing'),
        ],
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Card')),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump();

      // The card now appears twice: the faded original and the drag feedback.
      expect(find.text('Card'), findsNWidgets(2));

      // Release over the add-bucket button, which is not a drop target.
      await gesture.moveTo(tester.getCenter(find.text(l10n.kanbanAddBucket)));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
    });

    /// Lifts the column titled [column] and drops it before the first column.
    Future<void> dropColumnFirst(WidgetTester tester, String column) async {
      final gesture = await tester.startGesture(
        tester.getCenter(find.text(column)),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(
        tester.getTopLeft(find.byType(BucketColumn).first) +
            const Offset(-4, 100),
      );
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
    }

    testWidgets('long-pressing a column header lifts the column', (
      tester,
    ) async {
      await pumpBoard(
        tester,
        surfaceSize: roomForTwoColumns,
        buckets: [
          buildBucket(id: 50, title: 'Todo'),
          buildBucket(id: 51, title: 'Doing'),
        ],
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Todo')),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveBy(const Offset(120, 0));
      await tester.pump();

      expect(find.text('Todo'), findsNWidgets(2));

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('dropping a column in a new slot saves its position', (
      tester,
    ) async {
      await pumpBoard(
        tester,
        surfaceSize: roomForTwoColumns,
        buckets: [
          buildBucket(id: 50, title: 'Todo'),
          buildBucket(id: 51, title: 'Doing'),
        ],
      );

      await dropColumnFirst(tester, 'Doing');

      expect(calls.updatedBuckets.single.id, 51);
      expect(calls.updatedBuckets.single.position, isNotNull);
    });

    testWidgets('a failed column move reports the error', (tester) async {
      outcome.succeeds = false;
      await pumpBoard(
        tester,
        surfaceSize: roomForTwoColumns,
        buckets: [
          buildBucket(id: 50, title: 'Todo'),
          buildBucket(id: 51, title: 'Doing'),
        ],
      );

      await dropColumnFirst(tester, 'Doing');

      expect(find.text(l10n.bucketUpdateError), findsOneWidget);
    });
  });
}
