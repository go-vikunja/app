import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/features/tasks/presentation/follow/follow_button.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/server_connections.dart';
import '../../helpers/sync_fakes.dart';

// Before Vikunja 2.6.0 the server answers an unfollow of a task or subproject
// that a followed (parent) project covers with a 403: only unfollowing that
// project stops the follow.
void main() {
  final now = DateTime(2026, 10, 10, 12);
  late SyncFakes data;

  const throughWork = Subscription(
    entity: SubscriptionEntity.project,
    entityId: 1,
  );

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [
      sampleProject(id: 1, title: 'Work'),
      sampleProject(id: 3, title: 'Launch', parent: 1),
    ];
    data.tasks.all = [sampleTask(id: 2, title: 'Bare task', identifier: 'W-2')];
  });

  group('the task bell', () {
    Finder sheet() => find.byType(TaskDetailSheet).last;

    Finder inSheet(Finder matching) =>
        find.descendant(of: sheet(), matching: matching);

    IconButton bell(WidgetTester tester) => tester.widget<IconButton>(
      inSheet(
        find.descendant(
          of: find.byType(FollowButton),
          matching: find.byType(IconButton),
        ),
      ),
    );

    Future<void> openDetail(
      WidgetTester tester,
      ServerConnection connection,
    ) async {
      usePhoneSurface(tester, logicalSize: const Size(360, 1800));
      await pumpSignedInApp(
        tester,
        sync: data,
        now: now,
        connection: connection,
      );
      await tester.tap(find.text('Bare task').first);
      await tester.pumpAndSettle();
    }

    Future<void> tapBell(WidgetTester tester) async {
      await tester.tap(inSheet(find.byType(FollowButton)));
      await tester.pumpAndSettle();
    }

    testWidgets('a follow through the project stays on and a tap says how '
        'to stop it, without asking the server', (tester) async {
      data.subscriptions.taskStates[2] = throughWork;
      data.details.detailsByTask[2] = const TaskDetails(
        subscription: throughWork,
      );
      await openDetail(tester, fullServer250());

      expect(bell(tester).isSelected, isTrue);
      expect(inSheet(find.byTooltip(en.followingViaSomeProject)), findsOne);
      expect(inSheet(find.byTooltip(en.unfollowTask)), findsNothing);
      expect(inSheet(find.text(en.followingViaProject('Work'))), findsOne);

      await tapBell(tester);

      expect(find.text(en.followInheritedTaskTitle), findsNothing);
      expect(inSheet(find.text(en.followInheritedFixed('Work'))), findsOne);
      expect(data.subscriptions.calls, isEmpty);
      expect(bell(tester).isSelected, isTrue);
    });

    testWidgets('its own follow still unfollows', (tester) async {
      const own = Subscription(entity: SubscriptionEntity.task, entityId: 2);
      data.subscriptions.taskStates[2] = own;
      data.details.detailsByTask[2] = const TaskDetails(subscription: own);
      await openDetail(tester, fullServer250());

      expect(inSheet(find.byTooltip(en.unfollowTask)), findsOne);
      await tapBell(tester);

      expect(data.subscriptions.calls, ['setTask 2 false']);
      expect(bell(tester).isSelected, isFalse);
    });

    testWidgets('2.3.0 over v1 has no opt-outs either', (tester) async {
      data.subscriptions.taskStates[2] = throughWork;
      data.details.detailsByTask[2] = const TaskDetails(
        subscription: throughWork,
      );
      await openDetail(tester, oauthServer230());

      await tapBell(tester);

      expect(inSheet(find.text(en.followInheritedFixed('Work'))), findsOne);
      expect(data.subscriptions.calls, isEmpty);
    });

    testWidgets('a v2 server whose version cannot be read gets the opt-out '
        'once the user confirms; an older one refusing it fails as before', (
      tester,
    ) async {
      data.subscriptions.taskStates[2] = throughWork;
      data.details.detailsByTask[2] = const TaskDetails(
        subscription: throughWork,
      );
      data.subscriptions.writeFailure = const Forbidden();
      await openDetail(tester, unknownVersionServer(v2: true));

      expect(inSheet(find.byTooltip(en.unfollowTask)), findsOne);
      await tapBell(tester);
      await tester.tap(find.text(en.followInheritedConfirm));
      await tester.pumpAndSettle();

      expect(data.subscriptions.calls, ['setTask 2 false']);
      expect(find.text(en.followFailed), findsOne);
      expect(bell(tester).isSelected, isTrue);
    });

    testWidgets('2.7.0 opts the task out after asking, as before', (
      tester,
    ) async {
      data.subscriptions.taskStates[2] = throughWork;
      data.details.detailsByTask[2] = const TaskDetails(
        subscription: throughWork,
      );
      await openDetail(tester, fullServer270());

      expect(inSheet(find.byTooltip(en.unfollowTask)), findsOne);
      await tapBell(tester);
      await tester.tap(find.text(en.followInheritedConfirm));
      await tester.pumpAndSettle();

      expect(data.subscriptions.calls, ['setTask 2 false']);
      expect(bell(tester).isSelected, isFalse);
    });
  });

  group("the project menu's follow item", () {
    Future<void> openMenuOf(
      WidgetTester tester,
      int projectId,
      ServerConnection connection,
    ) async {
      await pumpSignedInApp(
        tester,
        sync: data,
        now: now,
        connection: connection,
      );
      containerOf(tester)
          .read(appRouterProvider)
          .go(AppRoutes.project(projectId));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(en.moreActions));
      await tester.pumpAndSettle();
    }

    testWidgets('a subproject followed through its parent is labelled as '
        'such and a tap says how to stop it, without asking the server', (
      tester,
    ) async {
      data.subscriptions.projectStates[3] = throughWork;
      await openMenuOf(tester, 3, fullServer250());

      expect(find.text(en.unfollowProject), findsNothing);
      await tester.tap(find.text(en.followingViaSomeProject));
      await tester.pumpAndSettle();

      expect(find.text(en.followInheritedProjectTitle), findsNothing);
      expect(find.text(en.followInheritedFixed('Work')), findsOne);
      expect(data.subscriptions.calls, ['forProject 3']);
    });

    testWidgets('the parent itself still unfollows', (tester) async {
      data.subscriptions.projectStates[1] = throughWork;
      await openMenuOf(tester, 1, fullServer250());

      await tester.tap(find.text(en.unfollowProject));
      await tester.pumpAndSettle();

      expect(data.subscriptions.calls, ['forProject 1', 'setProject 1 false']);
      expect(find.text(en.projectUnfollowed), findsOne);
    });

    testWidgets('2.7.0 opts the subproject out after asking, as before', (
      tester,
    ) async {
      data.subscriptions.projectStates[3] = throughWork;
      await openMenuOf(tester, 3, fullServer270());

      await tester.tap(find.text(en.unfollowProject));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.followInheritedConfirm));
      await tester.pumpAndSettle();

      expect(data.subscriptions.calls, ['forProject 3', 'setProject 3 false']);
    });
  });
}
