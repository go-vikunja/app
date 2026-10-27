import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/router/account_bound_screen.dart';
import 'package:vikunja_mobile/app/router/pushed_pages.dart';
import 'package:vikunja_mobile/app/router/root_modal_routes.dart';
import 'package:vikunja_mobile/app/router/splash_screen.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/links/deep_link_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/account_settings_page.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/api_token_form_page.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/api_tokens_page.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/avatar_page.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/caldav_page.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/data_export_page.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/sessions_page.dart';
import 'package:vikunja_mobile/features/description_editor/application/description_target.dart';
import 'package:vikunja_mobile/features/description_editor/presentation/description_editor_page.dart';
import 'package:vikunja_mobile/features/home/presentation/account_tab.dart';
import 'package:vikunja_mobile/features/home/presentation/home_shell.dart';
import 'package:vikunja_mobile/features/inbox/presentation/inbox_screen.dart';
import 'package:vikunja_mobile/features/labels/presentation/label_form_page.dart';
import 'package:vikunja_mobile/features/labels/presentation/labels_page.dart';
import 'package:vikunja_mobile/features/notifications/application/notifications_onboarding.dart';
import 'package:vikunja_mobile/features/notifications/presentation/notification_setup_screen.dart';
import 'package:vikunja_mobile/features/onboarding/application/current_server.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_server_screen.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/server_overview_screen.dart';
import 'package:vikunja_mobile/features/overview/presentation/overview_screen.dart';
import 'package:vikunja_mobile/features/privacy/presentation/privacy_page.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/project_edit_page.dart';
import 'package:vikunja_mobile/features/projects/presentation/manage/project_views_page.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_tasks_screen.dart';
import 'package:vikunja_mobile/features/projects/presentation/projects_screen.dart';
import 'package:vikunja_mobile/features/search/presentation/search_page.dart';
import 'package:vikunja_mobile/features/sharing/presentation/project_share_page.dart';
import 'package:vikunja_mobile/features/smart_lists/presentation/label_tasks_screen.dart';
import 'package:vikunja_mobile/features/smart_lists/presentation/saved_filter_form_page.dart';
import 'package:vikunja_mobile/features/smart_lists/presentation/smart_list_screen.dart';
import 'package:vikunja_mobile/features/sync/application/sync_status_queries.dart';
import 'package:vikunja_mobile/features/sync/presentation/first_sync_screen.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/task_edit_page.dart';
import 'package:vikunja_mobile/features/teams/presentation/team_page.dart';
import 'package:vikunja_mobile/features/teams/presentation/teams_page.dart';
import 'package:vikunja_mobile/features/upcoming/presentation/upcoming_screen.dart';
import 'package:vikunja_mobile/features/widgets/presentation/widget_configure_page.dart';
import 'package:vikunja_mobile/features/widgets/presentation/widgets_page.dart';

part 'app_router.g.dart';

abstract final class AppRoutes {
  static const splash = '/splash';
  static const connect = '/';
  static const serverOverview = '/server';

  /// The full pull after sign-in, before [home] can show.
  static const firstSync = '/sync';

  /// The notification permissions, once per device after the first sync.
  static const notificationsSetup = '/notifications-setup';

  /// The signed-in shell; it opens on [overview].
  static const home = '/home';
  static const overview = '/home/overview';
  static const upcoming = '/home/upcoming';
  static const projects = '/home/projects';
  static const account = '/home/account';

  static String project(int id) => '$projects/$id';

  /// Full screen over the shell, from the detail sheet or a new task.
  static String taskEdit(int id) => '$home/tasks/$id/edit';

  /// The description editor over the shell, from the detail sheet and the
  /// edit pages.
  static String taskDescription(int id) => '$home/tasks/$id/description';

  /// The editor over the shell for an own comment, from the detail sheet;
  /// the comment comes as the push's `extra`, a `CommentTarget`.
  static String commentEdit(int taskId, int commentId) =>
      '$home/tasks/$taskId/comments/$commentId/edit';
  static String projectDescription(int id) => '$home/project/$id/description';

