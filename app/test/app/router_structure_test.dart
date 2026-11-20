import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/router/account_bound_screen.dart';
import 'package:vikunja_mobile/app/router/app_router.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/features/account_settings/presentation/sessions_page.dart';
import 'package:vikunja_mobile/features/accounts/application/account_switcher.dart';
import 'package:vikunja_mobile/features/description_editor/application/description_target.dart';
import 'package:vikunja_mobile/features/inbox/presentation/inbox_screen.dart';

import '../features/accounts/accounts_harness.dart';
import '../helpers/label_user_fakes.dart';
import '../helpers/pump_app.dart';
import '../helpers/sample_data.dart';

/// The routes outside the tab shell that replace it rather than cover it.
const Set<String> _startRoutes = {
  AppRoutes.splash,
  AppRoutes.connect,
  AppRoutes.serverOverview,
  AppRoutes.connection,
  AppRoutes.about,
  AppRoutes.firstSync,
  AppRoutes.notificationsSetup,
  AppRoutes.home,
};

/// Over the shell, but kept through an account switch.
const Set<String> _notAccountBound = {
  AppRoutes.widgets,
  '${AppRoutes.widgets}/configure',
  AppRoutes.privacy,
  AppRoutes.addAccount,
  AppRoutes.addAccountServer,
};

void main() {
  GoRouter routerOf(WidgetTester tester) =>
      containerOf(tester).read(appRouterProvider);

  /// Every route outside the tab shell, by its full path.
  Map<String, GoRoute> outsideTheShell(GoRouter router) {
    final configuration = router.configuration;
    final routes = <String, GoRoute>{};
    void walk(List<RouteBase> children) {
      for (final route in children) {
        if (route is StatefulShellRoute) continue;
        if (route is GoRoute) {
          routes[configuration.locationForRoute(route)!] = route;
        }
        walk(route.routes);
      }
    }

    walk(configuration.routes);
    return routes;
  }

  testWidgets('every page outside the tab shell covers the tab bar, except '
      'the start pages', (tester) async {
    await pumpVikunjaApp(tester);
    final router = routerOf(tester);
    final routes = outsideTheShell(router);

    expect(routes.keys, containsAll(_startRoutes));
    expect(routes.length - _startRoutes.length, 33);
    for (final MapEntry(key: path, value: route) in routes.entries) {
      expect(
        route.parentNavigatorKey,
        _startRoutes.contains(path)
            ? isNull
            : same(router.routerDelegate.navigatorKey),
        reason: path,
      );
    }
  });

  testWidgets('a page over the shell belongs to the account that opened it, '
      'except the device-wide ones and adding an account', (tester) async {
    await pumpVikunjaApp(tester);
    final router = routerOf(tester);
    final context = tester.element(find.byType(Navigator).first);

    for (final MapEntry(key: path, value: route) in outsideTheShell(
      router,
    ).entries) {
      if (_startRoutes.contains(path)) continue;
      final location = path
          .replaceAll(':commentId', '4')
          .replaceAll(':id', '3');
      final state = GoRouterState(
        router.configuration,
        uri: Uri(path: location, queryParameters: {'appWidgetId': '5'}),
        matchedLocation: location,
        fullPath: path,
        pathParameters: const {'id': '3', 'commentId': '4'},
        extra: switch (path) {
          '/home/tasks/:id/comments/:commentId/edit' => CommentTarget(
            taskId: 3,
            projectId: 1,
            comment: sampleComment(id: 4),
          ),
          '/home/teams/:id/description' => const TeamDescriptionTarget(
            teamId: 3,
            description: '',
          ),
          _ => null,
        },
        pageKey: ValueKey(location),
      );

      expect(
        route.builder!(context, state),
        _notAccountBound.contains(path)
            ? isNot(isA<AccountBoundScreen>())
            : isA<AccountBoundScreen>(),
        reason: path,
      );
    }
  });

  testWidgets('a page opened without a usable id, or without what it was '
      'pushed with, goes to the page it was opened from', (tester) async {
    await pumpSignedInApp(
      tester,
      overrides: [
        labelRepositoryProvider.overrideWithValue(FakeLabelRepository()),
        userRepositoryProvider.overrideWithValue(FakeUserRepository()),
      ],
    );
    const fallbacks = {
      '/home/tasks/x/edit': AppRoutes.overview,
      '/home/tasks/x/description': AppRoutes.overview,
      '/home/tasks/1/comments/2/edit': AppRoutes.overview,
      '/home/project/x/description': AppRoutes.projects,
      '/home/project/x/edit': AppRoutes.projects,
      '/home/project/x/views': AppRoutes.projects,
      '/home/project/x/share': AppRoutes.projects,
      '/home/projects/x': AppRoutes.projects,
      '/home/labels/x': AppRoutes.labels,
      '/home/labels/x/edit': AppRoutes.labels,
      '/home/labels/x/description': AppRoutes.labels,
      '/home/teams/x': AppRoutes.teams,
      '/home/teams/3/description': '/home/teams/3',
      '/home/filters/x/edit': AppRoutes.projects,
      '/home/filters/x/description': AppRoutes.projects,
      '/home/widgets/configure': AppRoutes.widgets,
    };

    for (final MapEntry(key: opened, value: fallback) in fallbacks.entries) {
      routerOf(tester).go(opened);
      await tester.pumpAndSettle();

      expect(
        routerOf(tester).routerDelegate.currentConfiguration.uri.toString(),
        fallback,
        reason: opened,
      );
    }
  });

  group('an account switch blanks a page over the shell at once', () {
    for (final (location, page) in [
      (AppRoutes.inbox, InboxScreen),
      (AppRoutes.accountSessions, SessionsPage),
    ]) {
      testWidgets(location, (tester) async {
        final accounts = ThreeAccounts();
        await accounts.seed(withCarol: false);
        await accounts.pump(tester);
        unawaited(routerOf(tester).push(location));
        await tester.pumpAndSettle();
        expect(find.byType(page), findsOneWidget);

        await containerOf(tester)
            .read(accountSwitcherProvider)
            .switchTo(accounts.bob.id);
        // Delivers the registry change, then draws the frame it scheduled.
        await tester.pump();
        await tester.pump();

        expect(find.byType(page), findsNothing);
        await tester.pumpAndSettle();
        expect(
          routerOf(tester).routerDelegate.currentConfiguration.uri.toString(),
          AppRoutes.overview,
        );
      });
    }
  });
}
