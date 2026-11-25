import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// What a refresh of the router does to pushed pages: go_router decodes
/// the current route list anew (flutter/flutter#128122), so the futures of
/// earlier pushes never finish and an `extra` that is no JSON is gone.
/// Handed to the router's own provider: the app drops every route the
/// platform pushes.
Future<void> refreshRoutes(WidgetTester tester) async {
  final router = GoRouter.of(tester.element(find.byType(Navigator).first));
  final info = router.routeInformationParser.restoreRouteInformation(
    router.routerDelegate.currentConfiguration,
  )!;
  await router.routeInformationProvider.didPushRouteInformation(
    RouteInformation(uri: info.uri, state: info.state),
  );
  await tester.pumpAndSettle();
}