  /// Full screen over the shell, from the project's menu; outside
  /// [projects], which would count them as the tab.
  static String projectEdit(int id) => '$home/project/$id/edit';
  static String projectViews(int id) => '$home/project/$id/views';
  static String projectShare(int id) => '$home/project/$id/share';

  /// The server's notifications, over the shell from the Overview's bell.
  static const inbox = '$home/inbox';

  /// Over the shell, from the search button of the Overview, Upcoming and
  /// Projects; a label found there opens [labelTasks] over it.
  static const search = '$home/search';

  /// Over the shell, from the Account tab; a label opens [labelTasks],
  /// which the search and the task sheet's label pills open too.
  static const labels = '$home/labels';
  static const labelNew = '$labels/new';
  static String labelTasks(int labelId) => '$labels/$labelId';
  static String labelEdit(int labelId) => '$labels/$labelId/edit';
  static String labelDescription(int labelId) => '$labels/$labelId/description';

  /// Over the shell, from the Account tab; a team's page also from the
  /// inbox. Its description editor comes with the team's text as the
  /// push's `extra`, a `TeamDescriptionTarget`: teams are not stored.
  static const teams = '$home/teams';
  static String team(int teamId) => '$teams/$teamId';
  static String teamDescription(int teamId) => '$teams/$teamId/description';

  /// Over the shell, from the Projects tab and a saved filter's menu.
  static const savedFilterNew = '$home/filters/new';
  static String savedFilterEdit(int pseudoProjectId) =>
      '$home/filters/$pseudoProjectId/edit';

  /// Over the shell, from the Account tab's profile header; the server's
  /// settings of the account, not the device's.
  static const accountSettings = '$home/account-settings';
  static const accountAvatar = '$accountSettings/avatar';
  static const accountSessions = '$accountSettings/sessions';
  static const accountApiTokens = '$accountSettings/api-tokens';
  static const accountApiTokenNew = '$accountApiTokens/new';
  static const accountCaldav = '$accountSettings/caldav';
  static const accountDataExport = '$accountSettings/data-export';

  /// Over the shell, from the Account tab: how to place the home-screen
  /// widgets, and on Android the placed ones.
  static const widgets = '$home/widgets';

  /// Over the shell, from a placed Android widget's setup (through a
  /// widget link, [fromWidget]) and the widgets page.
  static String widgetConfigure(int appWidgetId, {bool fromWidget = false}) =>
      '$widgets/configure?appWidgetId=$appWidgetId'
      '${fromWidget ? '&from=widget' : ''}';

  /// Over the shell, from the Account tab: the app lock and what the
  /// screen, notifications and widgets show. Open to link-share guests,
  /// whose device it is too.
  static const privacy = '$home/privacy';

  /// The connect screen and the server overview over the shell, for
  /// signing in to another account; pushed, so back returns to the shell.
  static const addAccount = '$home/accounts/add';
  static const addAccountServer = '$addAccount/server';

  static const List<String> _tabs = [overview, upcoming, projects, account];

  /// Whether [location] is inside one of the shell's tabs rather than a
  /// page over the shell; `/home/accounts/add` is not the Account tab.
  static bool isTab(String location) =>
      _tabs.any((tab) => location == tab || location.startsWith('$tab/'));

  static final _closedToGuests = RegExp(
    '^(?:(?:$accountSettings|$teams)(?:/.*)?|$inbox|'
    '$labels(?:/new|/\\d+/edit|/\\d+/description)?|'
    '$home/filters/(?:new|-?\\d+/edit)|'
    '$home/project/-?\\d+/(?:edit|description|views|share))\$',
  );

  /// The pages a link-share guest has no use for: the server refuses what
  /// they do for anyone who is not a user, or the share's project is its
  /// owner's to rename, share or set up views for. A label's tasks stay
  /// open.
  static bool isClosedToGuests(String location) =>
      _closedToGuests.hasMatch(location);
}

