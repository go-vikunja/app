import 'dart:async';

import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_page.dart';
import 'package:vikunja_mobile/features/description_editor/presentation/mention_bar.dart';
import 'package:vikunja_mobile/features/inbox/presentation/inbox_button.dart';
import 'package:vikunja_mobile/features/overview/presentation/overview_screen.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/comment_composer.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/reaction_chips.dart';
import 'package:vikunja_mobile/features/tasks/presentation/favourite_button.dart';
import 'package:vikunja_mobile/features/tasks/presentation/follow/follow_button.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/assignee_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/pickers/label_picker.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_row.dart';
import 'package:vikunja_mobile/features/trash/presentation/trash_page.dart';

import '../helpers/auth_fakes.dart';
import '../helpers/guest_app.dart';
import '../helpers/label_user_fakes.dart';
import '../helpers/pump_app.dart';
import '../helpers/sample_data.dart';
import '../helpers/server_connections.dart';
import '../helpers/sync_fakes.dart';

const _needsUser =
    'the server refuses what it does for anyone who is not a user';
const _ownersProject =
    "the shared project is its owner's to describe, rename, set up views "
    'for and share';

/// Every route outside `AppRoutes.openToGuests`, by its full path, with the
/// reason a guest is kept from it.
const closedToGuests = <String, String>{
  '/home/project/:id/description': _ownersProject,
  '/home/project/:id/edit': _ownersProject,
  '/home/project/:id/views': _ownersProject,
  '/home/project/:id/share': _ownersProject,
  '/home/inbox': 'the server keeps no notifications for a guest',
  '/home/labels': _needsUser,
  '/home/labels/new': _needsUser,
  '/home/labels/:id/edit': _needsUser,
  '/home/labels/:id/description': _needsUser,
  '/home/teams': _needsUser,
  '/home/teams/:id': _needsUser,
  '/home/teams/:id/description': _needsUser,
  '/home/trash': 'the server shows a guest no bin',
  '/home/filters/new': _needsUser,
  '/home/filters/:id/edit': _needsUser,
  '/home/account-settings': _needsUser,
  '/home/account-settings/avatar': _needsUser,
  '/home/account-settings/sessions': _needsUser,
  '/home/account-settings/api-tokens': _needsUser,
  '/home/account-settings/api-tokens/new': _needsUser,
  '/home/account-settings/caldav': _needsUser,
  '/home/account-settings/data-export': _needsUser,
};

