import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/widgets/widget_config.dart';
import 'package:vikunja_mobile/features/description_editor/application/description_target.dart';
import 'package:vikunja_mobile/features/description_editor/presentation/description_editor_page.dart';
import 'package:vikunja_mobile/features/inbox/presentation/inbox_screen.dart';
import 'package:vikunja_mobile/features/labels/presentation/label_form_page.dart';
import 'package:vikunja_mobile/features/labels/presentation/labels_page.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/project_edit_page.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/project_views_page.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_list_body.dart';
import 'package:vikunja_mobile/features/search/presentation/search_page.dart';
import 'package:vikunja_mobile/features/sharing/presentation/project_share_page.dart';
import 'package:vikunja_mobile/features/smart_lists/presentation/label_tasks_screen.dart';
import 'package:vikunja_mobile/features/smart_lists/presentation/saved_filter_form_page.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/task_edit_page.dart';
import 'package:vikunja_mobile/features/teams/presentation/team_page.dart';
import 'package:vikunja_mobile/features/teams/presentation/teams_page.dart';
import 'package:vikunja_mobile/features/trash/presentation/trash_page.dart';
import 'package:vikunja_mobile/features/trash/presentation/trash_rows.dart';
import 'package:vikunja_mobile/features/widgets/presentation/widget_configure_page.dart';
import 'package:vikunja_mobile/features/widgets/presentation/widgets_page.dart';

import '../features/inbox/inbox_samples.dart';
import '../features/teams/organise_harness.dart';
import '../features/widgets/widget_pages_harness.dart';
import '../helpers/auth_fakes.dart';
import '../helpers/editor_bridge_fakes.dart';
import '../helpers/guest_app.dart';
import '../helpers/pump_app.dart';
import '../helpers/sample_data.dart';
import '../helpers/server_connections.dart';
import '../helpers/sync_fakes.dart';
import '../helpers/team_sharing_fakes.dart';
import 'sweep_data.dart';
import 'sweep_harness.dart';

const _teamId = 5;
const _commentId = 2;

/// A page pushed over the shell, signed in with [sweepData].
SweepScenario _page(
  String pattern,
  String location,
  Type page, {
  void Function(SyncFakes data)? seed,
  bool editor = false,
  Object? extra,
  SweepStep? after,
}) => SweepScenario.route(
  pattern,
  setUp: (tester, _) async {
    final data = sweepData();
    seed?.call(data);
    await pumpSweepApp(
      tester,
      data: data,
      overrides: [if (editor) FakeEditorBridges().override],
    );
  },
  navigate: (tester, l10n) async {
    pushTo(tester, location, extra: extra);
    if (after != null) {
      await tester.pumpAndSettle();
      await after(tester, l10n);
    }
  },
  expectScreen: (_) => find.byType(page),
);

void _seedTeams(SyncFakes data) => data.teams.teams = [
  sampleTeam(
    id: _teamId,
    name: 'Gardeners',
    description: '<p>Who waters what, and when.</p>',
    isPublic: true,
    members: const [
      TeamMember(user: alice, admin: true),
      TeamMember(user: kim),
      TeamMember(user: ben),
    ],
  ),
  sampleTeam(id: 6, name: 'Synced from the sign-in', isExternal: true),
];

void _seedShares(SyncFakes data) => data.sharing
  ..people = [kim, ben]
  ..projects[workProjectId] = FakeProjectShares(
    users: const [
      ProjectUserShare(user: kim, permission: Permission.write),
      ProjectUserShare(user: ben, permission: Permission.read),
    ],
    teams: const [
      ProjectTeamShare(
        teamId: _teamId,
        teamName: 'Gardeners',
        memberCount: 3,
        permission: Permission.write,
      ),
    ],
    links: [
      LinkShare(
        id: 5,
        hash: fakeLinkShareHash(5),
        permission: Permission.read,
        name: 'Family',
        passwordProtected: true,
        sharedBy: alice,
      ),
    ],
  );

void _seedInbox(SyncFakes data) {
  final doer = payloadUser(id: 9, username: 'kim', name: 'Kim Lee');
  final task = payloadTask(id: 1, title: 'Call the plumber', identifier: 'W-1');
  data.activity.notifications = [
    for (final (index, name) in [
      'task.comment',
      'task.assigned',
      'task.mentioned',
      'project.created',
      'team.member.added',
      'task.reminder',
    ].indexed)
      inboxNotification(
        id: 100 - index,
        name: name,
        created: sweepNow.subtract(Duration(hours: index * 9)),
        readAt: index.isEven ? null : sweepNow,
        payload: {
          'doer': doer,
          'task': task,
          'project': {'id': workProjectId, 'title': 'Work'},
          'comment': {'id': 1, 'comment': '<p>Done on Friday?</p>'},
          'assignee': payloadUser(id: 11, username: 'ben'),
          'member': payloadUser(id: 11, username: 'ben'),
          'team': {'id': _teamId, 'name': 'Gardeners'},
        },
      ),
  ];
}

