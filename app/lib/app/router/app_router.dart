import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/features/onboarding/application/current_server.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/connect/connect_server_screen.dart';
import 'package:vikunja_mobile/features/onboarding/presentation/overview/server_overview_screen.dart';

part 'app_router.g.dart';

abstract final class AppRoutes {
  static const connect = '/';
  static const serverOverview = '/server';
}

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final currentServer = ValueNotifier(ref.read(currentServerProvider));
  ref
    ..listen(currentServerProvider, (_, next) => currentServer.value = next)
    ..onDispose(currentServer.dispose);

  final router = GoRouter(
    initialLocation: AppRoutes.connect,
    refreshListenable: currentServer,
    redirect: (context, state) {
      final needsServer = state.matchedLocation == AppRoutes.serverOverview;
      if (needsServer && currentServer.value == null) {
        return AppRoutes.connect;
      }
      return null;
    },
    routes: [
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
    ],
  );
  ref.onDispose(router.dispose);
  return router;
}
