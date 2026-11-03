import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:vikunja_app/presentation/pages/task/comment_edit_page.dart';
import 'package:vikunja_app/presentation/pages/task/task_comments_page.dart';
import 'package:vikunja_app/presentation/widgets/task/task_comments.dart';

import '../../../helpers/builders.dart';
import '../../../helpers/fake_controllers.dart';
import '../../../helpers/plugin_mocks.dart';
import '../../../helpers/test_app.dart';

/// `CommentEditPage` embeds an `HtmlEditor`, which needs a `flutter_inappwebview`
/// platform implementation that does not exist in a widget test. Tests that open
/// it therefore assert the navigation and consume the webview's build assertion;
/// the editor's own save logic is covered through
/// `TaskCommentsController` in `test/presentation/manager/`.
Future<void> openEditorAndDiscardWebviewError(
  WidgetTester tester,
  Finder trigger,
) async {
  await tester.tap(trigger);
  await tester.pump();
  await tester.pump();
  expect(tester.takeException(), isNotNull);
}

void main() {
  setUpAll(loadL10n);

  const taskId = 100;

  late ControllerCalls calls;
  late FakeOutcome outcome;
  late TestRepositories repos;

  setUp(() {
    mockPlatformPlugins();
    calls = ControllerCalls();
    outcome = FakeOutcome();
    repos = TestRepositories();
  });

  Future<void> pumpComments(
    WidgetTester tester, {
    List<dynamic> comments = const [],
    int currentUserId = 1,
  }) async {
    await pumpApp(
      tester,
      const TaskCommentsPage(taskId: taskId, taskTitle: 'Ship it'),
      overrides: [
        ...repos.overrides,
        currentUserOverride(buildUser(id: currentUserId)),
        commentsOverride(taskId, comments.cast(), calls, outcome),
      ],
    );
    await tester.pumpAndSettle();
  }

  group('the comments page', () {
    testWidgets('titles itself with the task name', (tester) async {
      await pumpComments(tester);

      // Once in the app bar, once as the section header inside the list.
      expect(find.text(l10n.comments), findsNWidgets(2));
      expect(find.text('Ship it'), findsOneWidget);
    });
  });

  group('the comment list', () {
    testWidgets('says so when there are no comments', (tester) async {
      await pumpComments(tester);

      expect(find.text(l10n.noComments), findsOneWidget);
    });

    testWidgets('renders one card per comment', (tester) async {
      await pumpComments(
        tester,
        comments: [
          buildComment(id: 1, comment: '<p>First</p>'),
          buildComment(id: 2, comment: '<p>Second</p>'),
        ],
      );

      expect(find.textContaining('First', findRichText: true), findsOneWidget);
      expect(find.textContaining('Second', findRichText: true), findsOneWidget);
    });

    testWidgets('names the author', (tester) async {
      await pumpComments(
        tester,
        comments: [
          buildComment(
            author: buildUser(id: 3, username: 'jdoe', name: 'Jane'),
          ),
        ],
      );

      expect(find.text('Jane'), findsOneWidget);
    });

    testWidgets('falls back to the username when there is no name', (
      tester,
    ) async {
      await pumpComments(
        tester,
        comments: [buildComment(author: buildUser(id: 3, username: 'jdoe'))],
      );

      expect(find.text('jdoe'), findsOneWidget);
    });

    testWidgets('shows only the creation time for an unedited comment', (
      tester,
    ) async {
      final created = DateTime.utc(2024, 3, 14, 15, 9);
      await pumpComments(
        tester,
        comments: [buildComment(created: created, updated: created)],
      );

      final formatted = DateFormat.yMd().add_jm().format(created.toLocal());
      expect(find.text(formatted), findsOneWidget);
    });

    testWidgets('marks an edited comment', (tester) async {
      await pumpComments(
        tester,
        comments: [
          buildComment(
            created: DateTime.utc(2024, 3, 14, 15, 9),
            updated: DateTime.utc(2024, 3, 15, 10, 0),
          ),
        ],
      );

      expect(find.textContaining(l10n.commentEdited), findsOneWidget);
    });

    testWidgets('reports a failure to load the comments', (tester) async {
      await pumpApp(
        tester,
        const TaskCommentsPage(taskId: taskId, taskTitle: 'Ship it'),
        overrides: [
          ...repos.overrides,
          currentUserOverride(buildUser()),
          commentsControllerProviderOverrideFailing(taskId),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.commentsLoadError), findsOneWidget);
    });
  });

  group('the comment menu', () {
    testWidgets('is offered on your own comment', (tester) async {
      await pumpComments(
        tester,
        currentUserId: 3,
        comments: [buildComment(author: buildUser(id: 3))],
      );

      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('is not offered on somebody else’s comment', (tester) async {
      await pumpComments(
        tester,
        currentUserId: 1,
        comments: [buildComment(author: buildUser(id: 3))],
      );

      expect(find.byIcon(Icons.more_vert), findsNothing);
    });

    testWidgets('offers edit and delete', (tester) async {
      await pumpComments(
        tester,
        currentUserId: 3,
        comments: [buildComment(author: buildUser(id: 3))],
      );

      await tapAndSettle(tester, find.byIcon(Icons.more_vert));

      expect(find.text(l10n.edit), findsOneWidget);
      expect(find.text(l10n.delete), findsOneWidget);
    });

    testWidgets('choosing edit opens the editor with the comment', (
      tester,
    ) async {
      await pumpComments(
        tester,
        currentUserId: 3,
        comments: [
          buildComment(id: 7, comment: '<p>Mine</p>', author: buildUser(id: 3)),
        ],
      );

      await tapAndSettle(tester, find.byIcon(Icons.more_vert));
      await openEditorAndDiscardWebviewError(tester, find.text(l10n.edit));

      expect(find.byType(CommentEditPage), findsOneWidget);
      expect(find.text(l10n.editCommentTitle), findsOneWidget);
    });
  });

  group('deleting a comment', () {
    Future<void> openDeleteDialog(WidgetTester tester) async {
      await tapAndSettle(tester, find.byIcon(Icons.more_vert));
      await tapAndSettle(tester, find.text(l10n.delete));
    }

    testWidgets('asks for confirmation', (tester) async {
      await pumpComments(
        tester,
        currentUserId: 3,
        comments: [buildComment(author: buildUser(id: 3))],
      );

      await openDeleteDialog(tester);

      expect(find.text(l10n.deleteCommentTitle), findsOneWidget);
      expect(find.text(l10n.deleteCommentConfirm), findsOneWidget);
    });

    testWidgets('confirming deletes the comment', (tester) async {
      await pumpComments(
        tester,
        currentUserId: 3,
        comments: [buildComment(id: 7, author: buildUser(id: 3))],
      );

      await openDeleteDialog(tester);
      await tapAndSettle(tester, find.text(l10n.delete).last);

      expect(calls.deletedCommentIds, [7]);
    });

    testWidgets('cancelling deletes nothing', (tester) async {
      await pumpComments(
        tester,
        currentUserId: 3,
        comments: [buildComment(id: 7, author: buildUser(id: 3))],
      );

      await openDeleteDialog(tester);
      await tapAndSettle(tester, find.text(l10n.cancel));

      expect(calls.deletedCommentIds, isEmpty);
    });

    testWidgets('a failed delete reports the error', (tester) async {
      outcome.succeeds = false;
      await pumpComments(
        tester,
        currentUserId: 3,
        comments: [buildComment(id: 7, author: buildUser(id: 3))],
      );

      await openDeleteDialog(tester);
      await tapAndSettle(tester, find.text(l10n.delete).last);

      expect(find.text(l10n.commentDeleteError), findsOneWidget);
    });
  });

  group('adding a comment', () {
    testWidgets('the add button opens an empty editor', (tester) async {
      await pumpComments(tester);

      await openEditorAndDiscardWebviewError(
        tester,
        find.descendant(
          of: find.byType(TaskComments),
          matching: find.byIcon(Icons.add),
        ),
      );

      expect(find.byType(CommentEditPage), findsOneWidget);
      expect(find.text(l10n.addCommentTitle), findsOneWidget);
    });
  });
}
