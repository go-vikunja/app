import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/auth/oauth_client.dart';
import 'package:vikunja_mobile/core/links/widget_link.dart';
import 'package:vikunja_mobile/core/links/widget_link_key.dart';
import 'package:vikunja_mobile/core/notifications/notification_actions.dart';
import 'package:vikunja_mobile/core/share/share_intent_source.dart';
import 'package:vikunja_mobile/features/share/presentation/share_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/comment_composer.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/comments_section.dart';
import 'package:vikunja_mobile/features/tasks/presentation/open/task_opener.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_pane.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

import '../../a11y/sweep_data.dart';
import '../../a11y/sweep_harness.dart' show routerOf;
import '../../helpers/auth_fakes.dart';
import '../../helpers/large_screens.dart';
import '../../helpers/notification_ui_fakes.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';
import '../../helpers/task_detail_panes.dart';
import '../inbox/inbox_samples.dart';
import '../teams/organise_harness.dart' show alice;

/// The install's widget-link key in these tests (32 bytes 0…31).
const _linkKey = 'AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8';

String _location(WidgetTester tester) =>
    routerOf(tester).routerDelegate.state.matchedLocation;

String _activeAccountId(WidgetTester tester) =>
    containerOf(tester).read(accountsProvider).value!.activeAccountId!;

Task _task(int id) => sweepData().tasks.all.firstWhere((task) => task.id == id);

Future<void> _inProject(WidgetTester tester) async {
  await openTab(tester, en.tabProjects);
  goTo(tester, AppRoutes.project(workProjectId));
  await tester.pumpAndSettle();
}

Future<void> _push(WidgetTester tester, Uri uri) async {
  expect(await tester.binding.handlePushRoute('$uri'), isTrue);
  await tester.pumpAndSettle();
}

final Finder _composerField = inPane(
  find.descendant(
    of: find.byType(CommentComposer),
    matching: find.byType(TextField),
  ),
);

List<TaskComment> _comments(int count) => [
  for (var id = 1; id <= count; id++)
    sampleComment(id: id, html: '<p>Comment number $id</p>'),
];

void _seedComments(SyncFakes data, int count) => data.details
  ..me = alice
  ..detailsByTask[1] = TaskDetails(
    commentCount: count,
    maxPermission: Permission.write,
  )
  ..commentsByTask[1] = _comments(count);

void main() {
  group("at 1280×800 in the Overview's pane, from another tab too", () {
    testWidgets('a task link', (tester) async {
      useWindow(tester, androidTabletLandscape);
      await pumpSweepApp(tester);
      await _inProject(tester);

      await _push(tester, Uri.parse('$oauthCallbackScheme://task/1'));
      expect(_location(tester), AppRoutes.overview);
      expectPane(tester, taskId: 1);
    });

    testWidgets("a widget's task", (tester) async {
      useWindow(tester, androidTabletLandscape);
      final auth = AuthFakes();
      auth.preferences.values[widgetLinkKeyPreference] = _linkKey;
      await pumpSweepApp(tester, auth: auth);
      await _inProject(tester);

      final link = WidgetTaskLink(
        accountId: _activeAccountId(tester),
        taskId: 6,
      ).toUri();
      await _push(
        tester,
        link.replace(queryParameters: {...link.queryParameters, 'k': _linkKey}),
      );
      expect(_location(tester), AppRoutes.overview);
      expectPane(tester, taskId: 6);
    });

    testWidgets('a notification about a comment, scrolled to it and tinted', (
      tester,
    ) async {
      useWindow(tester, androidTabletLandscape);
      final auth = AuthFakes();
      auth.preferences.values[widgetLinkKeyPreference] = _linkKey;
      final notifications = NotificationFakes();
      final data = sweepData();
      _seedComments(data, 30);
      data.activity.notifications = [
        inboxNotification(
          id: 5,
          name: 'task.comment',
          created: sweepNow,
          payload: {
            'doer': payloadUser(id: 9, username: 'anna', name: 'Anna'),
            'task': payloadTask(id: 1, title: 'Call the plumber'),
            'comment': {'id': 30, 'comment': '<p>Comment number 30</p>'},
          },
        ),
      ];
      await pumpSignedInApp(
        tester,
        sync: data,
        auth: auth,
        notifications: notifications,
        now: sweepNow,
        overrides: sweepRepositoryOverrides(),
      );
      await _inProject(tester);

      notifications.taps.tap(
        NotificationPayload(
          accountId: _activeAccountId(tester),
          taskId: 1,
          key: 'activity:5',
          linkKey: _linkKey,
        ).toJson(),
      );
      await tester.pumpAndSettle();
      expect(_location(tester), AppRoutes.overview);
      expectPane(tester, taskId: 1);
      final comment = inPane(find.text('Comment number 30'));
      expect(comment, findsOneWidget);
      final list = tester.getRect(inPane(find.byType(ListView)).first);
      expect(list.contains(tester.getCenter(comment)), isTrue);
      expect(
        tester
            .widget<CommentTile>(
              find.ancestor(of: comment, matching: find.byType(CommentTile)),
            )
            .highlighted,
        isTrue,
      );
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });

    testWidgets('"Open" after a share', (tester) async {
      useWindow(tester, androidTabletLandscape);
      final data = sweepData();
      data.shareSource.push(const IncomingShare(text: 'Buy milk'));
      await pumpSweepApp(tester, data: data);
      await tester.tap(
        find.descendant(
          of: find.byType(ShareSheet),
          matching: find.widgetWithText(TextButton, en.shareCreate),
        ),
      );
      await tester.pumpAndSettle();
      await _inProject(tester);

      await tester.tap(find.text(en.taskDuplicateOpen));
      await tester.pumpAndSettle();
      expect(_location(tester), AppRoutes.overview);
      expect(find.byType(TaskDetailPane), findsOneWidget);
      expect(tester.widget<TaskDetailSheet>(paneDetail).task.title, 'Buy milk');
    });
  });

  group('the sheet instead', () {
    testWidgets('at 800×1280', (tester) async {
      useWindow(tester, androidTabletPortrait);
      await pumpSweepApp(tester);
      await _push(tester, Uri.parse('$oauthCallbackScheme://task/1'));
      expectSheet(tester, taskId: 1);
    });

    testWidgets('with a page over the shell, which stays', (tester) async {
      useWindow(tester, androidTabletLandscape);
      await pumpSweepApp(tester);
      pushTo(tester, AppRoutes.taskEdit(4));
      await tester.pumpAndSettle();
      await _push(tester, Uri.parse('$oauthCallbackScheme://task/1'));
      expectSheet(tester, taskId: 1);
      expect(_location(tester), AppRoutes.taskEdit(4));
    });
  });

  testWidgets('the task already in the pane opens anew at the comment, with '
      'the draft typed just before', (tester) async {
    useWindow(tester, androidTabletLandscape);
    final data = sweepData();
    _seedComments(data, 3);
    await pumpSweepApp(tester, data: data);
    await tapTaskRow(tester, 1);
    final before = tester.state(paneDetail);
    await tester.enterText(_composerField, 'Half a thought');
    await tester.pump(const Duration(milliseconds: 100));

    unawaited(
      containerOf(tester)
          .read(taskOpenerProvider)
          .showTask(_task(1), commentId: 3),
    );
    await tester.pumpAndSettle();
    expectPane(tester, taskId: 1);
    expect(tester.state(paneDetail), isNot(same(before)));
    expect(tester.widget<TaskDetailSheet>(paneDetail).commentId, 3);
    expect(
      tester.widget<TextField>(_composerField).controller!.text,
      'Half a thought',
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