void main() {
  const anna = User(id: 5, username: 'anna', name: 'Anna');
  const ben = User(id: 6, username: 'ben', name: 'Ben');
  late AuthFakes auth;
  late SyncFakes data;

  setUp(() {
    auth = AuthFakes();
    data = SyncFakes();
    data.tasks.all = [
      sampleTask(id: 4, title: 'Water the plants', projectId: guestProjectId),
    ];
  });

  Future<void> go(WidgetTester tester, String location) async {
    containerOf(tester).read(appRouterProvider).go(location);
    await tester.pumpAndSettle();
  }

  Future<void> push(WidgetTester tester, String location) async {
    unawaited(containerOf(tester).read(appRouterProvider).push(location));
    await tester.pumpAndSettle();
  }

  String location(WidgetTester tester) =>
      containerOf(tester)
          .read(appRouterProvider)
          .routerDelegate
          .currentConfiguration
          .uri
          .path;

  BuildContext navigatorContext(WidgetTester tester) =>
      containerOf(tester)
          .read(appRouterProvider)
          .routerDelegate
          .navigatorKey
          .currentContext!;

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip(en.moreActions).first);
    await tester.pumpAndSettle();
  }

  Finder inSheet(Finder finder) =>
      find.descendant(of: find.byType(TaskDetailSheet), matching: finder);

  testWidgets('every route is open to guests or closed to them with a '
      'reason, so a new route has to decide', (tester) async {
    await pumpVikunjaApp(tester);
    final configuration = containerOf(tester)
        .read(appRouterProvider)
        .configuration;
    final routes = <String>{};
    void walk(List<RouteBase> children) {
      for (final route in children) {
        if (route is GoRoute) {
          routes.add(configuration.locationForRoute(route)!);
        }
        walk(route.routes);
      }
    }

    walk(configuration.routes);
    const open = AppRoutes.openToGuests;
    final closed = closedToGuests.keys.toSet();

    expect(
      routes.difference({...open, ...closed}),
      isEmpty,
      reason:
          'add each route to AppRoutes.openToGuests or to closedToGuests '
          'in this file',
    );
    expect({...open, ...closed}.difference(routes), isEmpty);
    expect(open.intersection(closed), isEmpty);
  });

  testWidgets('a guest sent to a closed page lands on the Overview', (
    tester,
  ) async {
    await pumpGuestApp(tester, auth: auth, data: data);

    for (final route in closedToGuests.keys) {
      final closed = route
          .replaceAll(':commentId', '7')
          .replaceAll(':id', '$guestProjectId');
      await go(tester, closed);
      expect(location(tester), AppRoutes.overview, reason: closed);
      expect(find.byType(OverviewScreen), findsOneWidget, reason: closed);
    }
    await push(tester, AppRoutes.accountSettings);
    expect(find.byType(AccountSettingsPage), findsNothing);
  });

  testWidgets('a guest opens the pages open to it whatever their ids', (
    tester,
  ) async {
    await pumpGuestApp(
      tester,
      auth: auth,
      data: data,
      overrides: [
        labelRepositoryProvider.overrideWithValue(
          FakeLabelRepository(labels: [sampleLabel(id: 5, title: 'Outside')]),
        ),
      ],
    );

    for (final open in [
      AppRoutes.project(guestProjectId),
      AppRoutes.taskEdit(4),
      AppRoutes.labelTasks(5),
      AppRoutes.search,
      AppRoutes.widgets,
      AppRoutes.privacy,
      AppRoutes.about,
    ]) {
      await go(tester, open);
      expect(location(tester), open, reason: open);
    }
  });

  testWidgets('a guest on a server with the bin pushed to it lands on the '
      'Overview', (tester) async {
    await pumpGuestApp(
      tester,
      auth: auth,
      data: data,
      permission: Permission.write,
      connection: fullServer280(),
    );

    await push(tester, AppRoutes.trash);

    expect(find.byType(TrashPage), findsNothing);
    expect(location(tester), AppRoutes.overview);
    expect(find.byType(OverviewScreen), findsOneWidget);
    expect(data.trash.calls, isEmpty);
  });

  testWidgets('the Overview greets a guest without a name', (tester) async {
    await pumpGuestApp(tester, auth: auth, data: data);

    final nameless = [
      en.overviewGreetingMorningGuest,
      en.overviewGreetingAfternoonGuest,
      en.overviewGreetingEveningGuest,
    ].where((greeting) => find.text(greeting).evaluate().isNotEmpty);
    expect(nameless, hasLength(1));
    for (final name in ['Helper', 'Garden']) {
      for (final named in [
        en.overviewGreetingMorning(name),
        en.overviewGreetingAfternoon(name),
        en.overviewGreetingEvening(name),
      ]) {
        expect(find.text(named), findsNothing, reason: named);
      }
    }
  });

  testWidgets('a guest whose access ended is told to open the link again', (
    tester,
  ) async {
    await pumpGuestApp(tester, auth: auth, data: data);
    data.engine.onRefresh = () async => throw const LinkShareGone();

    await pullToRefresh(tester, find.byType(CustomScrollView));

    expect(
      find.text(en.guestDataFailureAccessEnded('tasks.example.org')),
      findsOneWidget,
    );
    expect(
      find.text(en.dataFailureSessionEnded('tasks.example.org')),
      findsNothing,
    );
  });

  testWidgets('the Overview has no bell and Upcoming no inbox for a guest', (
    tester,
  ) async {
    await pumpGuestApp(tester, auth: auth, data: data);

    expect(find.byType(InboxButton), findsNothing);
    await openTab(tester, en.tabUpcoming);
    await openMenu(tester);
    expect(find.text(en.refresh), findsOneWidget);
    expect(find.text(en.inboxButton(0)), findsNothing);
  });

  testWidgets('the Projects tab offers a guest no new project or saved '
      'filter', (tester) async {
    await pumpGuestApp(tester, auth: auth, data: data);
    await openTab(tester, en.tabProjects);

    expect(find.text('Garden'), findsOneWidget);
    expect(find.byTooltip(en.projectNew), findsNothing);
    await openMenu(tester);
    expect(find.text(en.projectsShowArchived), findsOneWidget);
    expect(find.text(en.savedFilterNew), findsNothing);
    expect(find.text(en.projectsShowSavedFilters), findsNothing);
  });

  testWidgets("the Projects tab's empty state offers a guest nothing to "
      'create', (tester) async {
    data.projects.all = [guestProject().copyWith(isArchived: true)];
    await pumpGuestApp(tester, auth: auth, data: data);
    await openTab(tester, en.tabProjects);

    expect(find.text(en.projectsEmptyTitle), findsOneWidget);
    expect(find.text(en.projectNew), findsNothing);
    expect(find.text(en.savedFilterNew), findsNothing);
  });

  group('the shared project of a write guest', () {
    Future<void> pumpProject(
      WidgetTester tester, {
      List<Override> overrides = const [],
    }) async {
      usePhoneSurface(tester, logicalSize: const Size(400, 1600));
      await pumpGuestApp(
        tester,
        auth: auth,
        data: data,
        permission: Permission.write,
        overrides: overrides,
      );
      await go(tester, AppRoutes.project(guestProjectId));
    }

    testWidgets('keeps new tasks but offers no favourite, follow, edit, '
        'archive, copy, subproject or share', (tester) async {
      await pumpProject(tester);

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byTooltip(en.projectAddToFavourites), findsNothing);
      await openMenu(tester);
      expect(find.text(en.refresh), findsOneWidget);
      for (final item in [
        en.projectEdit,
        en.projectArchive,
        en.shareMenuItem,
        en.projectAddToFavourites,
        en.followProject,
        en.projectDuplicate,
        en.projectNewSubproject,
        en.projectViews,
        en.projectDelete,
      ]) {
        expect(find.text(item), findsNothing, reason: item);
      }
      expect(data.subscriptions.calls, isEmpty);
    });

    testWidgets("an admin guest can neither delete the owner's project nor "
        'set up its views', (tester) async {
      data.projects.all = [guestProject(permission: Permission.admin)];
      await pumpProject(tester);
      await openMenu(tester);

      expect(find.text(en.refresh), findsOneWidget);
      for (final item in [
        en.projectViews,
        en.projectDelete,
        en.projectEdit,
        en.shareMenuItem,
      ]) {
        expect(find.text(item), findsNothing, reason: item);
      }
    });

    testWidgets('rows have no star, but their checkbox works', (tester) async {
      await pumpProject(tester);

      final row = find.widgetWithText(TaskRow, 'Water the plants');
      expect(
        find.descendant(of: row, matching: find.byType(FavouriteButton)),
        findsNothing,
      );
      await tester.tap(
        find.descendant(of: row, matching: find.byTooltip(en.taskMarkDone)),
      );
      await tester.pumpAndSettle();
      expect(data.tasks.writes, ['setDone 4 true']);
    });

    testWidgets('the task sheet keeps edits and comments without follow, '
        'favourite and reactions', (tester) async {
      data.details.detailsByTask[4] = const TaskDetails(
        maxPermission: Permission.write,
        reactions: {
          '👍': [anna],
        },
      );
      await pumpProject(tester);

      await tester.tap(find.text('Water the plants'));
      await tester.pumpAndSettle();

      expect(inSheet(find.byTooltip(en.taskEdit)), findsOneWidget);
      expect(inSheet(find.text(en.taskDetailMarkDone)), findsOneWidget);
      expect(inSheet(find.byType(FollowButton)), findsNothing);
      expect(inSheet(find.byType(FavouriteButton)), findsNothing);
      final reactions = tester.widget<ReactionChips>(
        inSheet(find.byType(ReactionChips)),
      );
      expect(reactions.onToggle, isNull);
      expect(reactions.onAdd, isNull);
      await tester.scrollUntilVisible(
        inSheet(find.byType(CommentComposer)),
        300,
        scrollable: inSheet(find.byType(Scrollable)).first,
      );
      expect(
        tester
            .widget<CommentComposer>(inSheet(find.byType(CommentComposer)))
            .enabled,
        isTrue,
      );
    });

    testWidgets('@ in a comment suggests the people this device knows '
        'without asking the server', (tester) async {
      final users = FakeUserRepository(
        known: const [anna],
        projectUsers: {
          guestProjectId: const [anna, ben],
        },
      );
      data.details.detailsByTask[4] = const TaskDetails(
        maxPermission: Permission.write,
      );
      await pumpProject(
        tester,
        overrides: [userRepositoryProvider.overrideWithValue(users)],
      );
      await tester.tap(find.text('Water the plants'));
      await tester.pumpAndSettle();

      final field = inSheet(
        find.descendant(
          of: find.byType(CommentComposer),
          matching: find.byType(TextField),
        ),
      );
      await tester.scrollUntilVisible(
        field,
        300,
        scrollable: inSheet(find.byType(Scrollable)).first,
      );
      await tester.enterText(field, 'Thanks @');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(users.searches, isEmpty);
      final bar = inSheet(find.byType(MentionBar));
      expect(
        find.descendant(of: bar, matching: find.text('Anna')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: bar, matching: find.text('Ben')),
        findsNothing,
      );
    });
  });

  testWidgets('the label picker offers a guest no new label and says why', (
    tester,
  ) async {
    final labels = FakeLabelRepository(
      labels: [sampleLabel(id: 5, title: 'Outside')],
    );
    await pumpGuestApp(
      tester,
      auth: auth,
      data: data,
      overrides: [labelRepositoryProvider.overrideWithValue(labels)],
    );

    unawaited(pickLabels(navigatorContext(tester), selected: const []));
    await tester.pumpAndSettle();
    expect(find.text(en.guestLabelPickerNote), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Brand new');
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text(en.labelPickerCreate('Brand new')), findsNothing);
    expect(labels.created, isEmpty);
  });

  testWidgets('the people picker of a guest never asks the server and '
      'offers the people this device knows', (tester) async {
    final users = FakeUserRepository(
      known: const [anna],
      projectUsers: {
        guestProjectId: const [anna, ben],
      },
    );
    await pumpGuestApp(
      tester,
      auth: auth,
      data: data,
      overrides: [userRepositoryProvider.overrideWithValue(users)],
    );

    unawaited(
      pickAssignees(
        navigatorContext(tester),
        projectId: guestProjectId,
        selected: const [],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.enterText(find.byType(TextField), 'n');
    await tester.pump(AssigneePicker.debounce);
    await tester.pumpAndSettle();

    expect(users.searches, isEmpty);
    expect(find.text('Anna'), findsOneWidget);
    expect(find.text('Ben'), findsNothing);
    expect(find.text(en.assigneePickerOffline), findsNothing);
  });
}
