import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/app/router/splash_screen.dart';
import 'package:vikunja_mobile/core/auth/account_registry.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_providers.dart';
import 'package:vikunja_mobile/core/sync/sync_status.dart';
import 'package:vikunja_mobile/features/home/presentation/account_tab.dart';
import 'package:vikunja_mobile/features/home/presentation/home_shell.dart';
import 'package:vikunja_mobile/features/onboarding/application/current_server.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_server_screen.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/server_overview_screen.dart';
import 'package:vikunja_mobile/features/overview/presentation/overview_screen.dart';
import 'package:vikunja_mobile/features/projects/presentation/project_tasks_screen.dart';
import 'package:vikunja_mobile/features/projects/presentation/projects_screen.dart';
import 'package:vikunja_mobile/features/sync/application/sync_status_queries.dart';
import 'package:vikunja_mobile/features/sync/presentation/first_sync_screen.dart';

part 'app_router.g.dart';

abstract final class AppRoutes {
  static const splash = '/splash';
  static const connect = '/';
  static const serverOverview = '/server';

  /// The full pull after sign-in, before [home] can show.
  static const firstSync = '/sync';

  /// The signed-in shell; it opens on [overview].
  static const home = '/home';
  static const overview = '/home/overview';
  static const projects = '/home/projects';
  static const account = '/home/account';

  static String project(int id) => '$projects/$id';
}

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final currentServer = ValueNotifier(ref.read(currentServerProvider));
  final accounts = ValueNotifier(ref.read(accountsProvider));
  final syncStatus = ValueNotifier(ref.read(syncStatusProvider));
  ref
    ..listen(currentServerProvider, (_, next) => currentServer.value = next)
    ..listen(accountsProvider, (_, next) => accounts.value = next)
    ..listen(syncStatusProvider, (_, next) => syncStatus.value = next)
    ..onDispose(currentServer.dispose)
    ..onDispose(accounts.dispose)
    ..onDispose(syncStatus.dispose);

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: Listenable.merge([currentServer, accounts, syncStatus]),
    redirect: (context, state) => _redirect(
      location: state.matchedLocation,
      accounts: accounts.value,
      syncStatus: syncStatus.value,
      hasServer: currentServer.value != null,
    ),
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
        builder: (context, state) => const FirstSyncScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        redirect: (context, state) => AppRoutes.overview,
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
                path: AppRoutes.projects,
                builder: (context, state) => const ProjectsScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    redirect: (context, state) =>
                        _projectId(state) == null ? AppRoutes.projects : null,
                    builder: (context, state) =>
                        ProjectTasksScreen(projectId: _projectId(state)!),
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

int? _projectId(GoRouterState state) =>
    int.tryParse(state.pathParameters['id'] ?? '');

/// The account registry and the sync state are local, so the start screen
/// never waits for the network. Signed in, the shell waits for the account's
/// first full sync (and for its engine to report at all).
String? _redirect({
  required String location,
  required AsyncValue<AccountRegistryState> accounts,
  required AsyncValue<SyncStatus> syncStatus,
  required bool hasServer,
}) {
  if (accounts case AsyncLoading(hasValue: false)) return AppRoutes.splash;
  final signedIn = accounts.value?.activeAccount != null;
  if (!signedIn) {
    return switch (location) {
      AppRoutes.splash || AppRoutes.firstSync => AppRoutes.connect,
      _ when location.startsWith(AppRoutes.home) => AppRoutes.connect,
      AppRoutes.serverOverview when !hasServer => AppRoutes.connect,
      _ => null,
    };
  }
  final synced = !needsFirstSync(syncStatus.value);
  return switch (location) {
    AppRoutes.splash => synced ? AppRoutes.overview : AppRoutes.firstSync,
    AppRoutes.firstSync when synced => AppRoutes.overview,
    _ when location.startsWith(AppRoutes.home) && !synced =>
      AppRoutes.firstSync,
    AppRoutes.serverOverview when !hasServer => AppRoutes.connect,
    _ => null,
  };
}
