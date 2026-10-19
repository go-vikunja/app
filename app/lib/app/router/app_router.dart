import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/app/router/account_bound_screen.dart';
import 'package:vikunja_mobile/app/router/root_modal_routes.dart';
import 'package:vikunja_mobile/app/router/splash_screen.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/links/deep_link_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/home/presentation/account_tab.dart';
import 'package:vikunja_mobile/features/home/presentation/home_shell.dart';
import 'package:vikunja_mobile/features/inbox/presentation/inbox_screen.dart';
import 'package:vikunja_mobile/features/notifications/application/notifications_onboarding.dart';
import 'package:vikunja_mobile/features/notifications/presentation/notification_setup_screen.dart';
import 'package:vikunja_mobile/features/onboarding/application/current_server.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_server_screen.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/server_overview_screen.dart';
import 'package:vikunja_mobile/features/overview/presentation/overview_screen.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_tasks_screen.dart';
import 'package:vikunja_mobile/features/projects/presentation/projects_screen.dart';
import 'package:vikunja_mobile/features/smart_lists/presentation/smart_list_screen.dart';
import 'package:vikunja_mobile/features/sync/application/sync_status_queries.dart';
import 'package:vikunja_mobile/features/sync/presentation/first_sync_screen.dart';
import 'package:vikunja_mobile/features/tasks/presentation/edit/task_edit_page.dart';
import 'package:vikunja_mobile/features/upcoming/presentation/upcoming_screen.dart';

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

  /// The server's notifications, over the shell from the Overview's bell.
  static const inbox = '$home/inbox';

  /// The connect screen and the server overview over the shell, for
  /// signing in to another account; pushed, so back returns to the shell.
  static const addAccount = '$home/accounts/add';
  static const addAccountServer = '$addAccount/server';

  static const List<String> _tabs = [overview, upcoming, projects, account];

  /// Whether [location] is inside one of the shell's tabs rather than a
  /// page over the shell; `/home/accounts/add` is not the Account tab.
  static bool isTab(String location) =>
      _tabs.any((tab) => location == tab || location.startsWith('$tab/'));
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
  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    // A link that starts the app arrives as the platform's default route;
    // the start still goes through the splash, and the deep-link source
    // reads the link itself.
    overridePlatformDefaultLocation: true,
    observers: [ref.watch(rootModalRoutesProvider)],
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
      return _redirect(
        location: state.matchedLocation,
        accounts: registry,
        syncStatus: _syncStatusOfActive(ref, registry),
        notificationsOnboarded: onboarded.value,
        hasServer: currentServer.value != null,
      );
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
        path: AppRoutes.inbox,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            const AccountBoundScreen(child: InboxScreen()),
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
