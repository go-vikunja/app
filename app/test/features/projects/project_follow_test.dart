import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/sample_data.dart';
import '../../helpers/sync_fakes.dart';

void main() {
  final now = DateTime(2026, 10, 10, 12);
  late SyncFakes data;

  setUp(() {
    data = SyncFakes(now: now);
    data.projects.all = [
      sampleProject(id: 1, title: 'Work'),
      sampleProject(id: 3, title: 'Launch', parent: 1),
    ];
    data.tasks.all = [sampleTask(id: 1, title: 'Open 1')];
  });

  Future<void> pumpProject(WidgetTester tester, int projectId) async {
    await pumpSignedInApp(tester, sync: data, now: now);
    containerOf(tester)
        .read(appRouterProvider)
        .go(AppRoutes.project(projectId));
    await tester.pumpAndSettle();
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip(en.moreActions));
    await tester.pumpAndSettle();
  }

  testWidgets('Follow project follows it, and the menu then unfollows', (
    tester,
  ) async {
    await pumpProject(tester, 1);
    expect(data.subscriptions.calls, ['forProject 1']);

    await openMenu(tester);
    expect(find.text(en.unfollowProject), findsNothing);
    await tester.tap(find.text(en.followProject));
    await tester.pumpAndSettle();

    expect(data.subscriptions.calls.last, 'setProject 1 true');
    expect(find.text(en.projectFollowed), findsOneWidget);

    await openMenu(tester);
    await tester.tap(find.text(en.unfollowProject));
    await tester.pumpAndSettle();

    expect(data.subscriptions.calls.last, 'setProject 1 false');
    expect(find.text(en.projectUnfollowed), findsOneWidget);
  });

  testWidgets('a subscription inherited from the parent asks before it opts '
      'this project out', (tester) async {
    data.subscriptions.projectStates[3] = const Subscription(
      entity: SubscriptionEntity.project,
      entityId: 1,
    );
    await pumpProject(tester, 3);

    await openMenu(tester);
    await tester.tap(find.text(en.unfollowProject));
    await tester.pumpAndSettle();

    expect(find.text(en.followInheritedProjectTitle), findsOneWidget);
    expect(find.text(en.followInheritedProjectBody('Work')), findsOneWidget);
    await tester.tap(find.text(en.followInheritedConfirm));
    await tester.pumpAndSettle();

    expect(data.subscriptions.calls, ['forProject 3', 'setProject 3 false']);
    expect(find.text(en.projectUnfollowed), findsOneWidget);
  });

  testWidgets('offline the item says why and asks the server again', (
    tester,
  ) async {
    data.subscriptions.readFailure = const NetworkFailure(
      NetworkProblem.timeout,
    );
    await pumpProject(tester, 1);

    await openMenu(tester);
    await tester.tap(find.text(en.followProject));
    await tester.pumpAndSettle();

    expect(find.text(en.followNeedsConnection), findsOneWidget);
    expect(data.subscriptions.calls, ['forProject 1', 'forProject 1']);
  });

  testWidgets('while the state loads the item says so and cannot be '
      'tapped', (tester) async {
    final loaded = Completer<void>();
    data.subscriptions.beforeCall = (_) => loaded.future;
    await pumpProject(tester, 1);

    await openMenu(tester);
    expect(find.text(en.followProject), findsNothing);
    final item = tester.widget<PopupMenuItem<Object?>>(
      find.ancestor(
        of: find.text(en.followChecking),
        matching: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
      ),
    );
    expect(item.enabled, isFalse);
    await tester.tap(find.text(en.followChecking), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(data.subscriptions.calls, ['forProject 1']);

    loaded.complete();
    await tester.tapAt(const Offset(20, 400));
    await tester.pumpAndSettle();
    expect(find.text(en.followChecking), findsNothing);
    await openMenu(tester);
    await tester.tap(find.text(en.followProject));
    await tester.pumpAndSettle();

    expect(data.subscriptions.calls.last, 'setProject 1 true');
  });

  testWidgets('a failed change says so', (tester) async {
    data.subscriptions.writeFailure = const ServerFailure(503);
    await pumpProject(tester, 1);

    await openMenu(tester);
    await tester.tap(find.text(en.followProject));
    await tester.pumpAndSettle();

    expect(find.text(en.followFailed), findsOneWidget);
    expect(find.text(en.projectFollowed), findsNothing);
  });
}