void _seedComment(SyncFakes data) => data.details
  ..me = alice
  ..commentsByTask[1] = [_ownComment];

/// Three tasks, deleted by alice, by Kim (who is not admin of the
/// project) and through a link share, and a project with two subprojects.
void _seedTrash(SyncFakes data) => data.trash
  ..trashedTasks = [
    TrashedTask(
      task: sampleTask(id: 31, title: 'Fix the gate'),
      deletedAt: sweepNow.subtract(const Duration(days: 3)).toUtc(),
      deletedBy: alice,
      canDeletePermanently: true,
    ),
    TrashedTask(
      task: sampleTask(
        id: 32,
        title: 'Order compost',
        projectId: gardenProjectId,
      ),
      deletedAt: sweepNow.subtract(const Duration(days: 12)).toUtc(),
      deletedBy: kim,
    ),
    TrashedTask(
      task: sampleTask(id: 33, title: 'Sweep the porch'),
      deletedAt: sweepNow.subtract(const Duration(days: 30)).toUtc(),
      deletedBy: const User(
        id: -5,
        username: 'link-share-5',
        name: 'Link Share',
      ),
      canDeletePermanently: true,
    ),
  ]
  ..trashedProjects = [
    TrashedProject(
      project: sampleProject(id: 40, title: 'Old house', hexColor: 'e8445a'),
      deletedAt: sweepNow.subtract(const Duration(days: 1)).toUtc(),
      deletedBy: alice,
      subprojects: const [
        TrashedSubproject(
          id: 41,
          title: 'Kitchen',
          parentProjectId: 40,
          depth: 1,
        ),
        TrashedSubproject(
          id: 42,
          title: 'Attic',
          parentProjectId: 40,
          depth: 1,
        ),
      ],
    ),
  ];

/// The bin on a 2.8.0 server, on its [variant] tab, where [shows] is.
SweepScenario _trash(
  String variant, {
  Type shows = TrashPage,
  SweepStep? after,
}) => SweepScenario.route(
  AppRoutes.trash,
  variant: variant,
  setUp: (tester, _) async {
    final data = sweepData();
    _seedTrash(data);
    await pumpSignedInApp(
      tester,
      sync: data,
      now: sweepNow,
      connection: fullServer280(),
      overrides: sweepRepositoryOverrides(),
    );
  },
  navigate: (tester, l10n) async {
    pushTo(tester, AppRoutes.trash);
    if (after != null) {
      await tester.pumpAndSettle();
      await after(tester, l10n);
    }
  },
  expectScreen: (_) => find.byType(shows),
);

final TaskComment _ownComment = sampleComment(
  id: _commentId,
  author: alice,
  html: '<p>Asked for Friday.</p>',
);