/// Observes the root navigator, whose dialogs and sheets an account switch
/// closes.
@Riverpod(keepAlive: true)
RootModalRoutes rootModalRoutes(Ref ref) => RootModalRoutes();

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final currentServer = ValueNotifier(ref.read(currentServerProvider));
  // Only what triggers a redirect; it reads the registry and the status
  // itself, because a listener notified before these may already route.
  final accounts = ValueNotifier(ref.read(accountsProvider));
  final syncStatus = ValueNotifier(ref.read(syncStatusProvider));
  final onboarded = ValueNotifier(ref.read(notificationsOnboardingProvider));
  ref
    ..listen(currentServerProvider, (_, next) => currentServer.value = next)
    ..listen(accountsProvider, (_, next) => accounts.value = next)
    ..listen(syncStatusProvider, (_, next) => syncStatus.value = next)
    ..listen(
      notificationsOnboardingProvider,
      (_, next) => onboarded.value = next,
    )
    ..onDispose(currentServer.dispose)
    ..onDispose(accounts.dispose)
    ..onDispose(syncStatus.dispose)
    ..onDispose(onboarded.dispose);

  // Before the router exists: its own observer, which routes what the
  // platform pushes, registers once the app subscribes to it, so this one
  // is asked first.
  final links = _AppSchemeLinks(ref.read(deepLinkRelayProvider).accept);
  WidgetsBinding.instance.addObserver(links);
  ref.onDispose(() => WidgetsBinding.instance.removeObserver(links));

  final rootNavigatorKey = GlobalKey<NavigatorState>();
  final commentEdits = _PushedTargets<CommentTarget>();
  final teamDescriptions = _PushedTargets<TeamDescriptionTarget>();
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    // A link that starts the app arrives as the platform's default route;
    // the start still goes through the splash, and the deep-link source
    // reads the link itself.
    overridePlatformDefaultLocation: true,
    observers: [ref.watch(rootModalRoutesProvider), PushedPages()],
    refreshListenable: Listenable.merge([
      currentServer,
      accounts,
      syncStatus,
      onboarded,
    ]),
    redirect: (context, state) {
      // Never a route; [_AppSchemeLinks] takes these before they get here.
      if (ref.read(deepLinkRelayProvider).accept(state.uri)) {
        return AppRoutes.splash;
      }
      final registry = ref.read(accountsProvider);
      final redirect = _redirect(
        location: state.matchedLocation,
        accounts: registry,
        syncStatus: _syncStatusOfActive(ref, registry),
        notificationsOnboarded: onboarded.value,
        hasServer: currentServer.value != null,
      );
      if (redirect != null) return redirect;
      final guest = registry.value?.activeAccount?.account.isLinkShare ?? false;
      return guest && AppRoutes.isClosedToGuests(state.matchedLocation)
          ? AppRoutes.overview
          : null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.connect,
        builder: (context, state) => const ConnectServerScreen(),
        routes: [
          GoRoute(
            path: AppRoutes.serverOverview.substring(1),
            builder: (context, state) => const ServerOverviewScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.firstSync,
        // The shell this replaces stays mounted until the page above it has
        // finished its entrance, and the shell's global keys allow only one
        // shell at a time: a first sync that ends within an animated
        // entrance would return to a second shell beside the first.
        pageBuilder: (context, state) => NoTransitionPage(
          key: state.pageKey,
          name: state.path,
          restorationId: state.pageKey.value,
          child: const FirstSyncScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.notificationsSetup,
        builder: (context, state) => const NotificationSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        redirect: (context, state) => AppRoutes.overview,
      ),
      // On the root navigator: it covers the tab bar.
      GoRoute(
        path: '${AppRoutes.home}/tasks/:id/edit',
        parentNavigatorKey: rootNavigatorKey,
        redirect: (context, state) =>
            _idParam(state) == null ? AppRoutes.overview : null,
        builder: (context, state) =>
            AccountBoundScreen(child: TaskEditPage(taskId: _idParam(state)!)),
      ),
      GoRoute(
        path: '${AppRoutes.home}/tasks/:id/description',
        parentNavigatorKey: rootNavigatorKey,
        redirect: (context, state) =>
            _idParam(state) == null ? AppRoutes.overview : null,
        builder: (context, state) => AccountBoundScreen(
          child: DescriptionEditorPage(
            target: TaskDescriptionTarget(_idParam(state)!),
          ),
        ),
      ),
      GoRoute(
        path: '${AppRoutes.home}/tasks/:id/comments/:commentId/edit',
        parentNavigatorKey: rootNavigatorKey,
        redirect: (context, state) =>
            commentEdits.targetFor(state) == null ? AppRoutes.overview : null,
        builder: (context, state) => AccountBoundScreen(
          child: DescriptionEditorPage(target: commentEdits.targetFor(state)!),
        ),
      ),
      GoRoute(
        path: '${AppRoutes.home}/project/:id/description',
        parentNavigatorKey: rootNavigatorKey,
        redirect: (context, state) =>
            _idParam(state) == null ? AppRoutes.projects : null,
        builder: (context, state) => AccountBoundScreen(
          child: DescriptionEditorPage(
            target: ProjectDescriptionTarget(_idParam(state)!),
          ),
        ),
      ),
      GoRoute(
        path: '${AppRoutes.home}/project/:id/edit',
        parentNavigatorKey: rootNavigatorKey,
        redirect: (context, state) =>
            _idParam(state) == null ? AppRoutes.projects : null,
        builder: (context, state) => AccountBoundScreen(
          child: ProjectEditPage(projectId: _idParam(state)!),
        ),
      ),
      GoRoute(
        path: '${AppRoutes.home}/project/:id/views',
        parentNavigatorKey: rootNavigatorKey,
        redirect: (context, state) =>
            _idParam(state) == null ? AppRoutes.projects : null,
        builder: (context, state) => AccountBoundScreen(
          child: ProjectViewsPage(projectId: _idParam(state)!),
        ),
      ),
      GoRoute(
        path: '${AppRoutes.home}/project/:id/share',
        parentNavigatorKey: rootNavigatorKey,
        redirect: (context, state) =>
            _idParam(state) == null ? AppRoutes.projects : null,
        builder: (context, state) => AccountBoundScreen(
          child: ProjectSharePage(projectId: _idParam(state)!),
        ),
      ),
      GoRoute(
        path: AppRoutes.inbox,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            const AccountBoundScreen(child: InboxScreen()),
      ),
      GoRoute(
        path: AppRoutes.search,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            const AccountBoundScreen(child: SearchPage()),
      ),
      GoRoute(
        path: AppRoutes.labels,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            const AccountBoundScreen(child: LabelsPage()),
        routes: [
          // Before ':id', which would take it for an id.
          GoRoute(
            path: 'new',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) =>
                const AccountBoundScreen(child: LabelFormPage()),
          ),
          GoRoute(
            path: ':id',
            parentNavigatorKey: rootNavigatorKey,
            redirect: (context, state) =>
                _idParam(state) == null ? AppRoutes.labels : null,
            builder: (context, state) => AccountBoundScreen(
              child: LabelTasksScreen(labelId: _idParam(state)!),
            ),
            routes: [
              GoRoute(
                path: 'edit',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => AccountBoundScreen(
                  child: LabelFormPage(labelId: _idParam(state)),
                ),
              ),
              GoRoute(
                path: 'description',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => AccountBoundScreen(
                  child: DescriptionEditorPage(
                    target: LabelDescriptionTarget(_idParam(state)!),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.teams,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            const AccountBoundScreen(child: TeamsPage()),
        routes: [
          GoRoute(
            path: ':id',
            parentNavigatorKey: rootNavigatorKey,
            redirect: (context, state) =>
                _idParam(state) == null ? AppRoutes.teams : null,
            builder: (context, state) => AccountBoundScreen(
              child: TeamPage(
                key: ValueKey(_idParam(state)),
                teamId: _idParam(state)!,
              ),
            ),
            routes: [
              GoRoute(
                path: 'description',
                parentNavigatorKey: rootNavigatorKey,
                redirect: (context, state) =>
                    teamDescriptions.targetFor(state) == null
                    ? AppRoutes.team(_idParam(state)!)
                    : null,
                builder: (context, state) => AccountBoundScreen(
                  child: DescriptionEditorPage(
                    target: teamDescriptions.targetFor(state)!,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.savedFilterNew,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            const AccountBoundScreen(child: SavedFilterFormPage()),
      ),
      GoRoute(
        path: '${AppRoutes.home}/filters/:id/edit',
        parentNavigatorKey: rootNavigatorKey,
        redirect: (context, state) =>
            _idParam(state) == null ? AppRoutes.projects : null,
        builder: (context, state) => AccountBoundScreen(
          child: SavedFilterFormPage(pseudoProjectId: _idParam(state)),
        ),
      ),
      GoRoute(
        path: AppRoutes.accountSettings,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            const AccountBoundScreen(child: AccountSettingsPage()),
        routes: [
          GoRoute(
            path: 'avatar',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) =>
                const AccountBoundScreen(child: AvatarPage()),
          ),
          GoRoute(
            path: 'sessions',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) =>
                const AccountBoundScreen(child: SessionsPage()),
          ),
          GoRoute(
            path: 'api-tokens',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) =>
                const AccountBoundScreen(child: ApiTokensPage()),
            routes: [
              GoRoute(
                path: 'new',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) =>
                    const AccountBoundScreen(child: ApiTokenFormPage()),
              ),
            ],
          ),
          GoRoute(
            path: 'caldav',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => AccountBoundScreen(
              child: CaldavPage(
                knownTotp: TotpStatus.values.asNameMap()[state.extra],
              ),
            ),
          ),
          GoRoute(
            path: 'data-export',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) =>
                const AccountBoundScreen(child: DataExportPage()),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.widgets,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const WidgetsPage(),
        routes: [
          GoRoute(
            path: 'configure',
            parentNavigatorKey: rootNavigatorKey,
            redirect: (context, state) =>
                _appWidgetIdParam(state) == null ? AppRoutes.widgets : null,
            builder: (context, state) => WidgetConfigurePage(
              key: ValueKey(_appWidgetIdParam(state)),
              appWidgetId: _appWidgetIdParam(state)!,
              fromWidget: state.uri.queryParameters['from'] == 'widget',
            ),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.privacy,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const PrivacyPage(),
      ),
      GoRoute(
        path: AppRoutes.addAccount,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ConnectServerScreen(adding: true),
        routes: [
          GoRoute(
            path: 'server',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) =>
                const ServerOverviewScreen(adding: true),
          ),
        ],
      ),
      // Each tab keeps its own navigation stack and scroll position.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.overview,
                builder: (context, state) => const OverviewScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.upcoming,
                builder: (context, state) => const UpcomingScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.projects,
                builder: (context, state) => const ProjectsScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    redirect: (context, state) =>
                        _idParam(state) == null ? AppRoutes.projects : null,
                    // The page stays when only the id changes (its key is
                    // the route's path); the screen must not.
                    builder: (context, state) => switch (_idParam(state)!) {
                      final id when id < 0 => SmartListScreen(
                        key: ValueKey(id),
                        pseudoProjectId: id,
                      ),
                      final id => ProjectTasksScreen(
                        key: ValueKey(id),
                        projectId: id,
                      ),
                    },
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.account,
                builder: (context, state) => const AccountTab(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}

/// Takes every URI of the app's own scheme that the platform pushes (a
/// task link, an OAuth callback that arrived after its sign-in ended) for
/// the deep-link relay, so that the router never treats one as a route.
/// go_router's `onEnter` could block them too, but with an `onEnter` every
/// route parse is asynchronous, the first one included, and the app's
/// first frame would be empty.
final class _AppSchemeLinks with WidgetsBindingObserver {
  new(this._accept);

  final bool Function(Uri uri) _accept;

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) =>
      SynchronousFuture(_accept(routeInformation.uri));
}

/// The `:id` of a route; negative for a task created on this device and
/// not yet sent, and for a project, a list that is no project (Favorites or
/// a saved filter).
int? _idParam(GoRouterState state) =>
    int.tryParse(state.pathParameters['id'] ?? '');

int? _appWidgetIdParam(GoRouterState state) =>
    int.tryParse(state.uri.queryParameters['appWidgetId'] ?? '');

/// Not [syncStatusProvider], which follows a change of the active account
/// only once it rebuilds.
AsyncValue<SyncStatus> _syncStatusOfActive(
  Ref ref,
  AsyncValue<AccountRegistryState> accounts,
) => switch (accounts.value?.activeAccount) {
  final entry? =>
    ref.read(accountSyncStatusProvider(entry.id)).unwrapPrevious(),
  null => const AsyncLoading(),
};

/// The account registry, the sync state and the onboarding flag are local,
/// so the start screen never waits for the network. Signed in, the shell
/// waits for the account's first full sync (and for its engine to report
/// at all), then for the notification setup, once per device; the splash
/// holds until the flag is read, which bootstrap does before the first
/// frame.
String? _redirect({
  required String location,
  required AsyncValue<AccountRegistryState> accounts,
  required AsyncValue<SyncStatus> syncStatus,
  required AsyncValue<bool> notificationsOnboarded,
  required bool hasServer,
}) {
  if (accounts case AsyncLoading(hasValue: false)) return AppRoutes.splash;
  final signedIn = accounts.value?.activeAccount != null;
  if (!signedIn) {
    return switch (location) {
      AppRoutes.splash ||
      AppRoutes.firstSync ||
      AppRoutes.notificationsSetup => AppRoutes.connect,
      _ when location.startsWith(AppRoutes.home) => AppRoutes.connect,
      AppRoutes.serverOverview when !hasServer => AppRoutes.connect,
      _ => null,
    };
  }
  final synced = !needsFirstSync(syncStatus.value);
  // An unreadable flag counts as onboarded: a setup screen the user cannot
  // leave would be worse than none.
  final onboarded = notificationsOnboarded.hasError
      ? true
      : notificationsOnboarded.value;
  return switch (location) {
    AppRoutes.splash when !synced => AppRoutes.firstSync,
    AppRoutes.splash => switch (onboarded) {
      null => null,
      false => AppRoutes.notificationsSetup,
      true => AppRoutes.overview,
    },
    AppRoutes.firstSync when synced =>
      onboarded == false ? AppRoutes.notificationsSetup : AppRoutes.overview,
    AppRoutes.notificationsSetup when !synced => AppRoutes.firstSync,
    AppRoutes.notificationsSetup when onboarded ?? true => AppRoutes.overview,
    _ when location.startsWith(AppRoutes.home) && !synced =>
      AppRoutes.firstSync,
    _ when location.startsWith(AppRoutes.home) && onboarded == false =>
      AppRoutes.notificationsSetup,
    AppRoutes.serverOverview when !hasServer => AppRoutes.connect,
    _ => null,
  };
}

/// The comment or team an editor page was pushed with. go_router drops an
/// `extra` it cannot store as JSON once the platform reports the route list
/// back, as Android does when the app is opened again, and would then send
/// the open editor away.
final class _PushedTargets<T extends DescriptionTarget> {
  String? _location;
  T? _target;

  T? targetFor(GoRouterState state) {
    if (state.extra case final T target) {
      _location = state.matchedLocation;
      _target = target;
      return target;
    }
    return state.matchedLocation == _location ? _target : null;
  }
}
