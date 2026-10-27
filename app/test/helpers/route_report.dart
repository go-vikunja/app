import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// go_router decoding the current route list anew, as it does on a state
/// restoration or a refresh (flutter/flutter#128122): it rebuilds the list,
/// and the futures of earlier pushes never finish. Handed to the router's
/// own provider: the app drops every route the platform pushes.
Future<void> reportRouteFromPlatform(WidgetTester tester) async {
  final router = GoRouter.of(tester.element(find.byType(Navigator).first));
  final info = router.routeInformationParser.restoreRouteInformation(
    router.routerDelegate.currentConfiguration,
  )!;
  await router.routeInformationProvider.didPushRouteInformation(
    RouteInformation(uri: info.uri, state: info.state),
  );
  await tester.pumpAndSettle();
}