/// The pages over the shell, from a task, a project, the Account tab and
/// the search.
final List<SweepScenario> pageRouteScenarios = [
  _page(
    '${AppRoutes.home}/tasks/:id/edit',
    AppRoutes.taskEdit(1),
    TaskEditPage,
  ),
  _page(
    '${AppRoutes.home}/tasks/:id/description',
    AppRoutes.taskDescription(1),
    DescriptionEditorPage,
    editor: true,
  ),
  _page(
    '${AppRoutes.home}/tasks/:id/comments/:commentId/edit',
    AppRoutes.commentEdit(1, _commentId),
    DescriptionEditorPage,
    editor: true,
    seed: _seedComment,
    extra: CommentTarget(
      taskId: 1,
      projectId: workProjectId,
      comment: _ownComment,
    ),
  ),
  _page(
    '${AppRoutes.home}/project/:id/description',
    AppRoutes.projectDescription(workProjectId),
    DescriptionEditorPage,
    editor: true,
  ),
  _page(
    '${AppRoutes.home}/project/:id/edit',
    AppRoutes.projectEdit(workProjectId),
    ProjectEditPage,
  ),
  _page(
    '${AppRoutes.home}/project/:id/views',
    AppRoutes.projectViews(workProjectId),
    ProjectViewsPage,
  ),
  _page(
    '${AppRoutes.home}/project/:id/share',
    AppRoutes.projectShare(workProjectId),
    ProjectSharePage,
    seed: (data) {
      _seedShares(data);
      _seedTeams(data);
    },
  ),
  _page(AppRoutes.inbox, AppRoutes.inbox, InboxScreen, seed: _seedInbox),
  _page(
    AppRoutes.search,
    AppRoutes.search,
    SearchPage,
    after: (tester, _) async {
      await tester.enterText(find.byType(TextField), 'the');
      await tester.pump(const Duration(seconds: 1));
    },
  ),
  _page(AppRoutes.labels, AppRoutes.labels, LabelsPage),
  _page(AppRoutes.labelNew, AppRoutes.labelNew, LabelFormPage),
  _page(
    '${AppRoutes.labels}/:id',
    AppRoutes.labelTasks(errands.id),
    LabelTasksScreen,
  ),
  _page(
    '${AppRoutes.labels}/:id/edit',
    AppRoutes.labelEdit(errands.id),
    LabelFormPage,
  ),
  _page(
    '${AppRoutes.labels}/:id/description',
    AppRoutes.labelDescription(errands.id),
    DescriptionEditorPage,
    editor: true,
  ),
  _page(AppRoutes.teams, AppRoutes.teams, TeamsPage, seed: _seedTeams),
  _page(
    '${AppRoutes.teams}/:id',
    AppRoutes.team(_teamId),
    TeamPage,
    seed: _seedTeams,
  ),
  _page(
    '${AppRoutes.teams}/:id/description',
    AppRoutes.teamDescription(_teamId),
    DescriptionEditorPage,
    editor: true,
    seed: _seedTeams,
    extra: const TeamDescriptionTarget(
      teamId: _teamId,
      description: '<p>Who waters what, and when.</p>',
    ),
  ),
  _trash('tasks'),
  _trash(
    'projects',
    shows: TrashProjectRow,
    after: (tester, _) async {
      final tab = find.byType(Tab).last;
      await tester.ensureVisible(tab);
      await tester.tap(tab);
    },
  ),
  _page(
    AppRoutes.savedFilterNew,
    AppRoutes.savedFilterNew,
    SavedFilterFormPage,
  ),
  _page(
    '${AppRoutes.home}/filters/:id/edit',
    AppRoutes.savedFilterEdit(urgentFilterId),
    SavedFilterFormPage,
  ),
  SweepScenario.route(
    AppRoutes.widgets,
    setUp: (tester, _) async {
      final harness = WidgetPagesHarness();
      await harness.pump(tester);
      final account = harness.activeAccountId(tester);
      harness.host.placed
        ..[12] = WidgetConfig(
          accountId: account,
          kind: const ProjectTasksKind(3),
        )
        ..[13] = WidgetConfig(accountId: account, kind: const UpcomingKind(7));
    },
    navigate: (tester, _) async => pushTo(tester, AppRoutes.widgets),
    expectScreen: (_) => find.byType(WidgetsPage),
  ),
  // A widget's setup page belongs to Android's launcher; iOS edits widgets
  // in its own widget editor.
  SweepScenario.route(
    '${AppRoutes.widgets}/configure',
    platforms: androidOnly,
    setUp: (tester, _) async {
      final harness = WidgetPagesHarness();
      await harness.pump(tester);
      final config = WidgetConfig(
        accountId: harness.activeAccountId(tester),
        kind: const UpcomingKind(7),
      );
      harness.host.placed[21] = config;
      harness.refresher.previews[config] = samplePreview(
        config,
        title: 'Upcoming',
        rows: 3,
        total: 5,
      );
    },
    navigate: (tester, _) async =>
        pushTo(tester, AppRoutes.widgetConfigure(21)),
    expectScreen: (_) => find.byType(WidgetConfigurePage),
  ),
];

/// A link-share guest on the paths it shares with users.
final List<SweepScenario> guestStateScenarios = [
  SweepScenario(
    kind: SweepKind.state,
    name: 'guest project list',
    route: '${AppRoutes.projects}/:id',
    setUp: (tester, _) async {
      final data = SyncFakes(now: sweepNow);
      data.projects.all = [
        guestProject(permission: Permission.write)
            .copyWith(views: defaultViews(guestProjectId, firstViewId: 31)),
      ];
      data.tasks.all = [
        for (final task in sweepData().tasks.all.take(4))
          task.copyWith(projectId: guestProjectId),
      ];
      await pumpGuestApp(
        tester,
        auth: AuthFakes(),
        data: data,
        permission: Permission.write,
      );
    },
    navigate: (tester, _) async =>
        goTo(tester, AppRoutes.project(guestProjectId)),
    expectScreen: (_) => find.byType(ProjectListBody),
  ),
];
